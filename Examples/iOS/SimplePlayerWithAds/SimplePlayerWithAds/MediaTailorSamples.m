//
//  MediaTailorSamples.m
//  SimplePlayerWithAds
//

#import "MediaTailorSamples.h"

static NSString * const kMediaTailorSampleURLDefaultsKey = @"MediaTailorSampleURL";
static NSString * const kMediaTailorCustomDomainURLDefaultsKey = @"MediaTailorCustomDomainURL";
static NSString * const kMediaTailorCustomSegmentPrefixDefaultsKey = @"MediaTailorCustomSegmentPrefix";
static NSString * const kMediaTailorCustomTrackingURLDefaultsKey = @"MediaTailorCustomTrackingURL";

@implementation MediaTailorSampleOption

- (instancetype)initWithLabel:(NSString *)label urlString:(NSString *)urlString {
    return [self initWithLabel:label urlString:urlString adSegmentPrefix:nil trackingUrl:nil];
}

- (instancetype)initWithLabel:(NSString *)label
                     urlString:(NSString *)urlString
               adSegmentPrefix:(NSString *)adSegmentPrefix
                   trackingUrl:(NSString *)trackingUrl {
    self = [super init];
    if (self) {
        _label = [label copy];
        _urlString = [urlString copy];
        _adSegmentPrefix = [adSegmentPrefix copy];
        _trackingUrl = [trackingUrl copy];
    }
    return self;
}

@end

@interface MediaTailorSamples ()
+ (NSString *)customDomainURLString;
+ (NSString *)customSegmentPrefixString;
+ (nullable NSString *)customTrackingURLStringOrNil;
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

+ (NSString *)customDomainURLDefaultsKey {
    return kMediaTailorCustomDomainURLDefaultsKey;
}

+ (NSString *)customSegmentPrefixDefaultsKey {
    return kMediaTailorCustomSegmentPrefixDefaultsKey;
}

+ (NSString *)customTrackingURLDefaultsKey {
    return kMediaTailorCustomTrackingURLDefaultsKey;
}

+ (NSString *)customDomainURLString {
    NSString *fromDefaults =
        [[NSUserDefaults standardUserDefaults] stringForKey:kMediaTailorCustomDomainURLDefaultsKey];
    if (fromDefaults.length > 0) return fromDefaults;

    NSString *fromEnv = NSProcessInfo.processInfo.environment[@"MT_CUSTOM_DOMAIN_URL"];
    if (fromEnv.length > 0) return fromEnv;

    return @"https://cdn.example.com/v1/master/YOUR_ACCOUNT_ID/YOUR_CONFIG_NAME/master.m3u8";
}

+ (NSString *)customSegmentPrefixString {
    NSString *fromDefaults =
        [[NSUserDefaults standardUserDefaults] stringForKey:kMediaTailorCustomSegmentPrefixDefaultsKey];
    if (fromDefaults.length > 0) return fromDefaults;

    NSString *fromEnv = NSProcessInfo.processInfo.environment[@"MT_CUSTOM_SEGMENT_PREFIX"];
    if (fromEnv.length > 0) return fromEnv;

    // Placeholder matching this CDN's ad-segment path convention. Must be
    // replaced with whatever substring actually appears in that CDN's
    // rewritten ad-segment URLs.
    return @"/YOUR_CUSTOM_AD_PATH/";
}

+ (nullable NSString *)customTrackingURLStringOrNil {
    NSString *fromDefaults =
        [[NSUserDefaults standardUserDefaults] stringForKey:kMediaTailorCustomTrackingURLDefaultsKey];
    if (fromDefaults.length > 0) return fromDefaults;

    NSString *fromEnv = NSProcessInfo.processInfo.environment[@"MT_CUSTOM_TRACKING_URL"];
    if (fromEnv.length > 0) return fromEnv;

    // Unset — the default manifest-URL-based derivation is used.
    return nil;
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
        [[MediaTailorSampleOption alloc]
            initWithLabel:@"Custom Domain (segment-prefix override)"
                urlString:[self customDomainURLString]
          adSegmentPrefix:[self customSegmentPrefixString]
              trackingUrl:[self customTrackingURLStringOrNil]],
    ];
}

@end
