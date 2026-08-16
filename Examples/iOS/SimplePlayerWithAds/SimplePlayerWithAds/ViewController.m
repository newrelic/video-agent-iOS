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
/// instantiate IMAAdsLoader/AdsManager. Presents an action sheet so the
/// flow to exercise (direct/implicit vs. explicit session-init, etc.) is a
/// tap — no scheme environment variable or NSUserDefaults setup needed.
/// The NSUserDefaults `MediaTailorSampleURL` / `MT_SAMPLE_URL` overrides
/// from `MediaTailorSamples.h` still work too (CI-friendly) — they just add
/// an "Override" entry to the same sheet instead of being the only path in.
- (IBAction)clickMediaTailorSample:(id)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"MediaTailor Sample"
                                                                     message:@"Choose a URL shape to test"
                                                              preferredStyle:UIAlertControllerStyleActionSheet];

    for (MediaTailorSampleOption *option in [MediaTailorSamples sampleOptions]) {
        [sheet addAction:[UIAlertAction actionWithTitle:option.label
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
            [self playMediaTailorVideo:option.urlString];
        }]];
    }

    NSString *overrideURL = [MediaTailorSamples defaultSampleURLString];
    [sheet addAction:[UIAlertAction actionWithTitle:@"NSUserDefaults/MT_SAMPLE_URL Override"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction * _Nonnull action) {
        [self playMediaTailorVideo:overrideURL];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    // iPad requires a popover source; use the tapped control if we got one.
    sheet.popoverPresentationController.sourceView = [sender isKindOfClass:[UIView class]] ? sender : self.view;
    if ([sender isKindOfClass:[UIView class]]) {
        sheet.popoverPresentationController.sourceRect = ((UIView *)sender).bounds;
    }

    [self presentViewController:sheet animated:YES completion:nil];
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
    [NRVAVideo releaseTracker:@(self.trackerId)];
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

    // Config-based wiring — parity with the MediaTailor path below.
    // `NRAdConfig.csai` tells the agent to create and attach an `NRTrackerIMA`
    // as the ad tracker (equivalent to the legacy `adEnabled:YES`, which sets
    // this same config under the hood). We still drive the actual Google IMA
    // SDK ourselves (`setupAds:`/`requestAds`) and forward its events via
    // `handleAdEvent:`/`handleAdError:` — NRTrackerIMA is a passive observer,
    // same role NRTrackerMediaTailor plays for server-side-stitched ads.
    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"TEST_ADS"
        player:player
        adConfig:[NRAdConfig csai]
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

/// MediaTailor playback entry point. A raw explicit-flow session-init URL
/// (`/v1/session/{account}/{config}/...`) is POST-only and returns 405 on
/// GET, so `AVPlayer` can't play it directly — detect that shape and resolve
/// it to a `manifestUrl` first via `-resolveMediaTailorSessionURL:completion:`
/// before handing off to `-startMediaTailorPlaybackWithManifestURL:sourceURLString:`.
/// Any other shape (already-resolved explicit URL, or direct/implicit) is
/// passed straight through unchanged.
- (void)playMediaTailorVideo:(NSString *)videoURLString {
    NSURL *videoURL = [NSURL URLWithString:videoURLString];
    if (videoURL == nil) {
        NSLog(@"❌ [MediaTailor] Invalid URL: %@", videoURLString);
        return;
    }

    if ([videoURL.path containsString:@"/v1/session/"]) {
        NSLog(@"🎥 [MediaTailor] Session-init URL detected — resolving via POST before playback: %@", videoURLString);
        [self resolveMediaTailorSessionURL:videoURL completion:^(NSURL * _Nullable manifestURL) {
            NSURL *resolvedURL = manifestURL;
            if (resolvedURL == nil) {
                NSLog(@"⚠️ [MediaTailor] Session-init resolution failed — falling back to original URL: %@", videoURLString);
                resolvedURL = videoURL;
            }
            [self startMediaTailorPlaybackWithManifestURL:resolvedURL sourceURLString:videoURLString];
        }];
        return;
    }

    [self startMediaTailorPlaybackWithManifestURL:videoURL sourceURLString:videoURLString];
}

/// POSTs an empty body to a MediaTailor explicit session-init URL
/// (`/v1/session/{account}/{config}/...`) and parses `manifestUrl`/
/// `trackingUrl` out of the JSON response. `manifestUrl` is what gets handed
/// to `AVPlayer`; `trackingUrl` is unused here — `NRTrackerMediaTailor`
/// resolves its own tracking URL once it observes the player's manifest.
/// Calls `completion` with the resolved manifest URL, or nil on any failure
/// (network error, non-2xx, malformed JSON, missing key) — each failure is
/// logged so a fallback to the original URL is traceable.
- (void)resolveMediaTailorSessionURL:(NSURL *)sessionURL
                           completion:(void (^)(NSURL * _Nullable manifestURL))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:sessionURL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSData data];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"❌ [MediaTailor] Session-init POST failed: %@", error.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
                return;
            }

            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode < 200 || statusCode >= 300) {
                NSLog(@"❌ [MediaTailor] Session-init POST returned status %ld for %@", (long)statusCode, sessionURL);
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
                return;
            }

            NSError *jsonError = nil;
            id json = data != nil ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError] : nil;
            if (jsonError != nil || ![json isKindOfClass:[NSDictionary class]]) {
                NSLog(@"❌ [MediaTailor] Session-init response was not valid JSON: %@",
                      jsonError != nil ? jsonError.localizedDescription : @"response was not a JSON object");
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
                return;
            }

            NSDictionary *jsonDict = (NSDictionary *)json;
            NSString *manifestUrlString = jsonDict[@"manifestUrl"];
            NSString *trackingUrlString = jsonDict[@"trackingUrl"];
            if (![manifestUrlString isKindOfClass:[NSString class]] || manifestUrlString.length == 0) {
                NSLog(@"❌ [MediaTailor] Session-init response missing manifestUrl: %@", jsonDict);
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
                return;
            }

            // MediaTailor's session-init response returns manifestUrl/trackingUrl as a
            // host-relative path (e.g. "/v1/master/...", no scheme/host) — resolving it
            // with no base URL silently produces a scheme-less NSURL that AVPlayer then
            // rejects with -1002 "unsupported URL". Resolve against sessionURL's host.
            NSURL *manifestURL = [NSURL URLWithString:manifestUrlString relativeToURL:sessionURL].absoluteURL;
            if (manifestURL == nil) {
                NSLog(@"❌ [MediaTailor] Session-init returned an unparsable manifestUrl: %@", manifestUrlString);
                dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
                return;
            }

            NSLog(@"🎥 [MediaTailor] Session-init resolved manifestUrl: %@ (trackingUrl: %@)",
                  manifestURL, trackingUrlString ?: @"none");
            dispatch_async(dispatch_get_main_queue(), ^{ completion(manifestURL); });
    }];
    [task resume];
}

