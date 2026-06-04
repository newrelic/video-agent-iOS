//
//  ViewController.m
//  SimplePlayerWithAds
//
//  Created by Andreu Santaren on 2/3/21.
//

#import "ViewController.h"
#import <NewRelicVideoCore.h>

@import AVKit;

// ---------------------------------------------------------------------------
// CR Test case selector — confirmed crash scenarios (CR-1, CR-2, CR-3)
// ---------------------------------------------------------------------------
typedef NS_ENUM(NSInteger, CRTestCase) {
    CRTestAll = 0,
    CRTest1   = 1,   // setUserId: on content-only tracker → NSNull crash
    CRTest2   = 2,   // setGlobalAttribute:value: → NSNull crash
    CRTest3   = 3,   // setGlobalAttribute:value:action: → NSNull crash
};

// ---------------------------------------------------------------------------
// DQ Test case selector — data quality fixes (no crash, wrong stored value)
// Before fix: NR iOS Agent coerces types to strings
// After fix:  SDK sanitizes at storage boundary — correct types in NRDB
// ---------------------------------------------------------------------------
typedef NS_ENUM(NSInteger, DQTestCase) {
    DQTestAll = 0,
    DQTest1   = 1,   // NSDate → before: string description, after: epoch seconds
    DQTest2   = 2,   // NSURL  → before: string description, after: dropped with log
    DQTest3   = 3,   // NSDictionary with NSDate → before: inner date as string, after: epoch
    DQTest4   = 4,   // nil    → before: no-op, after: explicit silent drop
};

// ---------------------------------------------------------------------------
// REC Test case selector — record event sanity (no crash, verify event dispatch)
// NOTE: recordCustomEvent attributes bypass setAttribute: sanitization path —
// they go through generateAttributes:append: directly. So REC-3 (NSDate in
// recordCustomEvent) behaves the SAME on 4.1.2 and fix branch — NR agent
// coerces to string on both. This is a known gap, tracked for future fix.
// ---------------------------------------------------------------------------
typedef NS_ENUM(NSInteger, RECTestCase) {
    RECTestAll = 0,
    RECTest1   = 1,   // recordCustomEvent on specific tracker — verify event fires with tracker attrs
    RECTest2   = 2,   // recordCustomEvent nil trackerId — broadcasts to all active trackers
    RECTest3   = 3,   // recordCustomEvent with NSDate in attrs — same on both builds (bypasses sanitization)
    RECTest4   = 4,   // recordEvent: raw dispatch — verify event fires without tracker enrichment
};

@interface ViewController ()

@property (nonatomic) AVPlayerViewController *playerController;
@property (nonatomic) NSInteger trackerId;
@property (nonatomic) NSString *multipleAdTagURL;
@property (nonatomic) IMAAVPlayerContentPlayhead *contentPlayhead;
@property (nonatomic) IMAAdsLoader *adsLoader;
@property (nonatomic) IMAAdsManager *adsManager;

@end

@implementation ViewController

- (IBAction)clickBunnyVideo:(id)sender {
    [self playVideo:@"http://docs.evostream.com/sample_content/assets/hls-bunny-rangerequest/playlist.m3u8"];
}

- (IBAction)clickSintelVideo:(id)sender {
    [self playVideo:@"https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8"];
}

- (IBAction)clickAirshowLive:(id)sender {
    [self playVideo:@"https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8"];
}

