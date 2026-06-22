# Contributing to NRMediaTailorTracker

This module is a passive observer of AWS MediaTailor ads in an `AVPlayer` stream. Its scope is narrow on purpose. Before adding or changing functionality, read this document, the [`README.md`](README.md), and the [feature spec](../NRMediaTailorTracker_FEATURE_SPEC.md).

## Scope boundaries (the 10 anti-patterns)

These are non-goals. Each is anchored to the atomic-fact section that established the rule, and to `NRMediaTailorTracker_FEATURE_SPEC.md` §5. If a new feature feels close to any of these lines, **message `team-lead` before writing code**.

1. **Do not fire VAST tracking beacons.** Server-side mode = MediaTailor fires them. Client-side mode = customer's player fires them. We observe; we do not transmit ad-server beacons. *(Atomic facts §8 — SDK boundary.)*
2. **Do not resolve VAST wrappers.** MediaTailor returns final ad metadata. *(Atomic facts §1, §8.)*
3. **Do not implement ad personalization or targeting.** *(Atomic facts §8 — ad-decisioning is upstream of the tracker.)*
4. **Do not cache ads across sessions.** *(Atomic facts §3 — each MediaTailor session is independent; `nextToken` is the only intra-session continuity primitive.)*
5. **Do not modify manifest query parameters.** *(Atomic facts §3, §8 — manifest URL is owned by the app/player.)*
6. **Do not implement avail suppression (`BEHIND_LIVE_EDGE` etc.) logic.** *(Atomic facts §8 — suppression is a player concern.)*
7. **Do not render ad UI, pause the player, or call back into customer business logic.** *(Atomic facts §8 — tracker is passive; no callbacks into app code beyond event emission.)*
8. **Do not assume every avail has ads** (empty = no-fill, handle explicitly). *(Atomic facts §6 "Ad-server failure" — empty avails are a normal outcome, not an error condition.)*
9. **Do not pre-fire impression beacons before confirming the ad played.** *(Atomic facts §6, §9 — impressions must be playback-confirmed.)*
10. **Do not perform OMID / viewability handoff.** That's an app-layer concern. *(Atomic facts §8 — viewability (Moat, DoubleVerify, IAS) is an ad-renderer + app concern, not a tracker concern.)*

## Coding conventions

- **Language: Objective-C** (`.m` + `.h`). All sibling trackers in this repo are Obj-C; we match. **No Swift in new code without explicit team-lead approval.**
- **Deployment targets:** iOS 12.0 and tvOS 12.0. Both ship in v1. Guard UIKit-only symbols with `#if TARGET_OS_IOS`.
- **Style:** mirror `NRAVPlayerTracker` — file layout, naming (`NR` prefix), header organization, and `NS_ASSUME_NONNULL_BEGIN/END` placement.
- **Concurrency:** GCD only. Tracker state lives on the main queue. Fetches run on a dedicated background `dispatch_queue_t`; results bounce back to main via `dispatch_async`. No Swift `async/await`, no actors.
- **Public types:** prefix with `NR` (e.g., `NRTrackerMediaTailor`). Internal types prefix with `MT` (e.g., `MTAvail`, `MTAdPod`).
- **Headerdoc:** public headers use `/** */` doc comments for the T14 docs build. Implementation files use plain `//` comments; this file and the source guardrails block use `//` so we don't generate DocC pages for them.

## Adding new functionality

Before writing code:

1. Verify the change does not violate any of the 10 anti-patterns above.
2. If unsure, message `team-lead` with a description of the change and the closest anti-pattern.
3. Confirm the change has a task in the project task list. If it doesn't, ask `team-lead` to add one.

When writing code:

1. Match Obj-C conventions from `NRAVPlayerTracker`.
2. Keep tracker state on the main queue. Confine fetches and parsing to background queues; bounce results back to main before mutating state.
3. Cite atomic-fact sections in comments for any non-obvious behavior — especially anywhere we deviate from Android.
4. Update the README and CONTRIBUTING if you add a new event, attribute, or public API method.

## Testing

- **Framework:** `XCTest`. Fixture-based unit tests live alongside the module.
- **Coverage target:** ≥70% line coverage. Tracked via task T12.
- Unit tests must cover:
  - Manifest parsers (HLS fixtures; DASH fixtures land with the DASH parser follow-up)
  - Schedule merger (mismatch, empty-avail, live-rollover, missing-start)
  - State machine (golden path, seek, pause, dispose)
- Integration tests against a real MediaTailor stream run on a CI schedule, not per-PR. See task T13.

## References

- [`README.md`](README.md) — one-pager
- [`NRMediaTailorTracker_FEATURE_SPEC.md`](../NRMediaTailorTracker_FEATURE_SPEC.md) — spec
- [`NRMediaTailorTracker_BUGS_TO_FIX.md`](../NRMediaTailorTracker_BUGS_TO_FIX.md) — bug list vs Android
