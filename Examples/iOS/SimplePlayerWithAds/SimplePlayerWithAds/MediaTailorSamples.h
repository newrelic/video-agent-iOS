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

/// One named, ready-to-play MediaTailor sample URL, offered to the user by
/// `clickMediaTailorSample:` as an action-sheet choice — picking the flow to
/// exercise is a tap, not a scheme-environment-variable edit.
@interface MediaTailorSampleOption : NSObject

@property (nonatomic, copy, readonly) NSString *label;
@property (nonatomic, copy, readonly) NSString *urlString;

/// Passed to `NRAdConfig mediaTailorWithSegmentPrefix:trackingUrl:` when
/// non-nil — for a CDN that rewrites ad-segment URLs to a custom path
/// instead of AWS's own conventions. Nil for the standard AWS-path samples.
@property (nonatomic, copy, readonly, nullable) NSString *adSegmentPrefix;

/// Passed to `NRAdConfig mediaTailorWithSegmentPrefix:trackingUrl:` when
/// non-nil — for a deployment where the tracking-API URL can't be derived
/// from the manifest URL by the default heuristic. Nil to derive as usual.
@property (nonatomic, copy, readonly, nullable) NSString *trackingUrl;

- (instancetype)initWithLabel:(NSString *)label urlString:(NSString *)urlString;
- (instancetype)initWithLabel:(NSString *)label
                     urlString:(NSString *)urlString
               adSegmentPrefix:(nullable NSString *)adSegmentPrefix
                   trackingUrl:(nullable NSString *)trackingUrl NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface MediaTailorSamples : NSObject

/// Resolved MediaTailor session URL. Never nil. See file header for the
/// lookup order.
+ (NSString *)defaultSampleURLString;

/// The NSUserDefaults key consulted by the override path above. Exposed
/// so tests or developers can clear/set it programmatically.
+ (NSString *)defaultsKey;

/// Named MediaTailor URLs covering the shapes that actually occur in real
/// deployments — the bare direct/implicit entry URL, the explicit
/// session-init URL (POST-only; the tracker never does this, the sample app
/// itself resolves it — see `ViewController.m`'s `resolveMediaTailorSessionURL:`),
/// the raw non-CDN endpoint for comparison, and a custom-domain entry whose
/// URL/ad-segment-prefix/tracking-URL are read from the NSUserDefaults/env
/// overrides below (so a real custom-CDN deployment can be exercised without
/// editing source). Presented to the user as an action sheet by
/// `clickMediaTailorSample:` so no environment-variable or NSUserDefaults
/// setup is needed to switch between them.
+ (NSArray<MediaTailorSampleOption *> *)sampleOptions;

/// NSUserDefaults key for the custom-domain sample's URL. Falls back to the
/// `MT_CUSTOM_DOMAIN_URL` environment variable, then a placeholder.
+ (NSString *)customDomainURLDefaultsKey;

/// NSUserDefaults key for the custom-domain sample's ad-segment-prefix
/// override. Falls back to the `MT_CUSTOM_SEGMENT_PREFIX` environment
/// variable, then a placeholder. See `NRTrackerMediaTailor.adSegmentPrefix`.
+ (NSString *)customSegmentPrefixDefaultsKey;

/// NSUserDefaults key for the custom-domain sample's tracking-URL override.
/// Falls back to the `MT_CUSTOM_TRACKING_URL` environment variable; empty
/// means "derive as usual". See `NRTrackerMediaTailor.trackingUrl`.
+ (NSString *)customTrackingURLDefaultsKey;

@end

NS_ASSUME_NONNULL_END
