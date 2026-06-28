//
//  ViewController.m
//  SimplePlayerWithAds
//
//  Created by Andreu Santaren on 2/3/21.
//

#import "ViewController.h"
#import "MediaTailorSamples.h"
#import <NewRelicVideoCore.h>
#import <NRMediaTailorTracker/NRMediaTailorTracker.h>
#import <NRMediaTailorTracker/NRTrackerMediaTailor.h>
#import <NRMediaTailorTracker/MTDetector.h>

@import AVKit;

@interface ViewController ()

@property (nonatomic) AVPlayerViewController *playerController;
@property (nonatomic) NSInteger trackerId;
@property (nonatomic) NSString *multipleAdTagURL;
@property (nonatomic) IMAAVPlayerContentPlayhead *contentPlayhead;
@property (nonatomic) IMAAdsLoader *adsLoader;
@property (nonatomic) IMAAdsManager *adsManager;

/// MediaTailor tracker for the `clickMediaTailorSample:` flow. Nil while
/// any of the IMA buttons is the active flow.
@property (nonatomic, strong, nullable) NRTrackerMediaTailor *mediaTailorTracker;

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

/// MediaTailor server-side ad-insertion smoke path. Uses
/// `NRTrackerMediaTailor` instead of the IMA ads stack — MediaTailor
/// ads are stitched into the HLS manifest, so the client does not
/// instantiate IMAAdsLoader/AdsManager. Override the URL via
/// NSUserDefaults `MediaTailorSampleURL` or the `MT_SAMPLE_URL`
/// environment variable; see `MediaTailorSamples.h`.
- (IBAction)clickMediaTailorSample:(id)sender {
    [self playMediaTailorVideo:[MediaTailorSamples defaultSampleURLString]];
}

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
    [self.mediaTailorTracker dispose];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // User closed the player
    if (self.playerController.isBeingDismissed) {

        //Stop tracking
        [NRVAVideo releaseTracker:@(self.trackerId)];

        [self releaseAds];
        [self.mediaTailorTracker dispose];
        self.mediaTailorTracker = nil;
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

    // ✅ GLOBAL custom event (trackerId = nil sends to ALL trackers)
    [NRVAVideo recordCustomEvent:@"PLAYER_SETUP_COMPLETE"
                      trackerId:nil
                     attributes:@{
                         @"setupMethod": @"configuration-based",
                         @"customAttr1": @"1080p",
                         @"customAttr2": @"720p"
                     }];

    // ✅ TRACKER-SPECIFIC custom event (enriched with video attributes)
    [NRVAVideo recordCustomEvent:@"VIDEO_READY"
                      trackerId:@(self.trackerId)
                     attributes:@{
                         @"videoURL": videoURL,
                         @"hasAds": @YES,
                         @"customAttr1": @"enhanced",
                         @"customAttr2": @"with_video_context"
                     }];

    [self setupAds:player];

    [self presentViewController:self.playerController animated:YES completion:^{
        [self.playerController.player play];
        [self requestAds];
    } ];
}

/// MediaTailor playback path. Spins up an AVPlayer, attaches a
/// NRTrackerMediaTailor, and registers a content tracker alongside.
/// Per FEATURE_SPEC §9 "Definition of Done": run with a real
/// MediaTailor URL, capture a proxy log proving
/// `/v1/tracking/<sessionId>` round-trips `nextToken`, and confirm in
/// NRDB that AD_BREAK_START → AD_START → 3×AD_QUARTILE → AD_END →
/// AD_BREAK_END fires for at least one ad break.
- (void)playMediaTailorVideo:(NSString *)videoURLString {
    NSURL *videoURL = [NSURL URLWithString:videoURLString];
    if (videoURL == nil) {
        NSLog(@"❌ [MediaTailor] Invalid URL: %@", videoURLString);
        return;
    }
    if (![MTDetector isMediaTailorURL:videoURL]) {
        NSLog(@"⚠️ [MediaTailor] URL does not look like a MediaTailor session — "
              @"the tracker will not activate. Override via NSUserDefaults "
              @"`MediaTailorSampleURL` or env `MT_SAMPLE_URL`.");
    }

    AVPlayer *player = [AVPlayer playerWithURL:videoURL];
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = player;
    self.playerController.showsPlaybackControls = YES;

    // Set up the MediaTailor tracker. Unlike the IMA path, MediaTailor
    // ads are server-side-stitched, so we do NOT instantiate
    // IMAAdsLoader / IMAAdsManager.
    self.mediaTailorTracker = [[NRTrackerMediaTailor alloc] init];
    [self.mediaTailorTracker setPlayer:player];

    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"MediaTailorPlayer"
        player:player
        adEnabled:YES
        customAttributes:@{
            @"videoURL": videoURLString,
            @"adStitching": @"server-side",
            @"customTag": @"SimplePlayerWithAds-MediaTailor",
        }];
    self.trackerId = [NRVAVideo addPlayer:playerConfig];

    NSLog(@"🎥 [MediaTailor] Started MediaTailor video tracking with ID: %ld", (long)self.trackerId);

    [self presentViewController:self.playerController animated:YES completion:^{
        [self.playerController.player play];
        NSLog(@"▶️ [MediaTailor] Playback started — feed a parsed schedule via "
              @"-[mediaTailorTracker startTrackingWithSchedule:] once your "
              @"app has both the manifest and tracking JSON.");
    }];
}

- (void)setupAds:(AVPlayer *)player {
    // Set up IMA stuff
    self.contentPlayhead = [[IMAAVPlayerContentPlayhead alloc] initWithAVPlayer:player];
    self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
    self.adsLoader.delegate = self;
}

- (void)requestAds {
    // Create ad display container for ad rendering.
    IMAAdDisplayContainer *adDisplayContainer = [[IMAAdDisplayContainer alloc] initWithAdContainer:self.playerController.view viewController:self.playerController];
    // Create an ad request with our ad tag, display container, and optional user context.
    IMAAdsRequest *request = [[IMAAdsRequest alloc] initWithAdTagUrl:self.multipleAdTagURL
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

    // 🤖 MUCH SIMPLER: One-line ad event handling!
    [NRVAVideo handleAdEvent:@(self.trackerId) event:event adsManager:adsManager];

    if (event.type == kIMAAdEvent_LOADED) {
        NSLog(@"Ads Manager call start()");
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
