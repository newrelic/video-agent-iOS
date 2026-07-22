//
//  ViewController.m
//  SimplePlayerWithAds
//
//  Created by Andreu Santaren on 2/3/21.
//

#import "ViewController.h"
#import <NewRelicVideoCore.h>

@import AVKit;

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

- (void)viewDidLoad {
    [super viewDidLoad];

    self.multipleAdTagURL = @"http://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/ad_rule_samples&ciu_szs=300x250&ad_rule=1&impl=s&gdfp_req=1&env=vp&output=xml_vmap1&unviewed_position_start=1&cust_params=sample_ar%3Dpremidpostpod%26deployment%3Dgmf-js&cmsid=496&vid=short_onecue&correlator=";

    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [self setupGamedayButtons];
}

static NSString * const kGamedayAssetURL = @"https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8";
static const double kTC1LowBitrate = 400000;
static const double kTC1MidBitrate = 1100000;
static const double kTC1TopBitrate = 4000000;

- (void)setupGamedayButtons {
    NSArray<NSString *> *titles = @[@"Run TC0: Baseline", @"Run TC1: Happy Path", @"Run TC2: Stress/Error"];
    NSArray *selectors = @[
        [NSValue valueWithPointer:@selector(runTC0)],
        [NSValue valueWithPointer:@selector(runTC1)],
        [NSValue valueWithPointer:@selector(runTC2)]
    ];
    UIView *previousAnchorView = nil;
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setTitle:titles[i] forState:UIControlStateNormal];
        SEL selector;
        [selectors[i] getValue:&selector];
        [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
        [button.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
        if (previousAnchorView == nil) {
            [button.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-80].active = YES;
        } else {
            [button.bottomAnchor constraintEqualToAnchor:previousAnchorView.topAnchor constant:-8].active = YES;
        }
        previousAnchorView = button;
    }
}

- (void)runTC0 {
    NSLog(@"GAMEDAY TC0 started");
    [self playVideo:kGamedayAssetURL];
}

- (void)runTC1 {
    NSLog(@"GAMEDAY TC1 started");
    [self playVideo:kGamedayAssetURL];
    self.view.userInteractionEnabled = NO;
    self.playerController.player.currentItem.preferredPeakBitRate = kTC1LowBitrate;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.playerController.player.currentItem.preferredPeakBitRate = kTC1MidBitrate;
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(23 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.playerController.player.currentItem.preferredPeakBitRate = kTC1TopBitrate;
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(26 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.playerController.player.currentItem.preferredPeakBitRate = kTC1MidBitrate;
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(29 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"GAMEDAY TC1 pausing for 10s");
        [self.playerController.player pause];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.playerController.player play];
            self.view.userInteractionEnabled = YES;
        });
    });
}

- (void)runTC2 {
    NSLog(@"GAMEDAY TC2 started");
    [self playVideo:kGamedayAssetURL];
    self.view.userInteractionEnabled = NO;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"GAMEDAY TC2 triggering broken URL");
        NSString *brokenUrlString = [NSString stringWithFormat:@"https://commondatastorage.googleapis.com/does-not-exist/broken-%f.mp4", [[NSDate date] timeIntervalSince1970]];
        AVPlayerItem *brokenItem = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:brokenUrlString]];
        [self.playerController.player replaceCurrentItemWithPlayerItem:brokenItem];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AVPlayerItem *item = self.playerController.player.currentItem;
        CMTime duration = item.duration;
        if (CMTIME_IS_VALID(duration) && CMTimeGetSeconds(duration) > 3) {
            NSLog(@"GAMEDAY TC2 seeking near end");
            CMTime seekTarget = CMTimeSubtract(duration, CMTimeMake(3, 1));
            [self.playerController.player seekToTime:seekTarget];
        }
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"GAMEDAY TC2 firing one custom event");
        [NRVAVideo recordCustomEvent:@"GAMEDAY_TC2_CUSTOM_EVENT"
                          trackerId:@(self.trackerId)
                         attributes:@{}];
        self.view.userInteractionEnabled = YES;
    });
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
    
    // User closed the player
    if (self.playerController.isBeingDismissed) {
        
        //Stop tracking
        [NRVAVideo releaseTracker:@(self.trackerId)];
        
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
