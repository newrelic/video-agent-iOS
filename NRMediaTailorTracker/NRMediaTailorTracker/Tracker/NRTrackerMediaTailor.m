//
//  NRTrackerMediaTailor.m
//  NRMediaTailorTracker
//
//  New Relic Video Agent — AWS MediaTailor ad tracker for AVPlayer.
//  Subclasses NRVideoTracker (NewRelicVideoCore). Mirrors NRTrackerIMA's
//  role: a passive observer that detects MediaTailor ads inside an
//  AVPlayer stream and emits AD_BREAK_START / AD_START / AD_QUARTILE /
//  AD_END / AD_BREAK_END / AD_ERROR.
//
//  ---------------------------------------------------------------------------
//  SDK-Boundary Anti-Pattern Guardrails (do NOT do these)
//  Source: NRMediaTailorTracker_FEATURE_SPEC.md §5
//  ---------------------------------------------------------------------------
//  1. Do NOT fire VAST tracking beacons. Server-side mode = MediaTailor fires
//     them. Client-side mode = customer's player fires them. We observe; we do
//     not transmit ad-server beacons.
//  2. Do NOT resolve VAST wrappers. MediaTailor returns final ad metadata.
//  3. Do NOT implement ad personalization or targeting.
//  4. Do NOT cache ads across sessions.
//  5. Do NOT modify manifest query parameters.
//  6. Do NOT implement avail suppression (`BEHIND_LIVE_EDGE` etc.) logic.
//  7. Do NOT render ad UI, pause the player, or call back into customer
//     business logic.
//  8. Do NOT assume every avail has ads (empty = no-fill, handle explicitly).
//  9. Do NOT pre-fire impression beacons before confirming the ad played.
//  10. Do NOT perform OMID / viewability handoff. That's an app-layer concern.
//  ---------------------------------------------------------------------------
//

#import "NRTrackerMediaTailor.h"
#import "MTManifestParser.h"
#import "MTHlsParser.h"
#import "MTPlayheadStateMachine.h"
#import "MergedSchedule.h"
#import "MTAdBreak.h"
#import "MTAdPod.h"
#import "MTAdErrorCode.h"
#import "MTTrackingClient.h"

NSString * const NRMediaTailorTrackerErrorDomain = @"NRMediaTailorTracker";

/// KVO context for the `timeControlStatus` observation. Using a static
/// context pointer prevents accidental delivery of unrelated observations
/// from being interpreted as the player's pause/resume.
static void * const kTrackerTimeControlStatusContext = (void *)&kTrackerTimeControlStatusContext;

@interface NRTrackerMediaTailor () <MTPlayheadStateMachineDelegate>

@property (nonatomic, strong, nullable, readwrite) MTPlayheadStateMachine *stateMachine;
@property (nonatomic, strong, nullable) MTTrackingClient *trackingClient;

@property (nonatomic, weak, nullable) AVPlayer *avPlayer;
@property (nonatomic, assign) BOOL hasInstalledTimeControlObserver;

@property (nonatomic, weak, nullable) MTAdBreak *currentBreak;
@property (nonatomic, weak, nullable) MTAdPod *currentPod;
@property (nonatomic, assign) NSInteger currentQuartileNumber;

@property (nonatomic, assign, readwrite) BOOL isDisposed;

@end

@implementation NRTrackerMediaTailor

#pragma mark - Init / dealloc

