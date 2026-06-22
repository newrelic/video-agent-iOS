//
//  NRTrackerMediaTailor.swift
//  NRMediaTailorTracker
//
//  New Relic Video Agent — AWS MediaTailor ad tracker for AVPlayer.
//  Subclasses NRVideoTracker (NewRelicVideoCore). Mirrors NRTrackerIMA's role:
//  passive observer that detects MediaTailor ads inside an AVPlayer stream and
//  emits AD_BREAK_START / AD_START / AD_QUARTILE / AD_END / AD_BREAK_END / AD_ERROR.
//
//  ---------------------------------------------------------------------------
//  SDK-Boundary Anti-Pattern Guardrails (do NOT do these)
//  Source: NRMediaTailorTracker_FEATURE_SPEC.md §5
//  ---------------------------------------------------------------------------
//  1. Do NOT fire VAST tracking beacons. Server-side mode = MediaTailor fires
//     them. Client-side mode = customer's player fires them. We observe; we do
//     not transmit ad-server beacons.
//  2. Do NOT resolve VAST wrappers. MediaTailor returns final ad metadata.
//  3. Do NOT implement ad personalization or targeting.
//  4. Do NOT cache ads across sessions.
//  5. Do NOT modify manifest query parameters.
//  6. Do NOT implement avail suppression (`BEHIND_LIVE_EDGE` etc.) logic.
//  7. Do NOT render ad UI, pause the player, or call back into customer
//     business logic.
//  8. Do NOT assume every avail has ads (empty = no-fill, handle explicitly).
//  9. Do NOT pre-fire impression beacons before confirming the ad played.
//  10. Do NOT perform OMID / viewability handoff. That's an app-layer concern.
//  ---------------------------------------------------------------------------
//

import Foundation
import AVFoundation
import NewRelicVideoCore

/// `NRTrackerMediaTailor` detects AWS MediaTailor server-side-stitched ads inside an
/// `AVPlayer` stream and emits New Relic ad telemetry events, in parity with
/// `NRTrackerIMA`.
///
/// This is the public entry point of the `NRMediaTailorTracker` module. The full
/// tracker logic lands in tasks T02–T09; this scaffold compiles as a stub.
@objc(NRTrackerMediaTailor)
@objcMembers
public class NRTrackerMediaTailor: NRVideoTracker {

    public override init() {
        super.init()
    }
}
