#import "ViewController.h"
#import <AVKit/AVKit.h>
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>
#import <NewRelicVideoCore/NewRelicVideoCore.h>
#import <NRAVPlayerTracker/NRAVPlayerTracker.h>
#import <NRTrackerIMA.h>
static NSString *const kAssetKey = @"c-rArva4ShKVIAkNfy6HUQ";
static NSString *const kContentSourceID = @"2548831";
static NSString *const kVideoID = @"tears-of-steel";
static NSString *const kBackupStreamURLString =
    @"https://storage.googleapis.com/interactive-media-ads/media/bbb.m3u8";
@interface ViewController () <IMAAdsLoaderDelegate, IMAStreamManagerDelegate>
@property(nonatomic) IMAAdsLoader *adsLoader;
@property(nonatomic) UIView *adContainerView;
@property(nonatomic) IMAStreamManager *streamManager;
@property(nonatomic) AVPlayerViewController *playerViewController;
@property (nonatomic) NSNumber *trackerId;
@end
@implementation ViewController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor blackColor];
  [self setupAdsLoader];
  // Create a stream video player.
  AVPlayer *player = [[AVPlayer alloc] init];
  self.playerViewController = [[AVPlayerViewController alloc] init];
  self.playerViewController.player = player;
  // Attach the video player to the view hierarchy.
  [self addChildViewController:self.playerViewController];
  self.playerViewController.view.frame = self.view.bounds;
  [self.view addSubview:self.playerViewController.view];
  [self.playerViewController didMoveToParentViewController:self];
    [[NewRelicVideoAgent sharedInstance] setLogging:YES];
    [self attachAdContainer];
}
- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
    [self requestStream];
}
- (void)setupAdsLoader {
  self.adsLoader = [[IMAAdsLoader alloc] init];
  self.adsLoader.delegate = self;
}
- (void)attachAdContainer {
  self.adContainerView = [[UIView alloc] init];
  [self.view addSubview:self.adContainerView];
  self.adContainerView.frame = self.view.bounds;
}
-  (void)requestStream {
    IMAAVPlayerVideoDisplay *videoDisplay =
        [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:self.playerViewController.player];
      IMAAdDisplayContainer *adDisplayContainer =
          [[IMAAdDisplayContainer alloc] initWithAdContainer:self.adContainerView viewController:self companionSlots:@[]];
      IMALiveStreamRequest *request = [[IMALiveStreamRequest alloc] initWithAssetKey:kAssetKey
                                                                    adDisplayContainer:adDisplayContainer
                                                                          videoDisplay:videoDisplay
                                                                         userContext:nil];
//     VOD request. Comment out the IMALiveStreamRequest above and uncomment this IMAVODStreamRequest
//     to switch from a livestream to a VOD stream.
//     IMAVODStreamRequest *request =
//           [[IMAVODStreamRequest alloc] initWithContentSourceID:kContentSourceID
//                                                        videoID:kVideoID
//                                             adDisplayContainer:adDisplayContainer
//                                                   videoDisplay:videoDisplay
//                                                    userContext:nil];
    self.trackerId = [[NewRelicVideoAgent sharedInstance] startWithContentTracker:[[NRTrackerAVPlayer alloc] initWithAVPlayer:self.playerViewController.player]
                                                                              adTracker:[[NRTrackerIMA alloc] init]];
    [self.adsLoader requestStreamWithRequest:request];
  }
- (void)playBackupStream {
  NSURL *backupStreamURL = [NSURL URLWithString:kBackupStreamURLString];
  AVPlayerItem *backupStreamItem = [AVPlayerItem playerItemWithURL:backupStreamURL];
  [self.playerViewController.player replaceCurrentItemWithPlayerItem:backupStreamItem];
    [self.playerViewController.player play];
}
#pragma mark - IMAAdsLoaderDelegate
- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
  // Initialize and listen to stream manager's events.
  self.streamManager = adsLoadedData.streamManager;
  self.streamManager.delegate = self;
  [self.streamManager initializeWithAdsRenderingSettings:nil];
  NSLog(@"Stream created with: %@.", self.streamManager.streamId);
}
- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
  // Fall back to playing the backup stream.
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] adError:adErrorData.adError.message code:(int)adErrorData.adError.code];
  NSLog(@"Error loading ads: %@", adErrorData.adError.message);
  [self playBackupStream];
}
#pragma mark - IMAStreamManagerDelegate
- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdEvent:(IMAAdEvent *)event {
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] streamAdEvent:event streamManager:streamManager];
}
- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdError:(IMAAdError *)error {
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] adError:error.message code:(int)error.code];
    NSLog(@"StreamManager error: %@", error.message);
     [self playBackupStream];
}
- (void)streamManager:(IMAStreamManager *)streamManager
  adDidProgressToTime:(NSTimeInterval)time
           adDuration:(NSTimeInterval)adDuration
           adPosition:(NSInteger)adPosition
             totalAds:(NSInteger)totalAds
      adBreakDuration:(NSTimeInterval)adBreakDuration {}
- (void)adsManagerDidRequestContentPause:(IMAStreamManager *)streamManager {
    NSLog(@"Ads request pause");
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] sendAdBreakStart];
    [self.playerViewController.player pause];
}
- (void)adsManagerDidRequestContentResume:(IMAStreamManager *)streamManager {
    NSLog(@"Ads request resume");
    [(NRTrackerIMA *)[[NewRelicVideoAgent sharedInstance] adTracker:self.trackerId] sendAdBreakEnd];
    [self.playerViewController.player play];
}
@end
