//
//  MTDetector.m
//  NRMediaTailorTracker
//
//  Ported from Android `MTDetector.java` (lines 27–62).
//  See `MTDetector.h` for the PRIMARY (T05 manifest marker) vs FALLBACK
//  (URL rewrite) distinction.
//

#import "MTDetector.h"

static NSString * const kMTURLMarker = @"mediatailor";

static NSString * const kMTSessionIdRegexPattern = @"sessionId=([^&]+)";
static NSString * const kMTManifestSegmentRegexPattern = @"/v1/(master|session|dash)/";
static NSString * const kMTManifestFileRegexPattern = @"/[^/]*\\.(m3u8|mpd)(\\?.*)?$";

@implementation MTDetector

+ (NSRegularExpression *)sessionIdRegex {
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:kMTSessionIdRegexPattern
                                                          options:0
                                                            error:nil];
    });
    return regex;
}

+ (NSRegularExpression *)manifestSegmentRegex {
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:kMTManifestSegmentRegexPattern
                                                          options:0
                                                            error:nil];
    });
    return regex;
}

+ (NSRegularExpression *)manifestFileRegex {
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:kMTManifestFileRegexPattern
                                                          options:0
                                                            error:nil];
    });
    return regex;
}

+ (BOOL)isMediaTailorURL:(NSURL *)url {
    if (url == nil) return NO;
    NSString *s = url.absoluteString;
    if (s.length == 0) return NO;
    return [s rangeOfString:kMTURLMarker].location != NSNotFound;
}

+ (nullable NSString *)extractSessionId:(NSURL *)url {
    if (url == nil) return nil;
    NSString *full = url.absoluteString;
    if (full.length == 0) return nil;

    NSTextCheckingResult *match = [[self sessionIdRegex] firstMatchInString:full
                                                                    options:0
                                                                      range:NSMakeRange(0, full.length)];
    if (match == nil || match.numberOfRanges < 2) return nil;
    NSRange capture = [match rangeAtIndex:1];
    if (capture.location == NSNotFound) return nil;
    NSString *sessionId = [full substringWithRange:capture];
    return sessionId.length > 0 ? sessionId : nil;
}

+ (nullable NSURL *)deriveTrackingURL:(NSURL *)url {
    if (![self isMediaTailorURL:url]) return nil;

    NSString *sessionId = [self extractSessionId:url];
    if (sessionId.length == 0) return nil;

    NSString *full = url.absoluteString;
    NSRange fullRange = NSMakeRange(0, full.length);

    NSString *rewritten = [[self manifestSegmentRegex]
                           stringByReplacingMatchesInString:full
                                                    options:0
                                                      range:fullRange
                                               withTemplate:@"/v1/tracking/"];

    NSString *replacement = [@"/" stringByAppendingString:sessionId];
    rewritten = [[self manifestFileRegex]
                 stringByReplacingMatchesInString:rewritten
                                          options:0
                                            range:NSMakeRange(0, rewritten.length)
                                     withTemplate:replacement];

    NSRange queryRange = [rewritten rangeOfString:@"?"];
    if (queryRange.location != NSNotFound) {
        rewritten = [rewritten substringToIndex:queryRange.location];
    }

    return [NSURL URLWithString:rewritten];
}

+ (NSArray<NSString *> *)defaultSegmentMarkers {
    static NSArray<NSString *> *markers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        markers = @[
            @"segments.mediatailor",
            @"/v1/dashsegment/",
            @"/v1/hlssegment/",
            @"/tm/",
        ];
    });
    return markers;
}

@end