- (instancetype)init {
    self = [super init];
    if (self) {
        _trackingClient = [[MTTrackingClient alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self dispose];
}

- (id<MTManifestParser>)manifestParser {
    if (_manifestParser == nil) {
        _manifestParser = [[MTHlsParser alloc] init];
    }
    return _manifestParser;
}

#pragma mark - Player attachment / KVO

- (void)setPlayer:(id)player {
    if (self.isDisposed) { return; }
    if (![player isKindOfClass:[AVPlayer class]]) {
        [super setPlayer:player];
        return;
    }
    AVPlayer *newPlayer = (AVPlayer *)player;

    [self detachFromCurrentPlayer];

    self.avPlayer = newPlayer;
    [self installTimeControlStatusObserver];

    if (self.stateMachine != nil) {
        [self.stateMachine attachToPlayer:newPlayer];
    }

    [super setPlayer:player];
}

- (void)installTimeControlStatusObserver {
    if (self.avPlayer == nil) { return; }
    if (self.hasInstalledTimeControlObserver) { return; }
    [self.avPlayer addObserver:self
                    forKeyPath:@"timeControlStatus"
                       options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                       context:kTrackerTimeControlStatusContext];
    self.hasInstalledTimeControlObserver = YES;
}

- (void)removeTimeControlStatusObserver {
    if (!self.hasInstalledTimeControlObserver) { return; }
    AVPlayer *player = self.avPlayer;
    if (player != nil) {
        @try {
            [player removeObserver:self
                        forKeyPath:@"timeControlStatus"
                           context:kTrackerTimeControlStatusContext];
        } @catch (NSException *exception) {
            // Defensive: removing an observer that wasn't installed throws.
            // We track our own install flag, so this should not happen, but
            // we keep the @try to harden against subclasses or unusual
            // lifecycles.
        }
    }
    self.hasInstalledTimeControlObserver = NO;
}

- (void)detachFromCurrentPlayer {
    [self.stateMachine detachFromPlayer];
    [self removeTimeControlStatusObserver];
    self.avPlayer = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (context != kTrackerTimeControlStatusContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    if (self.isDisposed) { return; }
    // Only emit pause / resume while inside an ad break — main-content
    // pause/resume is the customer's content tracker's concern.
    if (self.currentBreak == nil) { return; }

    AVPlayerTimeControlStatus newStatus =
        (AVPlayerTimeControlStatus)[change[NSKeyValueChangeNewKey] integerValue];
    AVPlayerTimeControlStatus oldStatus =
        (AVPlayerTimeControlStatus)[change[NSKeyValueChangeOldKey] integerValue];

    if (newStatus == AVPlayerTimeControlStatusPaused &&
        oldStatus != AVPlayerTimeControlStatusPaused) {
        [self sendPause];
    } else if (newStatus == AVPlayerTimeControlStatusPlaying &&
               oldStatus == AVPlayerTimeControlStatusPaused) {
        [self sendResume];
    }
}

#pragma mark - Public lifecycle

- (void)startTrackingWithSchedule:(MergedSchedule *)schedule {
    if (self.isDisposed) { return; }
    NSParameterAssert(schedule != nil);
    [self stopTracking];
    self.stateMachine = [[MTPlayheadStateMachine alloc] initWithSchedule:schedule
                                                    playheadPollInterval:0.250];
    self.stateMachine.delegate = self;
    if (self.avPlayer != nil) {
        [self.stateMachine attachToPlayer:self.avPlayer];
    }
}

- (void)stopTracking {
    [self.stateMachine detachFromPlayer];
    self.stateMachine = nil;
    self.currentBreak = nil;
    self.currentPod = nil;
    self.currentQuartileNumber = 0;
}

- (void)dispose {
    if (self.isDisposed) { return; }
    self.isDisposed = YES;

    [self.trackingClient cancel];
    [self.trackingClient resetSession];
    self.trackingClient = nil;

    [self stopTracking];
    [self detachFromCurrentPlayer];

    [super dispose];
}

- (void)notifyAdSkipped {
    if (self.isDisposed) { return; }
    if (self.currentPod == nil) { return; }
    [self sendVideoAdEvent:@"AD_SKIP"];
}

#pragma mark - MTPlayheadStateMachineDelegate

- (void)stateMachine:(MTPlayheadStateMachine *)sm enteredBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    self.currentBreak = brk;
    [self sendAdBreakStart];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
          enteredPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    self.currentPod = pod;
    self.currentQuartileNumber = 0;
    [self sendRequest];
    [self sendStart];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
     crossedQuartile:(NSInteger)quartile
               inPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    self.currentQuartileNumber = quartile;
    [self sendAdQuartile];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
           exitedPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    [self sendEnd];
    self.currentPod = nil;
    self.currentQuartileNumber = 0;
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm exitedBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    [self sendAdBreakEnd];
    self.currentBreak = nil;
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
         raisedError:(MTMergedScheduleError *)error {
    if (self.isDisposed) { return; }
    NSString *codeName = NSStringFromMTAdErrorCode(error.errorCode);
    NSDictionary *attrs = @{
        @"errorCode": codeName ?: @"UNKNOWN",
        @"errorMessage": error.message ?: codeName ?: @"",
    };
    [self sendVideoErrorEvent:@"AD_ERROR" attributes:attrs];
}

#pragma mark - NRVideoTracker attribute overrides

- (NSNumber *)getIsAd {
    return @1;
}

- (NSString *)getAdBreakId {
    return self.currentBreak.availId ?: @"";
}

- (NSString *)getAdCreativeId {
    return self.currentPod.creativeId ?: @"";
}

- (NSNumber *)getAdQuartile {
    return @(self.currentQuartileNumber);
}

- (NSString *)getAdPartner {
    return self.currentPod.adSystem ?: @"";
}

- (NSString *)getTrackerName {
    return @"NRMediaTailorTracker";
}

- (NSString *)getTrackerVersion {
    return @"4.2.0";
}

- (NSMutableDictionary *)getAttributes:(NSString *)action
                            attributes:(NSDictionary *)attributes {
    NSMutableDictionary *attrs = [super getAttributes:action attributes:attributes];

    MTAdBreak *brk = self.currentBreak;
    MTAdPod *pod = self.currentPod;

    // Break-level attributes. Bug B7: always emit programDateTime keys, even
    // when empty, so live-stream consumers can reliably correlate.
    if (brk != nil) {
        attrs[@"availId"]              = brk.availId ?: @"";
        attrs[@"availProgramDateTime"] = brk.availProgramDateTime ?: @"";
        attrs[@"noFill"]               = @(brk.isNoFill);
        attrs[@"podCountMismatch"]     = @(brk.podCountMismatch);
    } else {
        attrs[@"availId"]              = @"";
        attrs[@"availProgramDateTime"] = @"";
    }

    // Pod-level attributes.
    if (pod != nil) {
        attrs[@"adId"]              = pod.adId ?: @"";
        attrs[@"creativeId"]        = pod.creativeId ?: @"";
        attrs[@"adTitle"]           = pod.adTitle ?: @"";
        attrs[@"adSystem"]          = pod.adSystem ?: @"";
        attrs[@"creativeSequence"]  = pod.creativeSequence ?: @"";
        attrs[@"vastAdId"]          = pod.vastAdId ?: @"";
        attrs[@"skipOffset"]        = pod.skipOffset ?: @"";
        attrs[@"adProgramDateTime"] = pod.adProgramDateTime ?: @"";
        attrs[@"isBumper"]          = @(pod.isBumper);
    } else {
        attrs[@"adProgramDateTime"] = @"";
    }

    return attrs;
}

@end
