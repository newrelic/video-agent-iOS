//
//  ViewController.m
//  SimplePlayerUsingPods
//
//  Created by Andreu Santaren on 05/01/2021.
//

#import "ViewController.h"
#import <NewRelicVideoCore/NRVAVideo.h>
#import <NewRelicVideoCore/NRVAVideoPlayerConfiguration.h>
#import <UIKit/UIKit.h>

@import AVKit;

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *qoeSwitch;
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

    // Initialize QOE switch to match current configuration
    self.qoeSwitch.on = [NRVAVideo isQoeAggregateEnabled];

    NSLog(@"🎬 [ViewController] Simple Player - Ready for video tracking");
}

- (IBAction)qoeSwitchChanged:(UISwitch *)sender {
    [NRVAVideo setQoeAggregateEnabled:sender.on];

    NSString *message = sender.on ? @"QOE Aggregate Enabled" : @"QOE Aggregate Disabled";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];

    // Auto-dismiss after 1 second
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)dealloc {
    // Clean up tracker when view controller is deallocated
    [NRVAVideo releaseTracker:self.trackerId];
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
    
    // Use configuration-based approach
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

@end
