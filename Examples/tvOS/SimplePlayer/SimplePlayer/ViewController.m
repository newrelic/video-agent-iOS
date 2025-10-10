//
//  ViewController.m
//  SimplePlayer
//
//  Created by Andreu Santaren on 2/3/21.
//

#import "ViewController.h"
#import <NewRelicVideoCore/NewRelicVideoCore.h>
#import <NRAVPlayerTracker/NRAVPlayerTracker.h>

@import AVKit;

@interface ViewController ()

@property (nonatomic) AVPlayerViewController *playerController;
@property (nonatomic) NSInteger trackerId;

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

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)dealloc {
    [NRVAVideo releaseTracker:@(self.trackerId)];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // User closed the player
    if (self.playerController.isBeingDismissed) {
        //Stop tracking
        [NRVAVideo releaseTracker:@(self.trackerId)];
    }
}

- (void)playVideo:(NSString *)videoURL {
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:videoURL]];
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = player;
    self.playerController.showsPlaybackControls = YES;
    
    // Use configuration-based approach similar to SimplePlayerWithAds
    NSDictionary *customAttributes = @{
        @"contentType": @"video-on-demand",
        @"playerVersion": @"1.0.0",
        @"customTag": @"SimplePlayer_tvOS",
        @"videoURL": videoURL
    };
    
    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc] 
        initWithPlayerName:@"SimplePlayer_tvOS" 
        player:player 
        adEnabled:NO
        customAttributes:customAttributes];
    
    self.trackerId = [NRVAVideo addPlayer:playerConfig];
    
    // TRACKER-SPECIFIC custom event (enriched with video attributes)
    [NRVAVideo recordCustomEvent:@"VIDEO_READY" 
                      trackerId:@(self.trackerId) 
                     attributes:@{
                         @"videoURL": videoURL,
                         @"hasAds": @NO,
                         @"platform": @"tvOS"
                     }];
    
    [self presentViewController:self.playerController animated:YES completion:^{
        [self.playerController.player play];
    }];
}

@end
