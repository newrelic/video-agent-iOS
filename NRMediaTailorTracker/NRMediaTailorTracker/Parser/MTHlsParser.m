//
//  MTHlsParser.m
//  NRMediaTailorTracker
//

#import "MTHlsParser.h"
#import "MTManifestParseResult.h"
#import "MTAdBreak.h"
#import "MTAdPod.h"
#import "MTDetector.h"

static NSString * const kMTDateRangeTag        = @"#EXT-X-DATERANGE";
static NSString * const kMTExtInfTag           = @"#EXTINF";
static NSString * const kMTDiscontinuityTag    = @"#EXT-X-DISCONTINUITY";
static NSString * const kMTProgramDateTimeTag  = @"#EXT-X-PROGRAM-DATE-TIME";

static NSString * const kMTTrackingClassInterstitial = @"com.apple.hls.interstitial";
static NSString * const kMTTrackingClassTracking     = @"tracking";

static const NSTimeInterval kMTMinAdDurationMs = 500.0;

static NSString * const kMTClampedPodCountThreadKey = @"NRMT.MTHlsParser.clampedPodCount";

@implementation MTHlsParser

#pragma mark - MTManifestParser conformance (T11 seam)

- (MTManifestParseResult *)parseManifest:(NSData *)manifest baseURL:(NSURL *)baseURL {
    if (manifest.length == 0) {
        return [MTManifestParseResult empty];
    }
    NSString *text = [[NSString alloc] initWithData:manifest encoding:NSUTF8StringEncoding];
    if (text.length == 0) {
        return [MTManifestParseResult empty];
    }
    return [MTHlsParser parseManifestText:text manifestURL:baseURL customSegmentMarkers:nil];
}


#pragma mark - Public

+ (MTManifestParseResult *)parseManifestText:(NSString *)manifestText {
    return [self parseManifestText:manifestText manifestURL:nil customSegmentMarkers:nil];
}

+ (MTManifestParseResult *)parseManifestText:(NSString *)manifestText
                                 manifestURL:(NSURL *)manifestURL
                        customSegmentMarkers:(NSArray<NSString *> *)customSegmentMarkers {
    [self resetClampedPodCount];
    if (manifestText.length == 0) return [MTManifestParseResult empty];

    NSArray<NSString *> *lines = [self splitLines:manifestText];
    NSArray<NSString *> *markers = [self resolveMarkers:customSegmentMarkers];

    NSURL *trackingURL = [self findTrackingURLInLines:lines manifestURL:manifestURL];
    NSArray<MTAdBreak *> *breaks = [self buildBreaksFromLines:lines markers:markers];

    return [[MTManifestParseResult alloc] initWithTrackingURL:trackingURL breaks:breaks];
}

+ (NSInteger)lastClampedPodCount {
    NSNumber *n = [NSThread currentThread].threadDictionary[kMTClampedPodCountThreadKey];
    return n ? n.integerValue : 0;
}

#pragma mark - DATERANGE / tracking URL

+ (nullable NSURL *)findTrackingURLInLines:(NSArray<NSString *> *)lines
                                manifestURL:(NSURL *)manifestURL {
    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![line hasPrefix:kMTDateRangeTag]) continue;

        NSDictionary<NSString *, NSString *> *attrs = [self parseAttributes:line afterTag:kMTDateRangeTag];
        NSString *classAttr = attrs[@"CLASS"];
        NSString *uriAttr   = attrs[@"URI"];
        if (uriAttr.length == 0) continue;
        if (![classAttr isEqualToString:kMTTrackingClassInterstitial] &&
            ![classAttr isEqualToString:kMTTrackingClassTracking]) {
            continue;
        }
        NSURL *url = manifestURL ? [NSURL URLWithString:uriAttr relativeToURL:manifestURL].absoluteURL
                                 : [NSURL URLWithString:uriAttr];
        if (url) return url;
    }
    return nil;
}

#pragma mark - Break / pod construction

