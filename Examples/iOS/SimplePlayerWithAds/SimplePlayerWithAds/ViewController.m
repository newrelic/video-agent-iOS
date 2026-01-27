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
    [self playVideo:@"https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8"];
}

- (IBAction)clickAirshowLive:(id)sender {
    [self playVideo:@"http://cdn3.viblast.com/streams/hls/airshow/playlist.m3u8"];
}

- (IBAction)clickMediaTailorVideo:(id)sender {
    // Initialize MediaTailor session first (user-side initialization)
    [self initializeMediaTailorSession];
}

- (void)initializeMediaTailorSession {
    // AWS MediaTailor base URL and session endpoint
    // MASKED: Replace with your actual MediaTailor domain and session path via env or config for real use
    NSString *baseUrl = @"https://<domain>.mediatailor.<region>.amazonaws.com";
    // Correct format: /v1/session/{accountId}/{playbackConfigName}/{format}
    NSString *sessionPath = @"/v1/session/<accountId>/<playbackConfigName>/master.m3u8";
    NSString *sessionEndpoint = [baseUrl stringByAppendingString:sessionPath];

    NSURL *url = [NSURL URLWithString:sessionEndpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[@"{}" dataUsingEncoding:NSUTF8StringEncoding]];

    NSLog(@"🔄 Initializing MediaTailor session...");

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"❌ Session initialization error: %@", error.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                        message:[NSString stringWithFormat:@"Failed to initialize MediaTailor session: %@", error.localizedDescription]
                        preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                });
                return;
            }

            NSDictionary *sessionData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (!sessionData) {
                NSLog(@"❌ Failed to parse session response");
                return;
            }

            NSLog(@"✅ Session initialized successfully");

            // Extract manifestUrl from session response
            NSString *manifestUrl = sessionData[@"manifestUrl"];

            if (manifestUrl) {
                // Check if URL is relative and prepend base URL if needed
                NSString *fullUrl = manifestUrl;
                if ([manifestUrl hasPrefix:@"/"]) {
                    fullUrl = [baseUrl stringByAppendingString:manifestUrl];
                    NSLog(@"📺 Constructed full URL: %@", fullUrl);
                }

                // Play the MediaTailor video
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self playMediaTailorVideo:fullUrl];
                });
            } else {
                NSLog(@"❌ No manifestUrl in session response");
            }
        }];

    [task resume];
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

- (void)playMediaTailorVideo:(NSString *)videoURL {
    NSLog(@"📺 Playing MediaTailor video with tracking");
    NSLog(@"📺 URL: %@", videoURL);

    // Create player
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:videoURL]];
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = player;
    self.playerController.showsPlaybackControls = YES;

    // Setup tracking with custom attributes
    NSDictionary *customAttributes = @{
        @"contentType": @"video-on-demand",
        @"playerVersion": @"1.0.0",
        @"customTag": @"MediaTailorSSAI",
        @"adType": @"SSAI"
    };

    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"TEST_MEDIATAILOR"
        player:player
        adEnabled:YES
        customAttributes:customAttributes];

    // NRVAVideo.addPlayer will automatically detect MediaTailor stream
    // and use NRTrackerMediaTailor which will handle pre-fetching internally
    self.trackerId = [NRVAVideo addPlayer:playerConfig];

    NSLog(@"✅ MediaTailor player initialized with tracking (tracker ID: %ld)", (long)self.trackerId);

    // No IMA ads setup - MediaTailor handles SSAI

    [self presentViewController:self.playerController animated:YES completion:^{
        [self.playerController.player play];
    }];
}

- (void)playerItemFailedToPlayToEnd:(NSNotification *)notification {
    NSError *error = notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
    NSLog(@"❌ Player failed to play to end: %@", error.localizedDescription);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayer *player = (AVPlayer *)object;
        NSLog(@"🔍 Player status changed: %ld", (long)player.status);
        if (player.status == AVPlayerStatusFailed) {
            NSLog(@"❌ Player failed with error: %@", player.error.localizedDescription);
        }
    } else if ([keyPath isEqualToString:@"currentItem.status"]) {
        AVPlayer *player = (AVPlayer *)object;
        NSLog(@"🔍 Player item status changed: %ld", (long)player.currentItem.status);
        if (player.currentItem.status == AVPlayerItemStatusFailed) {
            NSLog(@"❌ Player item failed with error: %@", player.currentItem.error.localizedDescription);
        } else if (player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
            NSLog(@"✅ Player item ready to play!");
        }
    }
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
