//
//  MediaTailorSamples.m
//  SimplePlayerWithAds
//

#import "MediaTailorSamples.h"

static NSString * const kMediaTailorSampleURLDefaultsKey = @"MediaTailorSampleURL";

@implementation MediaTailorSampleOption

- (instancetype)initWithLabel:(NSString *)label urlString:(NSString *)urlString {
    self = [super init];
    if (self) {
        _label = [label copy];
        _urlString = [urlString copy];
    }
    return self;
}

@end

@implementation MediaTailorSamples

+ (NSString *)defaultSampleURLString {
    // 1. NSUserDefaults override.
    NSString *fromDefaults =
        [[NSUserDefaults standardUserDefaults] stringForKey:kMediaTailorSampleURLDefaultsKey];
    if (fromDefaults.length > 0) {
        return fromDefaults;
    }

    // 2. Environment override (CI-friendly).
    NSString *fromEnv = NSProcessInfo.processInfo.environment[@"MT_SAMPLE_URL"];
    if (fromEnv.length > 0) {
        return fromEnv;
    }

    // 3. Placeholder. Replace with a live MediaTailor playback configuration
    //    endpoint, or supply one via the NSUserDefaults/env override above.
    return @"https://example.mediatailor.us-east-1.amazonaws.com/v1/master/YOUR_ACCOUNT_ID/YOUR_CONFIG_NAME/master.m3u8?aws.sessionId=YOUR_SESSION_ID";
}

+ (NSString *)defaultsKey {
    return kMediaTailorSampleURLDefaultsKey;
}

+ (NSArray<MediaTailorSampleOption *> *)sampleOptions {
    // A MediaTailor playback configuration fronted by a CDN (no "mediatailor"
    // substring in the hostname) so the URL shape matches a real production
    // deployment. Both URLs point at the same underlying config/session-init
    // endpoint — they exercise the two different ways a player can enter a
    // MediaTailor session, per NRTrackerMediaTailor's auto-activation support
    // for both. Replace with a live CDN-fronted MediaTailor configuration, or
    // supply one via the NSUserDefaults/env override above.
    NSString * const cloudFrontHost = @"example.cloudfront.net";
    NSString * const account = @"YOUR_ACCOUNT_ID";
    NSString * const config = @"YOUR_CONFIG_NAME";

    return @[
        [[MediaTailorSampleOption alloc]
            initWithLabel:@"Direct/Implicit (CloudFront)"
                urlString:[NSString stringWithFormat:@"https://%@/v1/master/%@/%@/master.m3u8",
                           cloudFrontHost, account, config]],
        [[MediaTailorSampleOption alloc]
            initWithLabel:@"Explicit Session-Init (CloudFront)"
                urlString:[NSString stringWithFormat:@"https://%@/v1/session/%@/%@/master.m3u8",
                           cloudFrontHost, account, config]],
        [[MediaTailorSampleOption alloc]
            initWithLabel:@"Legacy (raw MediaTailor endpoint, no CDN)"
                urlString:[self defaultSampleURLString]],
    ];
}

@end
