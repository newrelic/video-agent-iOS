//
//  NRMTManifestParser.m
//  NRMediaTailorTracker
//
//  Created by New Relic on 05/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import "NRMTManifestParser.h"
#import "NRMTUtilities.h"
#import "NRMTAdBreak.h"

@implementation NRMTManifestParserResult
@end

@implementation NRMTManifestParser

+ (void)parseManifestAtURL:(NSString *)manifestURL
                trackingURL:(nullable NSString *)trackingURL
                 completion:(void (^)(NRMTManifestParserResult * _Nullable, NSError * _Nullable))completion {

    NSLog(@"%@ 🔍 Pre-fetching manifest: %@", [NRMTUtilities logPrefix], manifestURL);

    // Step 1: Fetch master manifest
    NSURL *masterURL = [NSURL URLWithString:manifestURL];
    if (!masterURL) {
        NSError *error = [NSError errorWithDomain:@"NRMTManifestParser" code:1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid manifest URL"}];
        completion(nil, error);
        return;
    }

    NSURLRequest *request = [NSURLRequest requestWithURL:masterURL];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"%@ ❌ Master manifest fetch failed: %@", [NRMTUtilities logPrefix], error.localizedDescription);
                completion(nil, error);
                return;
            }

            NSString *masterContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!masterContent) {
                NSError *err = [NSError errorWithDomain:@"NRMTManifestParser" code:2
                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode master manifest"}];
                completion(nil, err);
                return;
            }

            // Step 2: Extract media playlist URL from master manifest
            NSString *mediaPlaylistURL = [self extractFirstMediaPlaylistURL:masterContent baseURL:manifestURL];
            if (!mediaPlaylistURL) {
                NSError *err = [NSError errorWithDomain:@"NRMTManifestParser" code:3
                                               userInfo:@{NSLocalizedDescriptionKey: @"No media playlist found in master manifest"}];
                completion(nil, err);
                return;
            }

            NSLog(@"%@ 📄 Media playlist URL: %@", [NRMTUtilities logPrefix], mediaPlaylistURL);

            // Step 3: Fetch media playlist
            NSURL *mediaURL = [NSURL URLWithString:mediaPlaylistURL];
            NSURLRequest *mediaRequest = [NSURLRequest requestWithURL:mediaURL];
            NSURLSessionDataTask *mediaTask = [[NSURLSession sharedSession] dataTaskWithRequest:mediaRequest
                completionHandler:^(NSData *mediaData, NSURLResponse *mediaResponse, NSError *mediaError) {
                    if (mediaError) {
                        NSLog(@"%@ ❌ Media playlist fetch failed: %@", [NRMTUtilities logPrefix], mediaError.localizedDescription);
                        completion(nil, mediaError);
                        return;
                    }

                    NSString *mediaContent = [[NSString alloc] initWithData:mediaData encoding:NSUTF8StringEncoding];
                    if (!mediaContent) {
                        NSError *err = [NSError errorWithDomain:@"NRMTManifestParser" code:4
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode media playlist"}];
                        completion(nil, err);
                        return;
                    }

                    // 🔍 LOG FULL MANIFEST CONTENT FOR DEBUGGING
                    NSLog(@"%@ 📄 ===== FULL MEDIA PLAYLIST CONTENT =====", [NRMTUtilities logPrefix]);
                    NSLog(@"%@", mediaContent);
                    NSLog(@"%@ 📄 ===== END MEDIA PLAYLIST =====", [NRMTUtilities logPrefix]);

                    // Step 4: Parse media playlist for ad breaks
                    NRMTManifestParserResult *result = [self parseMediaPlaylist:mediaContent trackingURL:trackingURL];

                    NSLog(@"%@ ✅ Manifest parsed: %ld ad break(s), VOD=%@",
                          [NRMTUtilities logPrefix], (long)result.adBreaks.count, result.isVOD ? @"YES" : @"NO");

                    completion(result, nil);
                }];
            [mediaTask resume];
        }];
    [task resume];
}

+ (NSString *)extractFirstMediaPlaylistURL:(NSString *)masterContent baseURL:(NSString *)baseURL {
    NSArray *lines = [masterContent componentsSeparatedByString:@"\n"];

    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // Skip comments and tags
        if ([trimmed hasPrefix:@"#"] || trimmed.length == 0) {
            continue;
        }

        // First non-comment line is a playlist URL
        if ([trimmed hasSuffix:@".m3u8"]) {
            // Check if relative or absolute
            if ([trimmed hasPrefix:@"http"]) {
                return trimmed;
            } else {
                // Relative URL - construct from base
                NSURL *base = [NSURL URLWithString:baseURL];
                NSURL *resolved = [NSURL URLWithString:trimmed relativeToURL:base];
                return [resolved absoluteString];
            }
        }
    }

    return nil;
}