// CR Test button — shows picker then launches a content-only player
- (IBAction)clickCRTest:(id)sender {
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:@"CR Test — PR #208"
        message:@"Pick a crash scenario to run.\nCR-1/2/3 crash immediately.\nCR-4/5/6/7 crash at harvest (~60s)."
        preferredStyle:UIAlertControllerStyleActionSheet];

    NSDictionary *cases = @{
        @(CRTest1):   @"CR-1  setUserId:",
        @(CRTest2):   @"CR-2  setGlobalAttribute:value:",
        @(CRTest3):   @"CR-3  setGlobalAttribute:value:action:",
        @(CRTestAll): @"▶▶ Run All CR-1 to CR-3",
    };

    NSArray *order = @[@(CRTest1), @(CRTest2), @(CRTest3), @(CRTestAll)];

    for (NSNumber *key in order) {
        CRTestCase testCase = (CRTestCase)[key integerValue];
        [sheet addAction:[UIAlertAction
            actionWithTitle:cases[key]
            style:(testCase == CRTestAll ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault)
            handler:^(UIAlertAction *action) {
                [self launchCRTestWithCase:testCase];
            }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    // iPad popover anchor
    sheet.popoverPresentationController.sourceView = (UIView *)sender;
    [self presentViewController:sheet animated:YES completion:nil];
}

// Sets up a real content-only AVPlayer, registers it, runs the chosen test case
- (void)launchCRTestWithCase:(CRTestCase)testCase {
    NSString *videoURL = @"http://docs.evostream.com/sample_content/assets/hls-bunny-rangerequest/playlist.m3u8";
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:videoURL]];

    AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
    playerVC.player = player;
    playerVC.showsPlaybackControls = YES;

    // content-only — adEnabled:NO is the exact crash precondition
    NRVAVideoPlayerConfiguration *config = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"CR_Test_ContentOnly"
        player:player
        adEnabled:NO
        customAttributes:@{@"crTest": @(testCase), @"pr": @"208"}];
    NSInteger crTrackerId = [NRVAVideo addPlayer:config];

    [self runCRTest:testCase trackerId:crTrackerId];

    self.playerController = playerVC;
    self.trackerId = crTrackerId;
    [self presentViewController:playerVC animated:YES completion:^{
        [player play];
    }];
}

#pragma mark - Crash Regression Test Runner

/**
 Runs one or all CR test cases.
 CR-1/2/3 crash immediately on 4.1.2 (NSNull sent a message).
 CR-4/5/6/7 crash at harvest ~60s later on 4.1.2.
 All should PASS silently after the PR fix is applied.
 */
- (void)runCRTest:(CRTestCase)testCase trackerId:(NSInteger)trackerId {
    NSLog(@"[CrashTest] ---- Running %@ ----",
          testCase == CRTestAll ? @"All CR-1 to CR-3" : [NSString stringWithFormat:@"CR-%ld", (long)testCase]);

    BOOL runAll = (testCase == CRTestAll);

    // CR-1: setUserId — loops all tracker pairs, touches pair.second
    // pair.second = NSNull on content-only tracker → truthy → message crash
    if (runAll || testCase == CRTest1) {
        [NRVAVideo setUserId:@"cr-test-user"];
        NSLog(@"[CrashTest] CR-1 PASS — setUserId did not crash");
    }

    // CR-2: setGlobalAttribute:value: — same NSNull path
    if (runAll || testCase == CRTest2) {
        [NRVAVideo setGlobalAttribute:@"cr2_key" value:@"cr2_value"];
        NSLog(@"[CrashTest] CR-2 PASS — setGlobalAttribute did not crash");
    }

    // CR-3: setGlobalAttribute:value:action: — same NSNull path, action-filtered
    if (runAll || testCase == CRTest3) {
        [NRVAVideo setGlobalAttribute:@"cr3_key" value:@"cr3_value" action:@"CONTENT_START"];
        NSLog(@"[CrashTest] CR-3 PASS — setGlobalAttribute:action: did not crash");
    }

    NSLog(@"[CrashTest] ---- Done ----");
}

#pragma mark - Data Quality Tests

// DQ Test button — shows picker, launches a player with ads enabled,
// sets attributes with various types and logs the stored value.
// Run once on 4.1.2 (observe before), once on fix branch (observe after).
- (IBAction)clickDQTest:(id)sender {
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:@"DQ Test — PR #208"
        message:@"Data quality fixes — no crash.\nWatch console for stored value.\nBefore fix: strings. After fix: correct types."
        preferredStyle:UIAlertControllerStyleActionSheet];

    NSDictionary *cases = @{
        @(DQTest1):   @"DQ-1  NSDate attribute",
        @(DQTest2):   @"DQ-2  NSURL attribute",
        @(DQTest3):   @"DQ-3  NSDictionary with NSDate",
        @(DQTest4):   @"DQ-4  nil attribute",
        @(DQTestAll): @"▶▶ Run All DQ-1 to DQ-4",
    };

    NSArray *order = @[@(DQTest1), @(DQTest2), @(DQTest3), @(DQTest4), @(DQTestAll)];

    for (NSNumber *key in order) {
        DQTestCase testCase = (DQTestCase)[key integerValue];
        [sheet addAction:[UIAlertAction
            actionWithTitle:cases[key]
            style:(testCase == DQTestAll ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault)
            handler:^(UIAlertAction *action) {
                [self launchDQTestWithCase:testCase];
            }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = (UIView *)sender;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)launchDQTestWithCase:(DQTestCase)testCase {
    NSString *videoURL = @"http://docs.evostream.com/sample_content/assets/hls-bunny-rangerequest/playlist.m3u8";
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:videoURL]];

    AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
    playerVC.player = player;
    playerVC.showsPlaybackControls = YES;

    NRVAVideoPlayerConfiguration *config = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"DQ_Test"
        player:player
        adEnabled:NO
        customAttributes:@{@"dqTest": @(testCase), @"pr": @"208"}];
    NSInteger dqTrackerId = [NRVAVideo addPlayer:config];

    [self runDQTest:testCase trackerId:dqTrackerId];

    self.playerController = playerVC;
    self.trackerId = dqTrackerId;
    [self presentViewController:playerVC animated:YES completion:^{
        [player play];
    }];
}

