//
//  ViewController.m
//  SimplePlayerUsingPods
//
//  Created by Andreu Santaren on 05/01/2021.
//

#import "ViewController.h"
#import "MediaTailorSamples.h"
#import <NewRelicVideoCore/NRVAVideo.h>
#import <NewRelicVideoCore/NRVAVideoPlayerConfiguration.h>
#import <NRMediaTailorTracker/NRMediaTailorTracker.h>

@import AVKit;

@interface ViewController ()

@property (nonatomic) AVPlayerViewController *playerController;
@property (nonatomic) NSInteger trackerId;
@property (nonatomic, strong, nullable) NRTrackerMediaTailor *mediaTailorTracker;

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

- (IBAction)clickGearExample:(id)sender {
    [self playVideo:@"https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"];
}

/// MediaTailor integration smoke path (T13). Replace
/// `MediaTailorSamples.defaultSampleURLString` with your real session URL.
- (IBAction)clickMediaTailorSample:(id)sender {
    [self playMediaTailorVideo:[MediaTailorSamples defaultSampleURLString]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"🎬 [ViewController] Simple Player - Ready for video tracking");
}

- (void)dealloc {
    [NRVAVideo releaseTracker:self.trackerId];
    [self.mediaTailorTracker dispose];
    NSLog(@"🧹 [ViewController] Cleanup completed");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)playVideo:(NSString *)videoURL {
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:videoURL]];
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = player;
    self.playerController.showsPlaybackControls = YES;

    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"SimplePlayer"
        player:player
        adEnabled:NO
        customAttributes:@{
            @"videoURL": videoURL,
            @"setupMethod": @"configuration-based"
        }];

    self.trackerId = [NRVAVideo addPlayer:playerConfig];

    NSLog(@"🎥 [Video] Started simple video tracking with ID: %ld", (long)self.trackerId);

    [self presentViewController:self.playerController animated:YES completion:^{
        [self.playerController.player play];
        NSLog(@"▶️ [Video] Playback started");
    }];
}

/// Spin up an AVPlayer at a MediaTailor session URL, attach the
/// NRMediaTailorTracker, and feed it a parsed schedule. In production this
/// path runs concurrently with the content tracker (NRAVPlayerTracker).
///
/// Per FEATURE_SPEC §9 "Definition of Done": the verification flow is to
/// run this with a real MediaTailor URL, capture a proxy log proving that
/// `/v1/tracking/<sessionId>` round-trips `nextToken`, and confirm in NRDB
/// that the full AD_BREAK_START → AD_START → 3×AD_QUARTILE → AD_END →
/// AD_BREAK_END sequence fires for at least one ad break.
- (void)playMediaTailorVideo:(NSString *)videoURLString {
    NSURL *videoURL = [NSURL URLWithString:videoURLString];
    if (videoURL == nil) {
        NSLog(@"❌ [MediaTailor] Invalid URL: %@", videoURLString);
        return;
    }
    if (![MTDetector isMediaTailorURL:videoURL]) {
        NSLog(@"⚠️ [MediaTailor] URL does not look like a MediaTailor session — "
              @"the tracker will not activate. Replace MediaTailorSamples."
              @"defaultSampleURLString with your real session URL.");
    }

    AVPlayer *player = [AVPlayer playerWithURL:videoURL];
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = player;
    self.playerController.showsPlaybackControls = YES;

    // Set up the MediaTailor tracker. Content events still flow through the
    // NRAVPlayerTracker via NRVAVideo.addPlayer below.
    self.mediaTailorTracker = [[NRTrackerMediaTailor alloc] init];
    [self.mediaTailorTracker setPlayer:player];

    // For the smoke test we ship an empty schedule. In production the host
    // app or networking layer fetches the personalized manifest, parses it
    // via `MTHlsParser`, polls `/v1/tracking/<sessionId>` via
    // `MTTrackingClient`, merges via `MTAdScheduleMerger`, and hands the
    // result to `-startTrackingWithSchedule:`. See README.md "Integration"
    // for the full snippet.
    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"MediaTailorPlayer"
        player:player
        adEnabled:YES
        customAttributes:@{
            @"videoURL": videoURLString,
            @"setupMethod": @"mediatailor-integration",
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

@end
