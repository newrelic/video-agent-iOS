//
//  ViewController.m
//  SimplePlayerUsingPods
//
//  Created by Andreu Santaren on 05/01/2021.
//

#import "ViewController.h"
#import <NewRelicVideoCore/NewRelicVideoCore.h>
#import <NewRelicVideoCore/NRVAVideo.h>
#import <NewRelicVideoCore/NRVAVideoPlayerConfiguration.h>


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
    
    // Logging is already enabled in AppDelegate through NRVAVideo configuration
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // User closed the player
    if (self.playerController.isBeingDismissed) {
        //Send END using runtime method call
        NRTracker *contentTracker = [[NewRelicVideoAgent sharedInstance] contentTracker:@(self.trackerId)];
        if (contentTracker && [contentTracker respondsToSelector:@selector(sendEnd)]) {
            [contentTracker performSelector:@selector(sendEnd)];
        }
        
        //Stop tracking using NRVAVideo
        [NRVAVideo releaseTracker:self.trackerId];
    }
}

- (void)playVideo:(NSString *)videoURL {
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:videoURL]];
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = player;
    self.playerController.showsPlaybackControls = YES;
    
    // Create player configuration with ads enabled
    
    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc] 
        initWithPlayerName:@"main-player"
        player:player
        adEnabled:YES  // Enable ads
        ];
    
    // Use NRVAVideo instead of NewRelicVideoAgent directly
    self.trackerId = [NRVAVideo addPlayer:playerConfig];
    
    [self presentViewController:self.playerController animated:YES completion:^{
        [self.playerController.player play];
    } ];
}


@end