/**
 DQ test runner — sets attribute values of various types and logs what was stored.
 Console output differs between 4.1.2 and fix branch:

   4.1.2 (before fix):
     DQ-1: cr4_date = "2026-06-04 06:49:21 +0000"   ← NSDate as string description
     DQ-2: cr5_url  = "https://example.com"          ← NSURL as string description
     DQ-3: cr6_dict = { when = "2026-06-04..."; }    ← inner date as string
     DQ-4: (nothing logged — nil is a no-op)

   fix/tracker-safety-followups (after fix):
     DQ-1: cr4_date = 1748765361                     ← epoch seconds NSNumber
     DQ-2: DROPPED with NRVA_ERROR_LOG               ← not stored at all
     DQ-3: cr6_dict = { when = 1748765361; }         ← inner date as epoch
     DQ-4: (nothing logged — silent drop, no error)
 */
- (void)runDQTest:(DQTestCase)testCase trackerId:(NSInteger)trackerId {
    NSLog(@"[DQTest] ---- Running %@ ----",
          testCase == DQTestAll ? @"All DQ-1 to DQ-4" : [NSString stringWithFormat:@"DQ-%ld", (long)testCase]);

    BOOL runAll = (testCase == DQTestAll);

    // Track what we set so we can print a summary at the end
    NSMutableDictionary *summary = [NSMutableDictionary dictionary];

    // DQ-1: NSDate
    // Before: stored as string description e.g. "2026-06-04 06:49:21 +0000"
    // After:  stored as epoch seconds e.g. 1748765361 (NSNumber)
    if (runAll || testCase == DQTest1) {
        NSDate *now = [NSDate date];
        summary[@"DQ-1 input"] = [NSString stringWithFormat:@"NSDate — %@", now];
        summary[@"DQ-1 epoch"] = [NSString stringWithFormat:@"%.0f", [now timeIntervalSince1970]];
        [NRVAVideo setAttribute:trackerId key:@"dq1_date" value:now];
    }

    // DQ-2: NSURL
    // Before: stored as string description e.g. "https://example.com/stream.m3u8"
    // After:  dropped — key never written, NRVA_ERROR_LOG fires
    if (runAll || testCase == DQTest2) {
        NSURL *url = [NSURL URLWithString:@"https://example.com/stream.m3u8"];
        summary[@"DQ-2 input"] = [NSString stringWithFormat:@"NSURL — %@", url];
        summary[@"DQ-2 expect (before)"] = @"stored as string";
        summary[@"DQ-2 expect (after)"] = @"DROPPED — error log fires";
        [NRVAVideo setAttribute:trackerId key:@"dq2_url" value:url];
    }

    // DQ-3: NSDictionary with NSDate inside
    // Before: inner date stored as string description
    // After:  inner date recursively converted to epoch seconds
    if (runAll || testCase == DQTest3) {
        NSDate *now = [NSDate date];
        NSDictionary *dict = @{@"label": @"session-meta", @"startedAt": now};
        summary[@"DQ-3 input"] = [NSString stringWithFormat:@"NSDictionary — startedAt: %@", now];
        summary[@"DQ-3 epoch"] = [NSString stringWithFormat:@"%.0f", [now timeIntervalSince1970]];
        [NRVAVideo setAttribute:trackerId key:@"dq3_dict" value:dict];
    }

    // DQ-4: nil
    // Before: ObjC nil message — silent no-op
    // After:  explicit early return — still silent, no error log
    if (runAll || testCase == DQTest4) {
        summary[@"DQ-4 input"] = @"nil — silent on both builds, no log expected";
        [NRVAVideo setAttribute:trackerId key:@"dq4_nil" value:nil];
    }

    // --- Summary block — search console for [DQTest][SUMMARY] ---
    NSLog(@"[DQTest][SUMMARY] ----------------------------------------");
    for (NSString *key in [[summary allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        NSLog(@"[DQTest][SUMMARY]  %@ = %@", key, summary[key]);
    }
    NSLog(@"[DQTest][SUMMARY]  dq1_date stored value → check [NRVideoAgent][DEBUG] Set attribute for tracker %ld: dq1_date", (long)trackerId);
    NSLog(@"[DQTest][SUMMARY]  dq2_url  stored value → check [NRVideoAgent][DEBUG] Set attribute (before) or ERROR (after)");
    NSLog(@"[DQTest][SUMMARY]  dq3_dict stored value → check [NRVideoAgent][DEBUG] Set attribute for tracker %ld: dq3_dict", (long)trackerId);
    NSLog(@"[DQTest][SUMMARY] ----------------------------------------");
    NSLog(@"[DQTest][SUMMARY]  Filter console by: [DQTest][SUMMARY]");
    NSLog(@"[DQTest][SUMMARY]  Wait ~60s for harvest — confirm values in NRDB");
    NSLog(@"[DQTest][SUMMARY] ----------------------------------------");
}

#pragma mark - Record Event Tests

- (IBAction)clickRECTest:(id)sender {
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:@"REC Test — PR #208"
        message:@"Record event sanity tests.\nNo before/after crash difference.\nVerify events appear in console and NRDB."
        preferredStyle:UIAlertControllerStyleActionSheet];

    NSDictionary *cases = @{
        @(RECTest1):   @"REC-1  recordCustomEvent (specific tracker)",
        @(RECTest2):   @"REC-2  recordCustomEvent (nil — all trackers)",
        @(RECTest3):   @"REC-3  recordCustomEvent with NSDate (bypass check)",
        @(RECTest4):   @"REC-4  recordEvent raw dispatch",
        @(RECTestAll): @"▶▶ Run All REC-1 to REC-4",
    };

    NSArray *order = @[@(RECTest1), @(RECTest2), @(RECTest3), @(RECTest4), @(RECTestAll)];

    for (NSNumber *key in order) {
        RECTestCase testCase = (RECTestCase)[key integerValue];
        [sheet addAction:[UIAlertAction
            actionWithTitle:cases[key]
            style:(testCase == RECTestAll ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault)
            handler:^(UIAlertAction *action) {
                [self launchRECTestWithCase:testCase];
            }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = (UIView *)sender;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)launchRECTestWithCase:(RECTestCase)testCase {
    NSString *videoURL = @"http://docs.evostream.com/sample_content/assets/hls-bunny-rangerequest/playlist.m3u8";
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:videoURL]];

    AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
    playerVC.player = player;
    playerVC.showsPlaybackControls = YES;

    NRVAVideoPlayerConfiguration *config = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"REC_Test"
        player:player
        adEnabled:NO
        customAttributes:@{@"recTest": @(testCase), @"pr": @"208"}];
    NSInteger recTrackerId = [NRVAVideo addPlayer:config];

    self.playerController = playerVC;
    self.trackerId = recTrackerId;

    // REC-2 and REC-4 fire at init — app lifecycle / raw dispatch, not tied to playback
    BOOL needsPlayback = (testCase == RECTest1 || testCase == RECTest3 || testCase == RECTestAll);
    if (!needsPlayback) {
        [self runRECTest:testCase trackerId:recTrackerId];
    }

    [self presentViewController:playerVC animated:YES completion:^{
        [player play];

        if (needsPlayback) {
            // Wait for CONTENT_START to fire (~2-3s) so tracker has playback context:
            // contentPlayhead, timeSinceStarted, bitrate etc. are populated
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                NSLog(@"[RECTest][SUMMARY]  Playback active — firing runtime REC tests now");
                [self runRECTest:testCase trackerId:recTrackerId];
            });
        }
    }];
}

