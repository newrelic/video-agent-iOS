//
//  MediaTailorSamples.h
//  SimplePlayerWithAds
//
//  Resolves the MediaTailor session URL used by the
//  `clickMediaTailorSample:` button in `ViewController.m`. The URL is
//  read in this order so the smoke-test operator can override it
//  without editing source:
//
//    1. NSUserDefaults key `MediaTailorSampleURL` (set via
//       `defaults write com.newrelic.SimplePlayerWithAds
//        MediaTailorSampleURL "https://your.mediatailor.session.url"`).
//    2. The `MT_SAMPLE_URL` process-environment variable (useful for
//       CI runs that inject env via `xcrun simctl spawn launchctl
//       setenv`).
//    3. A placeholder `REPLACE_ME` AWS URL. The host MUST be replaced
//       with a real MediaTailor session URL before running the smoke
//       test, otherwise the tracker's detector will no-op.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaTailorSamples : NSObject

/// Resolved MediaTailor session URL. Never nil. See file header for the
/// lookup order.
+ (NSString *)defaultSampleURLString;

/// The NSUserDefaults key consulted by the override path above. Exposed
/// so tests or developers can clear/set it programmatically.
+ (NSString *)defaultsKey;

@end

NS_ASSUME_NONNULL_END
