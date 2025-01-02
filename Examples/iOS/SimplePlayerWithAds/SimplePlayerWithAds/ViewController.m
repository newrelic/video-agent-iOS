//
//  ViewController.m
//  SimplePlayerWithAds
//
//  Created by Andreu Santaren on 2/3/21.
//

#import "ViewController.h"
#import <NewRelicVideoCore.h>
#import <NRTrackerAVPlayer.h>
#import <NRTrackerIMA.h>

@import AVKit;

@interface ViewController ()

@property (nonatomic) AVPlayerViewController *playerController;
@property (nonatomic) NSNumber *trackerId;
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
    [self playVideo:@"https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8"];
}

- (IBAction)clickAirshowLive:(id)sender {
    [self playVideo:@"http://cdn3.viblast.com/streams/hls/airshow/playlist.m3u8"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.multipleAdTagURL = @"http://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/ad_rule_samples&ciu_szs=300x250&ad_rule=1&impl=s&gdfp_req=1&env=vp&output=xml_vmap1&unviewed_position_start=1&cust_params=sample_ar%3Dpremidpostpod%26deployment%3Dgmf-js&cmsid=496&vid=short_onecue&correlator=";
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NewRelicVideoAgent sharedInstance] setLogging:YES];
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
        //Send END
        [(NRTrackerAVPlayer *)[[NewRelicVideoAgent sharedInstance] contentTracker:self.trackerId] sendEnd];
        
        //Stop tracking
        [[NewRelicVideoAgent sharedInstance] releaseTracker:self.trackerId];
        
        [self releaseAds];
    }
}

- (void)playVideo:(NSString *)videoURL {
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:videoURL]];
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = player;
    self.playerController.showsPlaybackControls = YES;
    
    self.trackerId = [[NewRelicVideoAgent sharedInstance] startWithContentTracker:[[NRTrackerAVPlayer alloc] initWithAVPlayer:self.playerController.player]
                                                                        adTracker:[[NRTrackerIMA alloc] init]];
    
    NRTracker *contentTracker = [[NewRelicVideoAgent sharedInstance] contentTracker:self.trackerId];
    [contentTracker setAttribute:@"contentTitle"
                           value:@"A title"
                       forAction:@"CONTENT_START"];
    // Uncomment the following line to set a userId for the content
    // [contentTracker setUserId:@"TEST_USER"];
    
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
    
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] adError:adErrorData.adError.message code:(int)adErrorData.adError.code];
    
    [self.playerController.player play];
}

#pragma mark - AdsManager delegate

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdEvent:(IMAAdEvent *)event {
    
    NSLog(@"Ads Manager did receive event = %@", event.typeString);
    
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] adEvent:event adsManager:adsManager];
    // Uncomment below line to set userId for ad content
    // [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] setUserId:@"TEST_USER"];
    
    if (event.type == kIMAAdEvent_LOADED) {
        NSLog(@"Ads Manager call start()");
        [adsManager start];
    }
}

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdError:(IMAAdError *)error {
    NSLog(@"Error managing ads: %@", error.message);
    
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] adError:error.message code:(int)error.code];
    
    [self.playerController.player play];
}

- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager {
    NSLog(@"Ads request pause");
    
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] sendAdBreakStart];
    
    [self.playerController.player pause];
}

- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager {
    NSLog(@"Ads request resume");
    
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] sendAdBreakEnd];
    
    [self.playerController.player play];
}

@end
