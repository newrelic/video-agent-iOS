//
//  MTDashParser.m
//  NRMediaTailorTracker
//
//  See MTDashParser.h for the design notes (Bug A7 fix, SCTE-35 handling,
//  filters). Uses NSXMLParser (Foundation) — no new pod deps.
//

#import "MTDashParser.h"
#import "MTManifestParseResult.h"
#import "MTAdBreak.h"
#import "MTAdPod.h"
#import "MTDetector.h"

static const NSTimeInterval kMTDashMinAdDurationMs = 500.0;

#pragma mark - Per-period accumulator

@interface MTDashPeriodAcc : NSObject
@property (nonatomic, copy, nullable)   NSString *periodId;
@property (nonatomic, assign)            BOOL hasStart;
@property (nonatomic, assign)            NSTimeInterval startMs;       // ISO 8601 duration → ms
@property (nonatomic, assign)            BOOL hasDuration;
@property (nonatomic, assign)            NSTimeInterval durationMs;
@property (nonatomic, copy, nullable)   NSString *periodBaseURL;       // raw text from <BaseURL> child of <Period>
// Per-adaptation-set tracking
@property (nonatomic, copy, nullable)   NSString *currentAdaptationBaseURL;
@property (nonatomic, copy, nullable)   NSString *currentRepresentationBaseURL;
// Aggregated representation classifications for this period.
@property (nonatomic, assign)            NSUInteger representationCount;
@property (nonatomic, assign)            NSUInteger representationAdMatchCount;
// SCTE-35 / mediatailor EventStream events found inside this period.
@property (nonatomic, strong)            NSMutableArray<MTAdBreak *> *eventStreamBreaks;
@end

@implementation MTDashPeriodAcc
- (instancetype)init {
    if ((self = [super init])) {
        _eventStreamBreaks = [NSMutableArray array];
    }
    return self;
}
@end

#pragma mark - Parser

@interface MTDashParser () <NSXMLParserDelegate>
@end

@implementation MTDashParser {
    // Output collected during the parse.
    NSMutableArray<MTAdBreak *> *_breaks;
    NSURL *_trackingURL;
    NSError *_parseError;

    // Top-level state.
    NSURL *_baseURLParam;
    NSURL *_topLevelBaseURL;                  // resolved <BaseURL> child of <MPD>
    NSMutableString *_topLevelBaseURLText;    // raw text accumulator
    BOOL _capturingTopLevelBaseURL;
    NSTimeInterval _availabilityStartTimeUnixMs; // 0 if absent
    BOOL _hasAvailabilityStartTime;

    // <Location> text accumulator for tracking URL.
    BOOL _capturingLocation;
    NSMutableString *_locationText;

    // <BaseURL> text accumulators (depth-aware).
    BOOL _capturingPeriodBaseURL;
    NSMutableString *_periodBaseURLText;
    BOOL _capturingAdaptationBaseURL;
    NSMutableString *_adaptationBaseURLText;
    BOOL _capturingRepresentationBaseURL;
    NSMutableString *_representationBaseURLText;

    // Period accumulator + running sum-of-prior-durations for `start` fallback.
    MTDashPeriodAcc *_currentPeriod;
    NSTimeInterval _runningPriorPeriodEndMs;

    // EventStream parsing state.
    BOOL _insideAdEventStream;        // SCTE-35 or mediatailor tracking
    BOOL _insideTrackingEventStream;  // urn:aws:elemental:mediatailor:tracking
    double _eventStreamTimescale;     // defaults to 1 per DASH spec

    // Mixed-classification telemetry (Bug A7).
    NSUInteger _mixedPeriodCount;
}

- (instancetype)init {
    if ((self = [super init])) {
        _mixedPeriodCount = 0;
    }
    return self;
}

#pragma mark - MTManifestParser conformance