+ (NRMTManifestParserResult *)parseMediaPlaylist:(NSString *)content trackingURL:(nullable NSString *)trackingURL {
    NRMTManifestParserResult *result = [[NRMTManifestParserResult alloc] init];
    result.trackingURL = trackingURL;

    NSMutableArray<NRMTAdBreak *> *adBreaks = [NSMutableArray array];
    NSArray *lines = [content componentsSeparatedByString:@"\n"];

    NSTimeInterval currentTime = 0.0;
    NSTimeInterval targetDuration = 6.0;
    NSTimeInterval currentAdStart = -1.0;
    NSTimeInterval currentAdDuration = 0.0;
    BOOL isVOD = NO;

    NSLog(@"%@ 🔍 Parsing %ld lines for ad markers...", [NRMTUtilities logPrefix], (long)lines.count);

    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // Check for VOD (playlist type)
        if ([trimmed hasPrefix:@"#EXT-X-PLAYLIST-TYPE:VOD"]) {
            isVOD = YES;
            NSLog(@"%@ 📺 Detected VOD stream", [NRMTUtilities logPrefix]);
        }

        // Check for target duration
        if ([trimmed hasPrefix:@"#EXT-X-TARGETDURATION:"]) {
            NSString *durationStr = [trimmed substringFromIndex:[@"#EXT-X-TARGETDURATION:" length]];
            targetDuration = [durationStr doubleValue];
            NSLog(@"%@ ⏱️ Target duration: %.1fs", [NRMTUtilities logPrefix], targetDuration);
        }

        // Check for ad break start (CUE-OUT with or without DURATION)
        if ([trimmed hasPrefix:@"#EXT-X-CUE-OUT"]) {
            NSLog(@"%@ 🎯 Found CUE-OUT at line: %@", [NRMTUtilities logPrefix], trimmed);

            // Try to extract duration from #EXT-X-CUE-OUT:DURATION=10.0
            NSRange durationRange = [trimmed rangeOfString:@"DURATION="];
            if (durationRange.location != NSNotFound) {
                NSString *durationPart = [trimmed substringFromIndex:durationRange.location + durationRange.length];
                // Remove any trailing commas or other params
                NSRange commaRange = [durationPart rangeOfString:@","];
                if (commaRange.location != NSNotFound) {
                    durationPart = [durationPart substringToIndex:commaRange.location];
                }
                currentAdDuration = [durationPart doubleValue];
                NSLog(@"%@ 📍 Ad break starts at %.2fs with explicit duration %.2fs", [NRMTUtilities logPrefix], currentTime, currentAdDuration);
            } else {
                // No DURATION parameter - will calculate from segments between CUE-OUT and CUE-IN
                currentAdDuration = 0.0;
                NSLog(@"%@ 📍 Ad break starts at %.2fs, duration will be calculated from segments", [NRMTUtilities logPrefix], currentTime);
            }
            currentAdStart = currentTime;
        }

        // Check for ad break end (CUE-IN)
        if ([trimmed hasPrefix:@"#EXT-X-CUE-IN"]) {
            NSLog(@"%@ 🎯 Found CUE-IN at line: %@", [NRMTUtilities logPrefix], trimmed);
            if (currentAdStart >= 0) {
                // Calculate duration if not explicitly provided
                if (currentAdDuration == 0.0) {
                    currentAdDuration = currentTime - currentAdStart;
                    NSLog(@"%@ 📏 Calculated ad duration from segments: %.2fs", [NRMTUtilities logPrefix], currentAdDuration);
                }

                NRMTAdBreak *adBreak = [[NRMTAdBreak alloc] init];
                adBreak.startTime = currentAdStart;
                adBreak.duration = currentAdDuration;
                adBreak.endTime = currentAdStart + currentAdDuration;
                [adBreaks addObject:adBreak];
                NSLog(@"%@ ✅ Ad break created: %.2fs - %.2fs (duration: %.2fs)",
                      [NRMTUtilities logPrefix], adBreak.startTime, adBreak.endTime, adBreak.duration);
                currentAdStart = -1.0;
                currentAdDuration = 0.0;
            } else {
                NSLog(@"%@ ⚠️ Found CUE-IN without corresponding CUE-OUT", [NRMTUtilities logPrefix]);
            }
        }

        // Track segment durations to calculate timeline
        if ([trimmed hasPrefix:@"#EXTINF:"]) {
            NSString *durationStr = [trimmed substringFromIndex:[@"#EXTINF:" length]];
            NSRange commaRange = [durationStr rangeOfString:@","];
            if (commaRange.location != NSNotFound) {
                durationStr = [durationStr substringToIndex:commaRange.location];
            }
            NSTimeInterval segmentDuration = [durationStr doubleValue];
            currentTime += segmentDuration;
        }
    }

    // Handle unclosed ad break (reached end of playlist while in ad)
    if (currentAdStart >= 0) {
        NRMTAdBreak *adBreak = [[NRMTAdBreak alloc] init];
        adBreak.startTime = currentAdStart;
        adBreak.duration = currentAdDuration;
        adBreak.endTime = currentAdStart + currentAdDuration;
        [adBreaks addObject:adBreak];
        NSLog(@"%@ ✅ Unclosed ad break created: %.2fs - %.2fs (duration: %.2fs)",
              [NRMTUtilities logPrefix], adBreak.startTime, adBreak.endTime, adBreak.duration);
    }

    result.adBreaks = [adBreaks copy];
    result.isVOD = isVOD;
    result.targetDuration = targetDuration;

    NSLog(@"%@ 📊 Parsing complete: Found %ld ad break(s), VOD=%@, targetDuration=%.1fs",
          [NRMTUtilities logPrefix], (long)adBreaks.count, isVOD ? @"YES" : @"NO", targetDuration);

    return result;
}

