//
//  MediaTailorSamples.m
//  SimplePlayerUsingPods
//

#import "MediaTailorSamples.h"

@implementation MediaTailorSamples

+ (NSString *)defaultSampleURLString {
    // AWS-documented MediaTailor sample. Replace with your own session URL
    // for the integration smoke test. Per `NRMediaTailorTracker_FEATURE_SPEC.md`
    // §9 "Definition of Done", the verification flow is:
    //   1. Run the app with a real MediaTailor URL here.
    //   2. Capture a proxy log (Charles / mitmproxy) and confirm the
    //      `/v1/tracking/<sessionId>` requests round-trip `nextToken`.
    //   3. Confirm in NRDB that AD_BREAK_START / AD_START / 3×AD_QUARTILE /
    //      AD_END / AD_BREAK_END fire for at least one ad break.
    return @"https://example.mediatailor.us-east-1.amazonaws.com/v1/master/REPLACE_ME/index.m3u8";
}

@end
