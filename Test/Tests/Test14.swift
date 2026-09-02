//
//  Test14.swift
//  Tests
//
//  NRVAVideo.addPlayer: auto-detects a real THEOplayer instance's player type by class, without the
//  caller setting NRVAVideoPlayerConfiguration.playerType at all — the exact "client forgot to set
//  playerType and it still works" scenario the detection was added for. No existing test exercised
//  addPlayer:'s dispatch path with a real player instance at all; Test11/Test12 call
//  tracker.setPlayer(player) directly on a manually-constructed tracker, bypassing addPlayer: entirely.
//
import Foundation
import NewRelicVideoCore
import THEOplayerSDK
@testable import NRTHEOplayerTracker

fileprivate let testName = "Test 14"

class Test14: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback

        // NRVAVideo is a dispatch_once-guarded singleton — this test is the only thing in this suite
        // that uses it, so first-call-wins is safe here. The token's contents don't matter: addPlayer:'s
        // dispatch logic never reads it, only NRVAVideoConfiguration's non-empty check does.
        if !NRVAVideo.isInitialized() {
            let videoConfig = NRVAVideoConfiguration.builder()
                .withApplicationToken("TEST_TOKEN_FOR_DISPATCH_TEST_ONLY")
                .build()
            _ = NRVAVideo.newBuilder().withConfiguration(videoConfig).build()
        }

        // THEOplayer's initializer touches UIKit internally and asserts it's running on the main thread —
        // same fix as Test11/Test12.
        var trackerId = 0
        DispatchQueue.main.sync {
            let player = THEOplayer()
            let config = NRVAVideoPlayerConfiguration(playerName: "test14-theoplayer", player: player)!
            // Deliberately not setting config.playerType — proving addPlayer: identifies THEOplayer by
            // class on its own.
            trackerId = NRVAVideo.addPlayer(config)
        }

        let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(NSNumber(value: trackerId))
        guard let tracker else {
            self.callback!(testName + " addPlayer: should have created a content tracker", false)
            return
        }
        let className = NSStringFromClass(type(of: tracker))
        guard className == "NRTrackerTHEOplayer" else {
            self.callback!(testName + " addPlayer: with a real THEOplayer and no explicit playerType created \(className), expected NRTrackerTHEOplayer", false)
            return
        }

        DispatchQueue.main.sync {
            (tracker as? NRTrackerTHEOplayer)?.player = nil
        }
        NRVAVideo.releaseTracker(trackerId)
        self.callback!(testName, true)
    }
}