/**
 REC test runner — verifies recordCustomEvent and recordEvent fire correctly.
 Filter console by [RECTest][SUMMARY] to see all results in one block.

 REC-1: recordCustomEvent on specific tracker
   → event appears enriched with full tracker attributes (playerName, viewId, etc.)
   → NRDB: SELECT * FROM VideoAction WHERE actionName = 'USER_BOOKMARK'

 REC-2: recordCustomEvent nil trackerId (broadcast)
   → event fires once per active tracker
   → NRDB: SELECT * FROM VideoAction WHERE actionName = 'APP_FOREGROUND'

 REC-3: recordCustomEvent with NSDate in attributes
   → IMPORTANT: bypasses setAttribute: sanitization — NR agent coerces to string on both builds
   → Same result on 4.1.2 AND fix branch — date stored as string description
   → Known gap: recordCustomEvent attrs not sanitized at SDK boundary

 REC-4: recordEvent raw dispatch
   → fires directly to harvest, no tracker enrichment
   → NRDB: SELECT * FROM VideoAction WHERE actionName = 'RAW_CUSTOM_EVENT'
 */
- (void)runRECTest:(RECTestCase)testCase trackerId:(NSInteger)trackerId {
    NSLog(@"[RECTest][SUMMARY] ----------------------------------------");
    NSLog(@"[RECTest][SUMMARY]  Running %@",
          testCase == RECTestAll ? @"All REC-1 to REC-4" : [NSString stringWithFormat:@"REC-%ld", (long)testCase]);

    BOOL runAll = (testCase == RECTestAll);

    // REC-1: recordCustomEvent on specific tracker — fires DURING playback
    // Event enriched with contentPlayhead, timeSinceStarted, bitrate etc.
    // NRDB: SELECT * FROM VideoAction WHERE actionName = 'USER_BOOKMARK'
    if (runAll || testCase == RECTest1) {
        [NRVAVideo recordCustomEvent:@"USER_BOOKMARK"
                          trackerId:@(trackerId)
                         attributes:@{
                             @"bookmarkPosition": @(42000),
                             @"contentLabel": @"bunny-video",
                             @"recTest": @"REC-1",
                             @"firedAt": @"runtime-after-content-start"
                         }];
        NSLog(@"[RECTest][SUMMARY]  REC-1 fired at runtime — check contentPlayhead/timeSinceStarted are populated");
        NSLog(@"[RECTest][SUMMARY]  REC-1 NRDB: SELECT * FROM VideoAction WHERE actionName = 'USER_BOOKMARK'");
    }

    // REC-2: recordCustomEvent nil trackerId — fires AT INIT (app lifecycle, not playback)
    // Broadcasts to all active trackers
    // NRDB: SELECT * FROM VideoAction WHERE actionName = 'APP_FOREGROUND'
    if (runAll || testCase == RECTest2) {
        [NRVAVideo recordCustomEvent:@"APP_FOREGROUND"
                          trackerId:nil
                         attributes:@{
                             @"source": @"REC-2-broadcast",
                             @"recTest": @"REC-2",
                             @"firedAt": @"init"
                         }];
        NSLog(@"[RECTest][SUMMARY]  REC-2 fired at init — broadcast to all trackers");
        NSLog(@"[RECTest][SUMMARY]  REC-2 NRDB: SELECT * FROM VideoAction WHERE actionName = 'APP_FOREGROUND'");
    }

    // REC-3: recordCustomEvent with NSDate — fires DURING playback
    // Bypasses setAttribute: sanitization — date stored as string on BOTH builds
    // Known gap: recordCustomEvent attrs not sanitized at SDK level
    if (runAll || testCase == RECTest3) {
        NSDate *now = [NSDate date];
        [NRVAVideo recordCustomEvent:@"TIMED_ACTION"
                          trackerId:@(trackerId)
                         attributes:@{
                             @"eventTimestamp": now,
                             @"recTest": @"REC-3",
                             @"firedAt": @"runtime-after-content-start"
                         }];
        NSLog(@"[RECTest][SUMMARY]  REC-3 fired at runtime — eventTimestamp: '%@' (string on BOTH builds)", now);
        NSLog(@"[RECTest][SUMMARY]  REC-3 NOTE: bypasses sanitization — known gap, future fix needed");
    }

    // REC-4: recordEvent raw dispatch — fires AT INIT (no tracker enrichment needed)
    // NRDB: SELECT * FROM VideoAction WHERE actionName = 'RAW_CUSTOM_EVENT'
    if (runAll || testCase == RECTest4) {
        [NRVAVideo recordEvent:@"RAW_CUSTOM_EVENT"
                    attributes:@{
                        @"source": @"REC-4-raw",
                        @"recTest": @"REC-4",
                        @"firedAt": @"init",
                        @"value": @(100)
                    }];
        NSLog(@"[RECTest][SUMMARY]  REC-4 fired at init — raw, no tracker enrichment");
        NSLog(@"[RECTest][SUMMARY]  REC-4 NRDB: SELECT * FROM VideoAction WHERE actionName = 'RAW_CUSTOM_EVENT'");
    }

    NSLog(@"[RECTest][SUMMARY]  Wait ~60s for harvest — check NRDB for all events above");
    NSLog(@"[RECTest][SUMMARY] ----------------------------------------");
}

