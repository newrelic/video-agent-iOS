//
//  MTDashParser.h
//  NRMediaTailorTracker
//
//  Stub DASH parser. Conforms to `MTManifestParser` so the tracker wiring
//  compiles, but the parser itself is intentionally NOT implemented in v1.
//  Per locked decision (FEATURE_SPEC §8 "DASH scope: HLS only for the first
//  release"). A real implementation ships as a fast-follow.
//
//  `parseManifest:baseURL:` returns an empty `MTManifestParseResult` and
//  emits an `NSLog` warning so a misconfigured customer sees the issue
//  immediately in their device logs.
//

#import <Foundation/Foundation.h>
#import "MTManifestParser.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTDashParser : NSObject <MTManifestParser>

@end

NS_ASSUME_NONNULL_END
