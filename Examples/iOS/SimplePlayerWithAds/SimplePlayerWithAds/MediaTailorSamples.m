//
//  MediaTailorSamples.m
//  SimplePlayerWithAds
//

#import "MediaTailorSamples.h"

static NSString * const kMediaTailorSampleURLDefaultsKey = @"MediaTailorSampleURL";

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

    // 3. Placeholder. Replace before running the smoke test.
    return @"https://example.mediatailor.us-east-1.amazonaws.com/v1/master/REPLACE_ME/index.m3u8";
}

+ (NSString *)defaultsKey {
    return kMediaTailorSampleURLDefaultsKey;
}

@end