+ (NSArray<MTAdBreak *> *)buildBreaksFromLines:(NSArray<NSString *> *)lines
                                       markers:(NSArray<NSString *> *)markers {
    NSMutableArray<MTAdBreak *> *out = [NSMutableArray array];

    MTAdBreak *currentBreak = nil;
    MTAdPod   *currentPod   = nil;
    NSTimeInterval cursorMs = 0.0;
    NSTimeInterval pendingExtInfMs = -1.0;
    BOOL pendingDiscontinuity = NO;
    NSString *pendingProgramDateTime = nil;
    NSString *currentBreakPDT = nil;

    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (line.length == 0) continue;

        if ([line hasPrefix:kMTDiscontinuityTag] &&
            ![line hasPrefix:@"#EXT-X-DISCONTINUITY-SEQUENCE"]) {
            pendingDiscontinuity = YES;
            continue;
        }
        if ([line hasPrefix:kMTProgramDateTimeTag]) {
            pendingProgramDateTime = [self valueAfterColonInTag:line];
            continue;
        }
        if ([line hasPrefix:kMTExtInfTag]) {
            pendingExtInfMs = [self extInfDurationMsFromLine:line];
            continue;
        }
        if ([line hasPrefix:@"#"]) {
            // Other tags — ignored for break detection.
            continue;
        }

        // Non-comment line: a media segment URL.
        NSString *segURL = line;
        NSTimeInterval segDurMs = pendingExtInfMs > 0 ? pendingExtInfMs : 0.0;
        NSTimeInterval segStartMs = cursorMs;

        BOOL isAdSegment = [self segmentURL:segURL matchesAnyMarker:markers];

        if (isAdSegment) {
            if (currentBreak == nil) {
                currentBreak = [[MTAdBreak alloc] initWithAvailId:[NSString stringWithFormat:@"hls-break-%lld",
                                                                   (long long)segStartMs]
                                                     startTimeMs:segStartMs
                                                      durationMs:0.0];
                currentBreakPDT = pendingProgramDateTime;
                if (currentBreakPDT.length > 0) {
                    currentBreak.availProgramDateTime = currentBreakPDT;
                }
                currentPod = [[MTAdPod alloc] initWithStartTimeMs:segStartMs durationMs:0.0];
                pendingDiscontinuity = NO; // first segment of a break implies a discontinuity
            } else if (pendingDiscontinuity) {
                [self closePod:currentPod intoBreak:currentBreak];
                currentPod = [[MTAdPod alloc] initWithStartTimeMs:segStartMs durationMs:0.0];
                pendingDiscontinuity = NO;
            }
            currentBreak.durationMs += segDurMs;
            currentPod.durationMs   += segDurMs;
        } else if (currentBreak != nil) {
            [self closePod:currentPod intoBreak:currentBreak];
            [self closeBreak:currentBreak into:out];
            currentBreak = nil;
            currentPod   = nil;
            pendingDiscontinuity = NO;
            currentBreakPDT = nil;
        }

        cursorMs += segDurMs;
        pendingExtInfMs = -1.0;
        pendingProgramDateTime = nil;
    }

    if (currentBreak != nil) {
        [self closePod:currentPod intoBreak:currentBreak];
        [self closeBreak:currentBreak into:out];
    }

    return [out copy];
}

+ (void)closePod:(MTAdPod *)pod intoBreak:(MTAdBreak *)br {
    if (pod == nil || br == nil) return;
    if (pod.durationMs < kMTMinAdDurationMs) return;

    if ([self clampPodIfNeeded:pod toBreak:br]) {
        if (pod.durationMs < kMTMinAdDurationMs) return;
    }
    [br.pods addObject:pod];
}

// Bug A6: clamp pod to the break window if it would overshoot.
+ (BOOL)clampPodIfNeeded:(MTAdPod *)pod toBreak:(MTAdBreak *)br {
    if (pod == nil || br == nil) return NO;
    NSTimeInterval podEnd = pod.startTimeMs + pod.durationMs;
    NSTimeInterval brkEnd = br.startTimeMs + br.durationMs;
    if (podEnd <= brkEnd) return NO;
    NSTimeInterval clamped = brkEnd - pod.startTimeMs;
    if (clamped < 0.0) clamped = 0.0;
    pod.durationMs = clamped;
    [self incrementClampedPodCount];
    return YES;
}