#pragma mark - Normal Playback

- (void)viewDidLoad {
    [super viewDidLoad];

    self.multipleAdTagURL = @"http://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/ad_rule_samples&ciu_szs=300x250&ad_rule=1&impl=s&gdfp_req=1&env=vp&output=xml_vmap1&unviewed_position_start=1&cust_params=sample_ar%3Dpremidpostpod%26deployment%3Dgmf-js&cmsid=496&vid=short_onecue&correlator=";

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)appDidBecomeActive:(NSNotification *)notif {
    if (self.adsManager != nil) {
        [self.adsManager resume];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.playerController.isBeingDismissed) {
        [NRVAVideo releaseTracker:self.trackerId];
        [self releaseAds];
    }
}

- (void)playVideo:(NSString *)videoURL {
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:videoURL]];
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = player;
    self.playerController.showsPlaybackControls = YES;

    NSDictionary *customAttributes = @{
        @"contentType": @"video-on-demand",
        @"playerVersion": @"1.0.0",
        @"customTag": @"SimplePlayerWithAds"
    };

    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"TEST_ADS"
        player:player
        adEnabled:YES
        customAttributes:customAttributes];

    self.trackerId = [NRVAVideo addPlayer:playerConfig];

    [NRVAVideo recordCustomEvent:@"PLAYER_SETUP_COMPLETE"
                      trackerId:nil
                     attributes:@{
                         @"setupMethod": @"configuration-based",
                         @"customAttr1": @"1080p",
                         @"customAttr2": @"720p"
                     }];

    [NRVAVideo recordCustomEvent:@"VIDEO_READY"
                      trackerId:@(self.trackerId)
                     attributes:@{
                         @"videoURL": videoURL,
                         @"hasAds": @YES,
                     }];

    [self setupAds:player];

    [self presentViewController:self.playerController animated:YES completion:^{
        [self.playerController.player play];
        [self requestAds];
    }];
}

