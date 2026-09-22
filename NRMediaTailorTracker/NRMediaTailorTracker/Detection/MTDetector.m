//
//  MTDetector.m
//  NRMediaTailorTracker
//
//  Ported from Android `MTDetector.java` (lines 27–62).
//  See `MTDetector.h` for the PRIMARY (manifest marker) vs FALLBACK
//  (URL rewrite) distinction.
//

#import "MTDetector.h"

static NSString * const kMTURLMarker = @"mediatailor";

static NSString * const kMTSessionIdRegexPattern = @"sessionId=([^&]+)";
static NSString * const kMTManifestSegmentRegexPattern = @"/v1/(master|session|dash)/";
static NSString * const kMTManifestFileRegexPattern = @"/[^/]*\\.(m3u8|mpd)(\\?.*)?$";

// Explicit session-init (POST /v1/session/...) resolves to a manifest URL with
// the session id in the query string (?aws.sessionId=...) — kMTSessionIdRegexPattern
// above handles that. The direct/implicit flow (GET /v1/master/... with no
// query at all) never puts a session id on that entry URL — MediaTailor only
// reveals it in the URLs *inside* the manifest it returns:
//   /v1/manifest/{account}/{config}/{sessionId}/{variant}.m3u8   (sub-playlist)
//   /v1/segment/{account}/{config}/{sessionId}/{variant}/{segment} (segment)
// So a caller that only ever has the top-level direct URL genuinely cannot
// derive a tracking URL — there is no session id in that string. But once the
// player/parser touches one of the URLs above (which it does, to play the
// stream at all), THIS pattern recovers the session id from it.
static NSString * const kMTPathSessionIdRegexPattern =
    @"^(https?://[^/]+/v1/)(?:manifest|segment)(/[^/]+/[^/]+/)([^/]+)/";

// `isMediaTailorURL:` originally relied solely on the hostname containing
// "mediatailor" — true for the raw *.mediatailor.<region>.amazonaws.com
// endpoint, but AWS's own recommended CDN-fronted deployment shape fronts
// MediaTailor with a custom hostname that never contains that substring at
// all. Example that must detect as YES:
// https://cdn.example.com/v1/master/{account}/{config}/index.m3u8 — no
// "mediatailor" anywhere, but unmistakably a MediaTailor path. This pattern
// recognizes that path convention regardless of hostname.
static NSString * const kMTPathConventionRegexPattern =
    @"/v1/(?:master|session|dash|manifest|segment|tracking)/";

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

+ (NSRegularExpression *)pathSessionIdRegex {
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:kMTPathSessionIdRegexPattern
                                                          options:0
                                                            error:nil];
    });
    return regex;
}

+ (NSRegularExpression *)pathConventionRegex {
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:kMTPathConventionRegexPattern
                                                          options:0
                                                            error:nil];
    });
    return regex;
}

+ (BOOL)isMediaTailorURL:(NSURL *)url {
    if (url == nil) return NO;
    NSString *s = url.absoluteString;
    if (s.length == 0) return NO;
    if ([s rangeOfString:kMTURLMarker].location != NSNotFound) return YES;

    // Hostname-based check missed it — try the path convention instead, so a
    // custom-domain/CloudFront-fronted MediaTailor URL still detects as YES.
    NSTextCheckingResult *m = [[self pathConventionRegex] firstMatchInString:s
                                                                      options:0
                                                                        range:NSMakeRange(0, s.length)];
    return m != nil;
}

+ (nullable NSString *)extractSessionId:(NSURL *)url {
    if (url == nil) return nil;
    NSString *full = url.absoluteString;
    if (full.length == 0) return nil;

    NSTextCheckingResult *match = [[self sessionIdRegex] firstMatchInString:full
                                                                    options:0
                                                                      range:NSMakeRange(0, full.length)];
    if (match != nil && match.numberOfRanges >= 2) {
        NSRange capture = [match rangeAtIndex:1];
        if (capture.location != NSNotFound) {
            NSString *sessionId = [full substringWithRange:capture];
            if (sessionId.length > 0) return sessionId;
        }
    }

    // Fallback: no query-string session id (the direct/implicit flow's
    // resolved manifest/segment URLs carry it as a path segment instead).
    NSTextCheckingResult *pathMatch = [[self pathSessionIdRegex] firstMatchInString:full
                                                                             options:0
                                                                               range:NSMakeRange(0, full.length)];
    if (pathMatch == nil || pathMatch.numberOfRanges < 4) return nil;
    NSRange pathCapture = [pathMatch rangeAtIndex:3];
    if (pathCapture.location == NSNotFound) return nil;
    NSString *sessionId = [full substringWithRange:pathCapture];
    return sessionId.length > 0 ? sessionId : nil;
}

+ (nullable NSURL *)deriveTrackingURL:(NSURL *)url {
    if (![self isMediaTailorURL:url]) return nil;

    NSString *full = url.absoluteString;

    // Direct/implicit flow: session id is a path segment on a resolved
    // manifest/segment URL, not a query param. Handled separately because the
    // generic rewrite below assumes the session id is the last thing before
    // (or replaces) a trailing filename — true for the query-string case, not
    // for this one, where the session id sits mid-path with more segments
    // after it that need dropping rather than rewriting.
    NSTextCheckingResult *pathMatch = [[self pathSessionIdRegex] firstMatchInString:full
                                                                             options:0
                                                                               range:NSMakeRange(0, full.length)];
    if (pathMatch != nil && pathMatch.numberOfRanges >= 4) {
        NSRange prefixRange = [pathMatch rangeAtIndex:1];   // "https://host/v1/"
        NSRange middleRange = [pathMatch rangeAtIndex:2];   // "/account/config/"
        NSRange sessionRange = [pathMatch rangeAtIndex:3];  // "{sessionId}"
        if (prefixRange.location != NSNotFound && middleRange.location != NSNotFound &&
            sessionRange.location != NSNotFound) {
            NSString *prefix = [full substringWithRange:prefixRange];
            NSString *middle = [full substringWithRange:middleRange];
            NSString *sessionId = [full substringWithRange:sessionRange];
            if (sessionId.length > 0) {
                NSString *rewritten = [NSString stringWithFormat:@"%@tracking%@%@", prefix, middle, sessionId];
                return [NSURL URLWithString:rewritten];
            }
        }
    }

    // Explicit/query-string flow (existing behavior, unchanged).
    NSString *sessionId = [self extractSessionId:url];
    if (sessionId.length == 0) return nil;

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
            // The raw, as-written-in-the-manifest AWS convention for HLS
            // segments (`/v1/segment/{account}/{config}/{sessionId}/...`) —
            // confirmed against a real MediaTailor manifest. Distinct from
            // the four markers above, which are all *post-redirect* target
            // shapes (what a segment URL becomes after MediaTailor 301s it,
            // e.g. to `segments.mediatailor.*` or a `/tm/` path) — those never
            // appear in the manifest text itself, only in a resolved fetch.
            // Without this, MTHlsParser correctly finds the
            // `#EXT-X-DISCONTINUITY` boundaries but never recognizes any
            // segment inside them as an ad, so real ad breaks silently parse
            // as zero breaks.
            @"/v1/segment/",
        ];
    });
    return markers;
}

@end
