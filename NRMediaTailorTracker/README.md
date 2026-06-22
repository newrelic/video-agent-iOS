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

```objc
#import <NRMediaTailorTracker/NRMediaTailorTracker.h>

AVPlayer *player = [[AVPlayer alloc] initWithURL:streamURL];
NRTrackerMediaTailor *tracker = [[NRTrackerMediaTailor alloc] initWithPlayer:player];
[NewRelicVideoAgent.sharedInstance startWithContentTracker:contentTracker adTracker:tracker];
[player play];
```

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

- **HLS only** in the first release. A DASH adapter protocol ships as a seam; the DASH parser is a follow-up module.
- **HTTP GET** is used for `/v1/tracking` for Android parity, even though the documented MediaTailor contract is POST. This deviation is intentional and called out in the tracking client source.
- **No VAST beacon firing.** Beacon URLs from the tracking JSON are surfaced as event attributes only.
- **No OMID / viewability.** `adVerifications` metadata is surfaced as event attributes only; the tracker does not initialize OMID sessions or manage ad views.

## Platform support

- iOS 12.0+
- tvOS 12.0+

Both platforms ship in v1. AVPlayer API is shared, so the bulk of the module is platform-agnostic; any UIKit-only call is `#if TARGET_OS_IOS` guarded.

## References

- [`NRMediaTailorTracker_FEATURE_SPEC.md`](../NRMediaTailorTracker_FEATURE_SPEC.md) — full spec, parity surface, locked decisions
- [`NRMediaTailorTracker_BUGS_TO_FIX.md`](../NRMediaTailorTracker_BUGS_TO_FIX.md) — 15 actionable bugs vs Android reference
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — scope boundaries and coding conventions for new work