- (void)setupAds:(AVPlayer *)player {
    self.contentPlayhead = [[IMAAVPlayerContentPlayhead alloc] initWithAVPlayer:player];
    self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
    self.adsLoader.delegate = self;
}

- (void)requestAds {
    IMAAdDisplayContainer *adDisplayContainer = [[IMAAdDisplayContainer alloc]
        initWithAdContainer:self.playerController.view
             viewController:self.playerController];
    IMAAdsRequest *request = [[IMAAdsRequest alloc]
        initWithAdTagUrl:self.multipleAdTagURL
      adDisplayContainer:adDisplayContainer
         contentPlayhead:self.contentPlayhead
             userContext:nil];
    [self.adsLoader requestAdsWithRequest:request];
}

- (void)releaseAds {
    [self.adsLoader contentComplete];
    if (self.adsManager != nil) {
        [self.adsManager destroy];
        self.adsManager = nil;
    }
    self.adsLoader = nil;
}

#pragma mark - AdsLoader delegate

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
    if (self.adsManager != nil) {
        [self.adsManager destroy];
        self.adsManager = nil;
    }
    self.adsManager = adsLoadedData.adsManager;
    self.adsManager.delegate = self;
    [self.adsManager initializeWithAdsRenderingSettings:nil];
    NSLog(@"Ads Loader Loaded Data");
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    NSLog(@"Error loading ads: %@", adErrorData.adError.message);
    [NRVAVideo handleAdError:@(self.trackerId) error:adErrorData.adError];
    [self.playerController.player play];
}

#pragma mark - AdsManager delegate

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdEvent:(IMAAdEvent *)event {
    NSLog(@"Ads Manager did receive event = %@", event.typeString);
    [NRVAVideo handleAdEvent:@(self.trackerId) event:event adsManager:adsManager];
    if (event.type == kIMAAdEvent_LOADED) {
        [adsManager start];
    }
}

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdError:(IMAAdError *)error {
    NSLog(@"Ads Manager received error = %@", error.message);
    [NRVAVideo handleAdError:@(self.trackerId) error:error adsManager:adsManager];
}

- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager {
    NSLog(@"Ads request pause");
    [NRVAVideo sendAdBreakStart:@(self.trackerId)];
    [self.playerController.player pause];
}

- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager {
    NSLog(@"Ads request resume");
    [NRVAVideo sendAdBreakEnd:@(self.trackerId)];
    [self.playerController.player play];
}

@end
