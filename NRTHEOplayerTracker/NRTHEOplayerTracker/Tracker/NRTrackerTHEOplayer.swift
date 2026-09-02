//
//  NRTrackerTHEOplayer.swift
//  NRTHEOplayerTracker
//
//  Content tracker for THEOplayer (Dolby OptiView Player).
//
//  Written in Swift because THEOplayer's iOS event API (PlayerEventTypes, addEventListener) is built on
//  Swift generics, which cannot bridge to Objective-C under any circumstance — confirmed against the
//  real generated THEOplayerSDK-Swift.h. `@objc(NRTrackerTHEOplayer)` pins this class's Objective-C
//  runtime name so NRVAVideo.m's existing NSClassFromString(@"NRTrackerTHEOplayer") dispatch finds it
//  without any change to that dispatch code — verified end-to-end with a spike before this was written.
//
//  Skeleton only — registerListeners()/unregisterListeners() intentionally do nothing beyond the base
//  class yet. Lifecycle/error/QoE/attribute handling lands in a follow-up PR; this establishes the
//  dispatch plumbing (pod scaffold, NSClassFromString lookup, player-type auto-detection) on its own.
//
import Foundation
import NewRelicVideoCore
import THEOplayerSDK

// Not `final` — the test convention this repo already uses (Test1-7.swift's TestContentTracker
// pattern) subclasses the tracker under test to intercept preSendAction:attributes: as a spy.
@objc(NRTrackerTHEOplayer)
public class NRTrackerTHEOplayer: NRVideoTracker {

    // Weak, matching NRTrackerAVPlayer's own playerInstance — the host app owns the player, the tracker
    // only observes it. A strong reference here would keep the entire THEOplayer instance (and its
    // internal view hierarchy) alive for as long as this tracker stays registered, if a host app ever
    // dropped its own player reference without also calling dispose()/releaseTracker.
    weak var player: THEOplayer?

    // Defensive, matching NRTrackerAVPlayer's own dealloc: tears down listeners even if the host app
    // released the tracker without calling dispose().
    deinit {
        unregisterListeners()
    }

    public override func setPlayer(_ player: Any) {
        super.setPlayer(player)
        self.player = player as? THEOplayer
        registerListeners()
    }

    public override func registerListeners() {
        super.registerListeners()
        // Event wiring lands in a follow-up PR.
    }

    public override func unregisterListeners() {
        super.unregisterListeners()
    }
}
