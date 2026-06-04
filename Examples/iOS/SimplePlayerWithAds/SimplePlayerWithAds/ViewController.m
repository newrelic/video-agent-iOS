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
// CR Test case selector — only confirmed crash scenarios (CR-1, CR-2, CR-3)
// CRTestAll runs all three in sequence (first crash stops the rest on 4.1.2)
// ---------------------------------------------------------------------------
typedef NS_ENUM(NSInteger, CRTestCase) {
    CRTestAll = 0,
    CRTest1   = 1,   // setUserId: on content-only tracker → NSNull crash
    CRTest2   = 2,   // setGlobalAttribute:value: → NSNull crash
    CRTest3   = 3,   // setGlobalAttribute:value:action: → NSNull crash
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