// MARK: - Synchronous Parsing Methods (for backward compatibility)

+ (NSArray<NRMTAdBreak *> *)parseHLSManifestForAds:(NSString *)manifestText {
    if (!manifestText) {
        return @[];
    }

    NSMutableArray<NRMTAdBreak *> *adBreaks = [NSMutableArray array];
    NSArray *lines = [manifestText componentsSeparatedByString:@"\n"];

    NSTimeInterval currentTime = 0.0;
    NSTimeInterval currentAdStart = -1.0;
    NSTimeInterval currentAdDuration = 0.0;

    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // Check for ad break start (CUE-OUT with or without DURATION)
        if ([trimmed hasPrefix:@"#EXT-X-CUE-OUT"]) {
            // Try to extract duration from #EXT-X-CUE-OUT:DURATION=10.0
            NSRange durationRange = [trimmed rangeOfString:@"DURATION="];
            if (durationRange.location != NSNotFound) {
                NSString *durationPart = [trimmed substringFromIndex:durationRange.location + durationRange.length];
                NSRange commaRange = [durationPart rangeOfString:@","];
                if (commaRange.location != NSNotFound) {
                    durationPart = [durationPart substringToIndex:commaRange.location];
                }
                currentAdDuration = [durationPart doubleValue];
            } else {
                // No DURATION parameter - will calculate from segments
                currentAdDuration = 0.0;
            }
            currentAdStart = currentTime;
        }

        // Check for ad break end (CUE-IN)
        if ([trimmed hasPrefix:@"#EXT-X-CUE-IN"]) {
            if (currentAdStart >= 0) {
                // Calculate duration if not explicitly provided
                if (currentAdDuration == 0.0) {
                    currentAdDuration = currentTime - currentAdStart;
                }

                NRMTAdBreak *adBreak = [[NRMTAdBreak alloc] init];
                adBreak.startTime = currentAdStart;
                adBreak.duration = currentAdDuration;
                adBreak.endTime = currentAdStart + currentAdDuration;
                [adBreaks addObject:adBreak];
                currentAdStart = -1.0;
                currentAdDuration = 0.0;
            }
        }

        // Track segment durations
        if ([trimmed hasPrefix:@"#EXTINF:"]) {
            NSString *durationStr = [trimmed substringFromIndex:[@"#EXTINF:" length]];
            NSRange commaRange = [durationStr rangeOfString:@","];
            if (commaRange.location != NSNotFound) {
                durationStr = [durationStr substringToIndex:commaRange.location];
            }
            NSTimeInterval segmentDuration = [durationStr doubleValue];
            currentTime += segmentDuration;
        }
    }

    // Handle unclosed ad break
    if (currentAdStart >= 0) {
        NRMTAdBreak *adBreak = [[NRMTAdBreak alloc] init];
        adBreak.startTime = currentAdStart;
        adBreak.duration = currentAdDuration;
        adBreak.endTime = currentAdStart + currentAdDuration;
        [adBreaks addObject:adBreak];
    }

    return [adBreaks copy];
}

+ (NSTimeInterval)extractTargetDuration:(NSString *)manifestText {
    if (!manifestText) {
        return 0.0;
    }

    NSArray *lines = [manifestText componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmed hasPrefix:@"#EXT-X-TARGETDURATION:"]) {
            NSString *durationStr = [trimmed substringFromIndex:[@"#EXT-X-TARGETDURATION:" length]];
            return [durationStr doubleValue];
        }
    }

    return 0.0;
}

@end
