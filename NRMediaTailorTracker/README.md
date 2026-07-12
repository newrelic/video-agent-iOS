# NRMediaTailorTracker

## What this is

`NRMediaTailorTracker` is a passive observer that detects AWS MediaTailor server-side-stitched ads inside an `AVPlayer` stream and emits New Relic ad telemetry events. It mirrors the role and event surface of `NRTrackerIMA`: attach to a player, hear about ads, emit events. No UI, no decisioning, no beacon firing.

## What this is NOT

These ten anti-patterns are non-goals. They are guardrails to keep future contributors from drifting into app-level or ad-renderer scope. Source: `NRMediaTailorTracker_FEATURE_SPEC.md` §5 (atomic facts §8).

1. **Do not fire VAST tracking beacons.** Server-side mode = MediaTailor fires them. Client-side mode = customer's player fires them. We observe; we do not transmit ad-server beacons.
2. **Do not resolve VAST wrappers.** MediaTailor returns final ad metadata.
3. **Do not implement ad personalization or targeting.**
4. **Do not cache ads across sessions.**
5. **Do not modify manifest query parameters.**
6. **Do not implement avail suppression (`BEHIND_LIVE_EDGE` etc.) logic.**
7. **Do not render ad UI, pause the player, or call back into customer business logic.**
8. **Do not assume every avail has ads** (empty = no-fill, handle explicitly).
9. **Do not pre-fire impression beacons before confirming the ad played.**
10. **Do not perform OMID / viewability handoff.** That's an app-layer concern.

## Integration

**Recommended — config-based (parity with IMA, mirrors Android `NRAdConfig`):**

```objc
#import <NewRelicVideoCore/NewRelicVideoCore.h>

// The agent creates + attaches an NRTrackerMediaTailor for you. Use
// NRAdConfig.mediaTailor() (or +mediaTailorWithSegmentPrefix:trackingUrl:
// for custom CDNs). Pass nil adConfig to disable ads; NRAdConfig.csai() = IMA.
AVPlayer *player = [[AVPlayer alloc] initWithURL:streamURL];
NRVAVideoPlayerConfiguration *cfg = [[NRVAVideoPlayerConfiguration alloc]
    initWithPlayerName:@"MyPlayer"
                player:player
              adConfig:[NRAdConfig mediaTailor]
      customAttributes:nil];
NSInteger trackerId = [NRVAVideo addPlayer:cfg];

// Grab the auto-created tracker to feed the merged schedule (below).
NRTrackerMediaTailor *tracker =
    (NRTrackerMediaTailor *)[[NewRelicVideoAgent sharedInstance] adTracker:@(trackerId)];
```

**Alternative — explicit wiring:**

```objc
#import <NRMediaTailorTracker/NRMediaTailorTracker.h>

// 1. Create the tracker, attach your AVPlayer, and register it with the
//    NewRelicVideoAgent the same way you register an IMA tracker.
AVPlayer *player = [[AVPlayer alloc] initWithURL:streamURL];
NRTrackerMediaTailor *tracker = [[NRTrackerMediaTailor alloc] init];

// Optional config (all have sensible defaults — set only if you need them):
tracker.adSegmentPrefix = @"/mycdn/ads/"; // custom-CDN ad-segment marker; default AWS paths (/tm/, /v1/hlssegment/, …) work out of the box
tracker.trackingUrl     = @"https://host/v1/tracking/<sessionId>"; // override when the /v1/master → /v1/tracking derivation can't be inferred from the manifest URL
tracker.pollIntervalMs  = 250; // playhead poll cadence; default 250 ms, clamped to 100…5000

[tracker setPlayer:player];
[NewRelicVideoAgent.sharedInstance startWithContentTracker:contentTracker adTracker:tracker];

// 2. After your app obtains the MediaTailor manifest + tracking JSON
//    (via your existing player or networking layer), feed the merged
//    schedule into the tracker. The tracker installs a playhead state
//    machine on the player and starts emitting AD_* events.
MTManifestParseResult *parsed = [tracker.manifestParser parseManifest:manifestData
                                                              baseURL:manifestURL];
MTTrackingResponse *tracking = ...; // from MTTrackingClient
MergedSchedule *schedule = [MTAdScheduleMerger mergeManifestBreaks:parsed.breaks
                                                  trackingResponse:tracking];
[tracker startTrackingWithSchedule:schedule];
[player play];

// 3. When tearing down the playback session:
[tracker dispose];
```

