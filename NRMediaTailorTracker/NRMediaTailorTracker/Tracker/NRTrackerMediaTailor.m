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

NSString * const NRMediaTailorTrackerErrorDomain = @"NRMediaTailorTracker";

@interface NRTrackerMediaTailor () <MTPlayheadStateMachineDelegate>

@property (nonatomic, strong, nullable, readwrite) MTPlayheadStateMachine *stateMachine;

@property (nonatomic, weak, nullable) MTAdBreak *currentBreak;
@property (nonatomic, weak, nullable) MTAdPod *currentPod;
@property (nonatomic, assign) NSInteger currentQuartileNumber;

@end

@implementation NRTrackerMediaTailor

- (id<MTManifestParser>)manifestParser {
    if (_manifestParser == nil) {
        _manifestParser = [[MTHlsParser alloc] init];
    }
    return _manifestParser;
}

#pragma mark - Public lifecycle

- (void)startTrackingWithSchedule:(MergedSchedule *)schedule {
    NSParameterAssert(schedule != nil);
    [self stopTracking];
    self.stateMachine = [[MTPlayheadStateMachine alloc] initWithSchedule:schedule
                                                    playheadPollInterval:0.250];
    self.stateMachine.delegate = self;
}

- (void)stopTracking {
    [self.stateMachine detachFromPlayer];
    self.stateMachine = nil;
    self.currentBreak = nil;
    self.currentPod = nil;
    self.currentQuartileNumber = 0;
}

- (void)notifyAdSkipped {
    if (self.currentPod == nil) { return; }
    [self sendVideoAdEvent:@"AD_SKIP"];
}

#pragma mark - MTPlayheadStateMachineDelegate

- (void)stateMachine:(MTPlayheadStateMachine *)sm enteredBreak:(MTAdBreak *)brk {
    self.currentBreak = brk;
    [self sendAdBreakStart];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
          enteredPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    self.currentPod = pod;
    self.currentQuartileNumber = 0;
    [self sendRequest];
    [self sendStart];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
     crossedQuartile:(NSInteger)quartile
               inPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    self.currentQuartileNumber = quartile;
    [self sendAdQuartile];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
           exitedPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    [self sendEnd];
    self.currentPod = nil;
    self.currentQuartileNumber = 0;
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm exitedBreak:(MTAdBreak *)brk {
    [self sendAdBreakEnd];
    self.currentBreak = nil;
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
         raisedError:(MTMergedScheduleError *)error {
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