+ (void)closeBreak:(MTAdBreak *)br into:(NSMutableArray<MTAdBreak *> *)out {
    if (br == nil) return;
    if (br.durationMs < kMTMinAdDurationMs) return;
    [out addObject:br];
}

#pragma mark - Helpers — segment marker matching

+ (NSArray<NSString *> *)resolveMarkers:(NSArray<NSString *> *)extras {
    NSMutableArray<NSString *> *all = [[MTDetector defaultSegmentMarkers] mutableCopy];
    for (NSString *m in extras) {
        if (m.length > 0 && ![all containsObject:m]) {
            [all addObject:m];
        }
    }
    return [all copy];
}

+ (BOOL)segmentURL:(NSString *)url matchesAnyMarker:(NSArray<NSString *> *)markers {
    if (url.length == 0) return NO;
    for (NSString *m in markers) {
        if (m.length > 0 && [url rangeOfString:m].location != NSNotFound) return YES;
    }
    return NO;
}

#pragma mark - Helpers — m3u8 tokenization

+ (NSArray<NSString *> *)splitLines:(NSString *)manifestText {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    [manifestText enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        (void)stop;
        [out addObject:line];
    }];
    return out;
}

+ (NSTimeInterval)extInfDurationMsFromLine:(NSString *)line {
    NSString *value = [self valueAfterColonInTag:line];
    if (value.length == 0) return -1.0;
    NSRange comma = [value rangeOfString:@","];
    NSString *durText = comma.location != NSNotFound ? [value substringToIndex:comma.location] : value;
    durText = [durText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (durText.length == 0) return -1.0;
    double seconds = [durText doubleValue];
    if (seconds <= 0.0) return -1.0;
    return seconds * 1000.0;
}

+ (NSString *)valueAfterColonInTag:(NSString *)line {
    NSRange colon = [line rangeOfString:@":"];
    if (colon.location == NSNotFound) return @"";
    return [line substringFromIndex:colon.location + 1];
}

// Parses `KEY1=VAL1,KEY2="quoted val",KEY3=42` style attribute lists.
+ (NSDictionary<NSString *, NSString *> *)parseAttributes:(NSString *)line afterTag:(NSString *)tag {
    NSMutableDictionary<NSString *, NSString *> *out = [NSMutableDictionary dictionary];
    if (![line hasPrefix:tag]) return out;
    NSString *rest = [line substringFromIndex:tag.length];
    if ([rest hasPrefix:@":"]) rest = [rest substringFromIndex:1];

    NSUInteger i = 0;
    NSUInteger n = rest.length;
    while (i < n) {
        // Parse key.
        NSUInteger keyStart = i;
        while (i < n && [rest characterAtIndex:i] != '=') i++;
        if (i >= n) break;
        NSString *key = [[rest substringWithRange:NSMakeRange(keyStart, i - keyStart)]
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        i++; // skip '='
        if (i >= n) { out[key] = @""; break; }

        // Parse value: quoted or bare.
        NSString *value;
        if ([rest characterAtIndex:i] == '"') {
            i++; // skip opening quote
            NSUInteger valStart = i;
            while (i < n && [rest characterAtIndex:i] != '"') i++;
            value = (i <= n) ? [rest substringWithRange:NSMakeRange(valStart, i - valStart)] : @"";
            if (i < n) i++; // skip closing quote
        } else {
            NSUInteger valStart = i;
            while (i < n && [rest characterAtIndex:i] != ',') i++;
            value = [[rest substringWithRange:NSMakeRange(valStart, i - valStart)]
                     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        if (key.length > 0) out[key] = value ?: @"";

        // Skip optional comma + spaces.
        while (i < n) {
            unichar c = [rest characterAtIndex:i];
            if (c == ',' || c == ' ' || c == '\t') { i++; } else { break; }
        }
    }
    return out;
}

#pragma mark - Helpers — clamp telemetry

+ (void)resetClampedPodCount {
    [NSThread currentThread].threadDictionary[kMTClampedPodCountThreadKey] = @0;
}

+ (void)incrementClampedPodCount {
    NSMutableDictionary *td = [NSThread currentThread].threadDictionary;
    NSInteger prev = [td[kMTClampedPodCountThreadKey] integerValue];
    td[kMTClampedPodCountThreadKey] = @(prev + 1);
}

@end