/// MediaTailor playback path. Spins up an AVPlayer, attaches a
/// NRTrackerMediaTailor, and registers a content tracker alongside.
///
/// `manifestURL` is the URL actually handed to `AVPlayer` — already resolved
/// via `-resolveMediaTailorSessionURL:completion:` if the original URL was a
/// session-init URL. `sourceURLString` is the original URL string passed to
/// `-playMediaTailorVideo:`, kept for logging/custom attributes.
- (void)startMediaTailorPlaybackWithManifestURL:(NSURL *)manifestURL
                                 sourceURLString:(NSString *)sourceURLString {
    if (![MTDetector isMediaTailorURL:manifestURL]) {
        NSLog(@"⚠️ [MediaTailor] URL does not look like a MediaTailor session — "
              @"the tracker will not activate. Override via NSUserDefaults "
              @"`MediaTailorSampleURL` or env `MT_SAMPLE_URL`.");
    }

    AVPlayer *player = [AVPlayer playerWithURL:manifestURL];
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = player;
    self.playerController.showsPlaybackControls = YES;

    // Config-based wiring — parity with the IMA path. `NRAdConfig.mediaTailor()`
    // tells the agent to create and attach an `NRTrackerMediaTailor` as the ad
    // tracker (custom-CDN: use `+mediaTailorWithSegmentPrefix:trackingUrl:`).
    // No IMAAdsLoader / IMAAdsManager — MediaTailor ads are server-side-stitched.
    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"MediaTailorPlayer"
        player:player
        adConfig:[NRAdConfig mediaTailor]
        customAttributes:@{
            @"videoURL": sourceURLString,
            @"adStitching": @"server-side",
            @"customTag": @"SimplePlayerWithAds-MediaTailor",
        }];
    self.trackerId = [NRVAVideo addPlayer:playerConfig];

    // The agent already created the tracker, attached it to the player, and
    // (per NRTrackerMediaTailor's auto-activation) started fetching/tracking
    // on its own. Grabbing it here is only for optional advanced use
    // (e.g. -notifyAdSkipped, inspecting activationStatus) — not required.
    self.mediaTailorTracker = (NRTrackerMediaTailor *)[[NewRelicVideoAgent sharedInstance] adTracker:@(self.trackerId)];

    NSLog(@"🎥 [MediaTailor] Started MediaTailor video tracking with ID: %ld", (long)self.trackerId);

    [self presentViewController:self.playerController animated:YES completion:^{
        [self.playerController.player play];
        NSLog(@"▶️ [MediaTailor] Playback started.");
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
