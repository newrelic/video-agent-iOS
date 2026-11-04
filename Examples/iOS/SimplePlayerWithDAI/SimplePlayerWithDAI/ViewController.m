//
//  ViewController.m
//  SimplePlayerWithDAI
//
//  Google IMA Dynamic Ad Insertion (server-side stitched ads) tracked by New Relic.
//
//  Wiring, all through the NRVAVideo lifecycle API:
//   1. NRVAVideo addPlayer with NRAdConfig.dai creates the content tracker and an NRTrackerIMA in DAI mode.
//   2. IMAAdsLoader requests the stream; IMAStreamManager plays it through an IMAAVPlayerVideoDisplay.
//   3. IMAStreamManagerDelegate callbacks are forwarded with handleStreamAdEvent/handleStreamAdError/
//      handleStreamAdProgress. Ad breaks come from the AD_BREAK_STARTED/ENDED events; there is no
//      content pause/resume callback for DAI.
//

#import "ViewController.h"
#import <NewRelicVideoCore.h>

@import AVKit;

// Google's public DAI sample streams.
static NSString *const kVODContentSourceID = @"2548831";
static NSString *const kVODVideoID = @"tears-of-steel";
static NSString *const kLiveAssetKey = @"c-rArva4ShKVIAkNfy6HUQ";

@interface ViewController ()

@property (nonatomic) AVPlayerViewController *playerController;
@property (nonatomic) AVPlayer *player;
@property (nonatomic) NSNumber *trackerId;
@property (nonatomic) IMAAdsLoader *adsLoader;
@property (nonatomic) IMAStreamManager *streamManager;
@property (nonatomic) UILabel *statusLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
    ]];

    [stack addArrangedSubview:[self buttonWithTitle:@"Play VOD (preroll + midroll)" action:@selector(playVOD)]];
    [stack addArrangedSubview:[self buttonWithTitle:@"Play Live" action:@selector(playLive)]];
    [stack addArrangedSubview:[self buttonWithTitle:@"Bad asset key (AD_ERROR)" action:@selector(playBadKey)]];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    [stack addArrangedSubview:self.statusLabel];
}

/// Lets a scripted run start a scenario without tapping: NR_AUTO_SCENARIO = vod | live | bad-key.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.trackerId) { return; }
    NSString *auto_ = NSProcessInfo.processInfo.environment[@"NR_AUTO_SCENARIO"];
    if ([auto_ isEqualToString:@"vod"]) { [self playVOD]; }
    else if ([auto_ isEqualToString:@"live"]) { [self playLive]; }
    else if ([auto_ isEqualToString:@"bad-key"]) { [self playBadKey]; }
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

#pragma mark - Scenarios

- (void)playVOD {
    [self startWithRequestBuilder:^IMAStreamRequest *(IMAAdDisplayContainer *container, id<IMAVideoDisplay> display) {
        return [[IMAVODStreamRequest alloc] initWithContentSourceID:kVODContentSourceID
                                                            videoID:kVODVideoID
                                                 adDisplayContainer:container
                                                       videoDisplay:display
                                                        userContext:nil];
    } label:@"vod"];
}

- (void)playLive {
    [self startWithRequestBuilder:^IMAStreamRequest *(IMAAdDisplayContainer *container, id<IMAVideoDisplay> display) {
        return [[IMALiveStreamRequest alloc] initWithAssetKey:kLiveAssetKey
                                           adDisplayContainer:container
                                                 videoDisplay:display
                                                  userContext:nil];
    } label:@"live"];
}

/// The stream request fails, so IMA reports it through adsLoader:failedWithErrorData: and the tracker emits AD_ERROR.
- (void)playBadKey {
    [self startWithRequestBuilder:^IMAStreamRequest *(IMAAdDisplayContainer *container, id<IMAVideoDisplay> display) {
        return [[IMALiveStreamRequest alloc] initWithAssetKey:@"invalid-asset-key"
                                           adDisplayContainer:container
                                                 videoDisplay:display
                                                  userContext:nil];
    } label:@"bad-key"];
}

- (void)startWithRequestBuilder:(IMAStreamRequest *(^)(IMAAdDisplayContainer *, id<IMAVideoDisplay>))builder
                          label:(NSString *)label {
    [self stopTracking];

    self.player = [[AVPlayer alloc] init];
    self.player.muted = YES;
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = self.player;

    // Tag every event of a manual run so it can be isolated in NRQL: SET NR_TEST_RUN in the scheme environment.
    NSString *testRun = NSProcessInfo.processInfo.environment[@"NR_TEST_RUN"] ?: @"dai-manual";
    NRVAVideoPlayerConfiguration *config = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"DAI_PLAYER"
        player:self.player
        adConfig:[NRAdConfig dai]
        customAttributes:@{ @"testRun": testRun, @"scenario": label, @"customTag": @"SimplePlayerWithDAI" }];
    // Registered before the stream request so a request failure still reaches a tracker.
    self.trackerId = @([NRVAVideo addPlayer:config]);
    // customAttributes reach the content tracker only; mirror them on the ad tracker so ad events can be filtered too.
    for (NSString *key in config.customAttributes) {
        [NRVAVideo setAdAttribute:self.trackerId.integerValue key:key value:config.customAttributes[key]];
    }

    [self presentViewController:self.playerController animated:YES completion:^{
        IMAAdDisplayContainer *container = [[IMAAdDisplayContainer alloc]
            initWithAdContainer:self.playerController.contentOverlayView
                 viewController:self.playerController];
        IMAAVPlayerVideoDisplay *display = [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:self.player];
        self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
        self.adsLoader.delegate = self;
        [self.adsLoader requestStreamWithRequest:builder(container, display)];
        self.statusLabel.text = [NSString stringWithFormat:@"Requested %@ stream, testRun=%@", label, testRun];
    }];
}

- (void)stopTracking {
    [self.streamManager destroy];
    self.streamManager = nil;
    self.adsLoader = nil;
    if (self.trackerId) {
        [NRVAVideo releaseTracker:self.trackerId];
        self.trackerId = nil;
    }
}

- (void)dealloc {
    [self stopTracking];
}

#pragma mark - IMAAdsLoaderDelegate

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
    self.streamManager = adsLoadedData.streamManager;
    self.streamManager.delegate = self;
    [self.streamManager initializeWithAdsRenderingSettings:nil];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    NSLog(@"[SimplePlayerWithDAI] Stream request failed: %@", adErrorData.adError.message);
    [NRVAVideo handleStreamAdError:self.trackerId error:adErrorData.adError];
    self.statusLabel.text = [NSString stringWithFormat:@"Stream request failed: %@", adErrorData.adError.message];
}

#pragma mark - IMAStreamManagerDelegate

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdEvent:(IMAAdEvent *)event {
    [NRVAVideo handleStreamAdEvent:self.trackerId event:event streamManager:streamManager];
}

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdError:(IMAAdError *)error {
    [NRVAVideo handleStreamAdError:self.trackerId error:error];
}

- (void)streamManager:(IMAStreamManager *)streamManager
    adDidProgressToTime:(NSTimeInterval)time
             adDuration:(NSTimeInterval)adDuration
             adPosition:(NSInteger)adPosition
               totalAds:(NSInteger)totalAds
        adBreakDuration:(NSTimeInterval)adBreakDuration
       adPeriodDuration:(NSTimeInterval)adPeriodDuration {
    [NRVAVideo handleStreamAdProgress:self.trackerId
                                 time:time
                           adDuration:adDuration
                           adPosition:adPosition
                             totalAds:totalAds
                      adBreakDuration:adBreakDuration];
}

@end