- (MTManifestParseResult *)parseManifest:(NSData *)manifest baseURL:(NSURL *)baseURL {
    if (manifest.length == 0) return [MTManifestParseResult empty];
    NSString *text = [[NSString alloc] initWithData:manifest encoding:NSUTF8StringEncoding];
    if (text.length == 0) {
        // Non-UTF-8 bytes.
        return [MTManifestParseResult empty];
    }

    // Reset per-parse state.
    _breaks = [NSMutableArray array];
    _trackingURL = nil;
    _parseError = nil;
    _baseURLParam = baseURL;
    _topLevelBaseURL = nil;
    _topLevelBaseURLText = nil;
    _capturingTopLevelBaseURL = NO;
    _availabilityStartTimeUnixMs = 0;
    _hasAvailabilityStartTime = NO;
    _capturingLocation = NO;
    _locationText = nil;
    _capturingPeriodBaseURL = NO;
    _periodBaseURLText = nil;
    _capturingAdaptationBaseURL = NO;
    _adaptationBaseURLText = nil;
    _capturingRepresentationBaseURL = NO;
    _representationBaseURLText = nil;
    _currentPeriod = nil;
    _runningPriorPeriodEndMs = 0;
    _insideAdEventStream = NO;
    _insideTrackingEventStream = NO;
    _eventStreamTimescale = 1.0;

    NSXMLParser *xml = [[NSXMLParser alloc] initWithData:manifest];
    xml.delegate = self;
    xml.shouldProcessNamespaces = NO;
    BOOL ok = [xml parse];
    if (!ok || _parseError != nil) {
        NSLog(@"⚠️ [MTDashParser] XML parse error: %@", _parseError ?: xml.parserError);
        return [MTManifestParseResult empty];
    }

    return [[MTManifestParseResult alloc] initWithTrackingURL:_trackingURL
                                                       breaks:[_breaks copy]];
}

