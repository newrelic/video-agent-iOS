#import "AppDelegate.h"
#import "ViewController.h"
#import <NewRelicVideoCore.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // The token comes from Config.local.xcconfig (gitignored) through Info.plist, never from source.
    NSString *token = [NSBundle mainBundle].infoDictionary[@"NRAppToken"];
    if (token.length == 0 || [token hasPrefix:@"YOUR_"] || [token hasPrefix:@"$("]) {
        NSLog(@"[SimplePlayerWithDAI] NR_APP_TOKEN is not set. Create Config.local.xcconfig (see Config.xcconfig). Events will not reach New Relic.");
        token = @"YOUR_NEWRELIC_APP_TOKEN";
    }

    // Optional: NR_COLLECTOR_ADDRESS in the scheme environment points the run at a non-default collector
    // (e.g. a staging account's token needs the staging collector).
    NSString *collector = NSProcessInfo.processInfo.environment[@"NR_COLLECTOR_ADDRESS"];
    NRVAVideoConfiguration *videoConfig = [[[[[NRVAVideoConfiguration builder]
        withApplicationToken:token]
        withHarvestCycle:60]
        withDebugLogging:YES] build];
    if (collector.length > 0) {
        videoConfig = [[[[[[NRVAVideoConfiguration builder]
            withApplicationToken:token]
            withHarvestCycle:60]
            withCollectorAddress:collector]
            withDebugLogging:YES] build];
    }
    [[[NRVAVideo newBuilder] withConfiguration:videoConfig] build];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[ViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