`MTTrackingClient` (in the same module) handles the `/v1/tracking/<sessionId>` HTTP polling with proper `NextToken` round-trip; see its header for the convenience initializer and `-fetchWithTrackingURL:completion:`.

## Events emitted

The tracker emits the standard New Relic ad event vocabulary, plus `AD_ERROR`. See `NRMediaTailorTracker_FEATURE_SPEC.md` §2 "Event Emission" for the full set and attribute reference.

- `AD_BREAK_START` / `AD_BREAK_END`
- `AD_REQUEST`
- `AD_START` / `AD_END`
- `AD_QUARTILE` (1, 2, 3)
- `AD_SKIP`
- `AD_PAUSE` / `AD_RESUME`
- `AD_SEEK_START` / `AD_SEEK_END`
- `AD_BUFFER_START` / `AD_BUFFER_END`
- `AD_ERROR` (with `errorCode` ∈ `ADS_TIMEOUT`, `TRACKING_FETCH_FAILED`, `TOKEN_EXPIRED`, `NO_FILL`, `MISSING_AVAIL_START`, `MANIFEST_PARSE_FAILED`, `MANIFEST_TRACKING_MISMATCH`)

## Known limitations

- **HTTP GET** is used for `/v1/tracking` for Android parity, even though the documented MediaTailor contract is POST. This deviation is intentional and called out in the tracking client source.
- **No VAST beacon firing.** Beacon URLs from the tracking JSON are surfaced as event attributes only.
- **No OMID / viewability.** `adVerifications` metadata is surfaced as event attributes only; the tracker does not initialize OMID sessions or manage ad views.

## Platform support

- iOS 12.0+
- tvOS 12.0+

Both platforms ship in v1. AVPlayer API is shared, so the bulk of the module is platform-agnostic; any UIKit-only call is `#if TARGET_OS_IOS` guarded.

## DASH adapter seam

V1 ships both an HLS parser (`MTHlsParser`) and a DASH parser (`MTDashParser`) out of the box. Both conform to the `MTManifestParser` Obj-C protocol, which exposes one method: `- (MTManifestParseResult *)parseManifest:(NSData *)manifest baseURL:(NSURL *)baseURL;`. `MTDashParser` handles the canonical AWS MediaTailor DASH cases — multi-period VOD, dynamic live with SCTE-35 `EventStream` markers, `<Location>`-anchored tracking-URL recovery — and applies the Bug A7 fix that the Android module never shipped: a `<Period>` is classified as ad only when **every** `<Representation>` (across every `<AdaptationSet>`) resolves to an ad-segment-marker URL. Mixed-classification periods are dropped (classified as content) and counted on `-[MTDashParser mixedPeriodCount]` for runtime telemetry. Customers using third-party DASH players (THEOplayer, Bitmovin, Shaka) with non-standard CDN layouts can still inject their own parser via `-[NRTrackerMediaTailor setManifestParser:]`.

## Verification

Contributor testing goes through the example app, which resolves `NewRelicVideoCore` and the sibling trackers via CocoaPods:

```bash
cd Examples/iOS/SimplePlayerWithAds && pod install && open SimplePlayerWithAds.xcworkspace
```

Run the `NRMediaTailorTrackerTests` scheme from the workspace. Latest local run: **132 tests passing, 89.92% line coverage** on `NRMediaTailorTracker.framework`.

### End-to-end smoke test

See `Examples/iOS/SimplePlayerUsingPods/`. Replace `MediaTailorSamples.defaultSampleURLString` with your AWS account's MediaTailor session URL, wire the IBAction `clickMediaTailorSample:` to a button, run the app, and:

1. Capture a proxy log (Charles / mitmproxy) — confirm `/v1/tracking/<sessionId>` requests round-trip `nextToken` between consecutive calls.
2. Confirm in NRDB that `AD_BREAK_START` → `AD_START` → 3× `AD_QUARTILE` → `AD_END` → `AD_BREAK_END` fires for at least one ad break.
3. Optional: run the Android module side-by-side on the same stream — event sequences should match (minus the bugs we fixed; see [`NRMediaTailorTracker_BUGS_TO_FIX.md`](../NRMediaTailorTracker_BUGS_TO_FIX.md)).

## References

- [`NRMediaTailorTracker_FEATURE_SPEC.md`](../NRMediaTailorTracker_FEATURE_SPEC.md) — full spec, parity surface, locked decisions
- [`NRMediaTailorTracker_BUGS_TO_FIX.md`](../NRMediaTailorTracker_BUGS_TO_FIX.md) — 15 actionable bugs vs Android reference
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — scope boundaries and coding conventions for new work