- (NSUInteger)mixedPeriodCount {
    return _mixedPeriodCount;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser
    didStartElement:(NSString *)elementName
       namespaceURI:(NSString *)namespaceURI
      qualifiedName:(NSString *)qName
         attributes:(NSDictionary<NSString *, NSString *> *)attrs {

    if ([elementName isEqualToString:@"MPD"]) {
        NSString *avs = attrs[@"availabilityStartTime"];
        if (avs.length > 0) {
            NSDate *d = [self parseISO8601Date:avs];
            if (d != nil) {
                _availabilityStartTimeUnixMs = [d timeIntervalSince1970] * 1000.0;
                _hasAvailabilityStartTime = YES;
            }
        }
        return;
    }

    if ([elementName isEqualToString:@"Location"]) {
        _capturingLocation = YES;
        _locationText = [NSMutableString string];
        return;
    }

    if ([elementName isEqualToString:@"BaseURL"]) {
        // Depth-aware: which container are we in?
        if (_currentPeriod != nil) {
            if (_currentPeriod.currentRepresentationBaseURL == nil &&
                _currentPeriod.currentAdaptationBaseURL == nil) {
                _capturingPeriodBaseURL = YES;
                _periodBaseURLText = [NSMutableString string];
            } else if (_currentPeriod.currentRepresentationBaseURL == nil) {
                _capturingAdaptationBaseURL = YES;
                _adaptationBaseURLText = [NSMutableString string];
            } else {
                _capturingRepresentationBaseURL = YES;
                _representationBaseURLText = [NSMutableString string];
            }
        } else {
            _capturingTopLevelBaseURL = YES;
            _topLevelBaseURLText = [NSMutableString string];
        }
        return;
    }

    if ([elementName isEqualToString:@"Period"]) {
        _currentPeriod = [[MTDashPeriodAcc alloc] init];
        _currentPeriod.periodId = attrs[@"id"];

        NSString *startAttr = attrs[@"start"];
        if (startAttr.length > 0) {
            NSTimeInterval startMs = [self parseISO8601DurationMs:startAttr];
            if (startMs >= 0) {
                _currentPeriod.hasStart = YES;
                _currentPeriod.startMs = startMs;
            }
        }
        NSString *durationAttr = attrs[@"duration"];
        if (durationAttr.length > 0) {
            NSTimeInterval durMs = [self parseISO8601DurationMs:durationAttr];
            if (durMs >= 0) {
                _currentPeriod.hasDuration = YES;
                _currentPeriod.durationMs = durMs;
            }
        }
        return;
    }

    if ([elementName isEqualToString:@"AdaptationSet"]) {
        if (_currentPeriod != nil) {
            _currentPeriod.currentAdaptationBaseURL = nil;  // reset
        }
        return;
    }

    if ([elementName isEqualToString:@"Representation"]) {
        if (_currentPeriod != nil) {
            _currentPeriod.currentRepresentationBaseURL = nil;
            _currentPeriod.representationCount += 1;
        }
        return;
    }

    if ([elementName isEqualToString:@"EventStream"]) {
        NSString *scheme = attrs[@"schemeIdUri"];
        _insideAdEventStream = NO;
        _insideTrackingEventStream = NO;
        if ([scheme isEqualToString:@"urn:scte:scte35:2014:xml"] ||
            [scheme hasPrefix:@"urn:scte:scte35"]) {
            _insideAdEventStream = YES;
        } else if ([scheme isEqualToString:@"urn:aws:elemental:mediatailor:tracking"]) {
            _insideAdEventStream = YES;
            _insideTrackingEventStream = YES;
        }
        NSString *ts = attrs[@"timescale"];
        _eventStreamTimescale = ts.doubleValue > 0 ? ts.doubleValue : 1.0;
        return;
    }

    if ([elementName isEqualToString:@"Event"] && _insideAdEventStream) {
        if (_currentPeriod == nil) return;
        double presentationTime = [attrs[@"presentationTime"] doubleValue];
        double duration         = [attrs[@"duration"] doubleValue];
        NSTimeInterval startMs    = (presentationTime / _eventStreamTimescale) * 1000.0;
        NSTimeInterval durationMs = (duration / _eventStreamTimescale) * 1000.0;

        // Resolve availId: prefer Period id, fall back to event messageData.
        NSString *availId = _currentPeriod.periodId.length > 0
                                ? _currentPeriod.periodId
                                : attrs[@"messageData"];

        if (durationMs < kMTDashMinAdDurationMs) return;

        MTAdBreak *br = [[MTAdBreak alloc] initWithAvailId:availId
                                              startTimeMs:startMs
                                               durationMs:durationMs];
        if (_hasAvailabilityStartTime) {
            br.availProgramDateTime =
                [self iso8601StringForUnixMs:(_availabilityStartTimeUnixMs + startMs)];
        }
        br.isNoFill = NO;
        [_currentPeriod.eventStreamBreaks addObject:br];
        return;
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (_capturingLocation) {
        [_locationText appendString:string];
        return;
    }
    if (_capturingRepresentationBaseURL) {
        [_representationBaseURLText appendString:string];
        return;
    }
    if (_capturingAdaptationBaseURL) {
        [_adaptationBaseURLText appendString:string];
        return;
    }
    if (_capturingPeriodBaseURL) {
        [_periodBaseURLText appendString:string];
        return;
    }
    if (_capturingTopLevelBaseURL) {
        [_topLevelBaseURLText appendString:string];
        return;
    }
}

- (void)parser:(NSXMLParser *)parser
    didEndElement:(NSString *)elementName
     namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qName {

    if ([elementName isEqualToString:@"Location"]) {
        NSString *trimmed = [_locationText stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0 && _trackingURL == nil) {
            _trackingURL = [self resolveURLString:trimmed against:_baseURLParam];
        }
        _capturingLocation = NO;
        _locationText = nil;
        return;
    }

    if ([elementName isEqualToString:@"BaseURL"]) {
        NSString *trimmed = nil;
        if (_capturingRepresentationBaseURL) {
            trimmed = [_representationBaseURLText stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            _currentPeriod.currentRepresentationBaseURL = trimmed;
            _capturingRepresentationBaseURL = NO;
            _representationBaseURLText = nil;
        } else if (_capturingAdaptationBaseURL) {
            trimmed = [_adaptationBaseURLText stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            _currentPeriod.currentAdaptationBaseURL = trimmed;
            _capturingAdaptationBaseURL = NO;
            _adaptationBaseURLText = nil;
        } else if (_capturingPeriodBaseURL) {
            trimmed = [_periodBaseURLText stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            _currentPeriod.periodBaseURL = trimmed;
            _capturingPeriodBaseURL = NO;
            _periodBaseURLText = nil;
        } else if (_capturingTopLevelBaseURL) {
            trimmed = [_topLevelBaseURLText stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length > 0) {
                _topLevelBaseURL = [self resolveURLString:trimmed against:_baseURLParam];
            }
            _capturingTopLevelBaseURL = NO;
            _topLevelBaseURLText = nil;
        }
        return;
    }

    if ([elementName isEqualToString:@"Representation"]) {
        // Classify this representation's effective URL against ad markers.
        if (_currentPeriod != nil) {
            NSString *effective = [self effectiveURLForCurrentRepresentation];
            BOOL adMatch = [self urlMatchesAdMarker:effective];
            if (adMatch) {
                _currentPeriod.representationAdMatchCount += 1;
            }
            _currentPeriod.currentRepresentationBaseURL = nil;
        }
        return;
    }

    if ([elementName isEqualToString:@"AdaptationSet"]) {
        if (_currentPeriod != nil) {
            _currentPeriod.currentAdaptationBaseURL = nil;
        }
        return;
    }

    if ([elementName isEqualToString:@"EventStream"]) {
        _insideAdEventStream = NO;
        _insideTrackingEventStream = NO;
        _eventStreamTimescale = 1.0;
        return;
    }

    if ([elementName isEqualToString:@"Period"]) {
        [self finalizeCurrentPeriod];
        return;
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    _parseError = parseError;
}

#pragma mark - Period finalisation

- (void)finalizeCurrentPeriod {
    MTDashPeriodAcc *p = _currentPeriod;
    _currentPeriod = nil;
    if (p == nil) return;

    // 1. SCTE-35 / tracking EventStream events take precedence regardless of
    //    BaseURL classification (atomic facts §10 — they're the canonical
    //    DASH ad-break markers).
    if (p.eventStreamBreaks.count > 0) {
        [_breaks addObjectsFromArray:p.eventStreamBreaks];
        // Advance the running cursor by the period duration when known so
        // subsequent fallback `start` inference stays consistent.
        if (p.hasDuration) {
            _runningPriorPeriodEndMs = (p.hasStart ? p.startMs : _runningPriorPeriodEndMs) + p.durationMs;
        }
        return;
    }

    // 2. BaseURL-marker classification (Bug A7 — ALL representations must match).
    BOOL classifiedAsAd = NO;
    if (p.representationCount > 0) {
        if (p.representationAdMatchCount == p.representationCount) {
            classifiedAsAd = YES;
        } else if (p.representationAdMatchCount > 0) {
            // Mixed — Bug A7: classify as content, not ad.
            _mixedPeriodCount += 1;
            NSLog(@"⚠️ [MTDashParser] mixed-content period %@: %lu reps, %lu match ad markers — classifying as CONTENT",
                  p.periodId ?: @"<no-id>",
                  (unsigned long)p.representationCount,
                  (unsigned long)p.representationAdMatchCount);
        }
    }

    // 3. Resolve period start. Use `start` attribute when present, otherwise
    //    fall back to the running cursor (sum of prior period durations).
    NSTimeInterval startMs = p.hasStart ? p.startMs : _runningPriorPeriodEndMs;

    if (classifiedAsAd) {
        if (!p.hasDuration) {
            NSLog(@"⚠️ [MTDashParser] ad period %@ has no duration — skipping",
                  p.periodId ?: @"<no-id>");
        } else if (p.durationMs >= kMTDashMinAdDurationMs) {
            MTAdBreak *br = [[MTAdBreak alloc] initWithAvailId:p.periodId
                                                   startTimeMs:startMs
                                                    durationMs:p.durationMs];
            if (_hasAvailabilityStartTime) {
                br.availProgramDateTime =
                    [self iso8601StringForUnixMs:(_availabilityStartTimeUnixMs + startMs)];
            }
            br.isNoFill = NO;
            [_breaks addObject:br];
        }
    }

    // 4. Advance the running cursor for the next period.
    if (p.hasDuration) {
        _runningPriorPeriodEndMs = startMs + p.durationMs;
    } else if (p.hasStart) {
        _runningPriorPeriodEndMs = p.startMs;
    }
}

#pragma mark - Helpers — URL resolution + ad-marker matching

- (nullable NSString *)effectiveURLForCurrentRepresentation {
    // Inheritance: representation BaseURL overrides adaptation overrides period
    // overrides top-level overrides parameter baseURL.
    NSString *repURL = _currentPeriod.currentRepresentationBaseURL;
    NSString *adaURL = _currentPeriod.currentAdaptationBaseURL;
    NSString *perURL = _currentPeriod.periodBaseURL;

    NSURL *base = _topLevelBaseURL ?: _baseURLParam;

    NSURL *effective = base;
    if (perURL.length > 0) effective = [self resolveURLString:perURL against:effective];
    if (adaURL.length > 0) effective = [self resolveURLString:adaURL against:effective];
    if (repURL.length > 0) effective = [self resolveURLString:repURL against:effective];

    // If we have no per-segment URL at all (no BaseURLs in the period, only
    // SegmentTemplate-derived URLs), fall back to whichever BaseURL we resolved
    // — usually the parameter baseURL. Per spec: "BaseURL is relative (no
    // scheme) → resolve against baseURL parameter; if both nil, treat as
    // ambiguous and classify as content".
    if (effective == nil) {
        // Build a synthetic string from whatever raw values we have.
        NSMutableString *concat = [NSMutableString string];
        if (perURL.length > 0) [concat appendString:perURL];
        if (adaURL.length > 0) [concat appendString:adaURL];
        if (repURL.length > 0) [concat appendString:repURL];
        return concat.length > 0 ? [concat copy] : nil;
    }
    return effective.absoluteString;
}

- (nullable NSURL *)resolveURLString:(NSString *)urlString against:(nullable NSURL *)base {
    if (urlString.length == 0) return base;
    // Absolute first — works regardless of base.
    NSURL *absolute = [NSURL URLWithString:urlString];
    if (absolute.scheme.length > 0) return absolute;
    if (base == nil) return absolute; // best-effort: keep the raw string as a URL
    return [[NSURL URLWithString:urlString relativeToURL:base] absoluteURL];
}

- (BOOL)urlMatchesAdMarker:(nullable NSString *)url {
    if (url.length == 0) return NO;
    for (NSString *m in [MTDetector defaultSegmentMarkers]) {
        if (m.length > 0 && [url rangeOfString:m].location != NSNotFound) return YES;
    }
    return NO;
}

#pragma mark - Helpers — ISO 8601 parsing

/// Parses an ISO 8601 duration like `PT30S`, `PT1M30.5S`, `PT2H15M`, `P1DT2H`.
/// Returns milliseconds, or -1 if the string is not a recognisable duration.
/// Supports day / hour / minute / second components with optional fractional
/// seconds. Not a complete ISO 8601 implementation — covers what DASH MPDs
/// realistically emit for `start` / `duration`.
- (NSTimeInterval)parseISO8601DurationMs:(NSString *)s {
    if (s.length < 2 || ![s hasPrefix:@"P"]) return -1.0;
    NSUInteger i = 1;
    NSUInteger n = s.length;
    BOOL inTimePart = NO;
    double days = 0, hours = 0, minutes = 0, seconds = 0;
    BOOL anyComponent = NO;

    while (i < n) {
        unichar c = [s characterAtIndex:i];
        if (c == 'T') {
            inTimePart = YES;
            i++;
            continue;
        }
        // Read a number (may include a decimal point).
        NSUInteger start = i;
        while (i < n) {
            unichar cc = [s characterAtIndex:i];
            if ((cc >= '0' && cc <= '9') || cc == '.' || cc == ',') {
                i++;
            } else {
                break;
            }
        }
        if (i == start) return -1.0; // expected a number
        NSString *num = [s substringWithRange:NSMakeRange(start, i - start)];
        num = [num stringByReplacingOccurrencesOfString:@"," withString:@"."];
        double v = num.doubleValue;
        if (i >= n) return -1.0;
        unichar unit = [s characterAtIndex:i++];
        if (!inTimePart) {
            if (unit == 'D') { days = v; anyComponent = YES; }
            else if (unit == 'W') { days = v * 7; anyComponent = YES; }
            else if (unit == 'Y' || unit == 'M') {
                // Year / month — not meaningful for ad durations; reject.
                return -1.0;
            } else { return -1.0; }
        } else {
            if (unit == 'H')      { hours = v;   anyComponent = YES; }
            else if (unit == 'M') { minutes = v; anyComponent = YES; }
            else if (unit == 'S') { seconds = v; anyComponent = YES; }
            else { return -1.0; }
        }
    }
    if (!anyComponent) return -1.0;
    double totalSeconds = days * 86400.0 + hours * 3600.0 + minutes * 60.0 + seconds;
    return totalSeconds * 1000.0;
}

- (nullable NSDate *)parseISO8601Date:(NSString *)s {
    if (s.length == 0) return nil;
    static NSISO8601DateFormatter *fmt;
    static NSISO8601DateFormatter *fmtWithMs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSISO8601DateFormatter alloc] init];
        fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        fmtWithMs = [[NSISO8601DateFormatter alloc] init];
        fmtWithMs.formatOptions = NSISO8601DateFormatWithInternetDateTime
                                | NSISO8601DateFormatWithFractionalSeconds;
    });
    NSDate *d = [fmtWithMs dateFromString:s];
    if (d == nil) d = [fmt dateFromString:s];
    return d;
}

- (nullable NSString *)iso8601StringForUnixMs:(NSTimeInterval)unixMs {
    static NSISO8601DateFormatter *fmt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSISO8601DateFormatter alloc] init];
        fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime
                          | NSISO8601DateFormatWithFractionalSeconds;
    });
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:unixMs / 1000.0];
    return [fmt stringFromDate:d];
}

@end
