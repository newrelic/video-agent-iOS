//
//  Test17.swift
//  Tests
//
//  NRVAVideo.releaseTracker(_:) — tracker ID 0 must actually release, not silently no-op.
//
//  NewRelicVideoAgent.trackerIdIndex is 0-indexed and process-lifetime, so the very first tracker
//  created in the process — literally the most common real-world case, "the first video someone
//  watches after opening the app" — gets ID 0. NRVAVideo.releaseTracker: used to guard with
//  `trackerId <= 0`, treating that legitimate first ID the same as a genuinely invalid negative one:
//  it returned before ever calling into NewRelicVideoAgent, so the tracker's heartbeat timer (which
//  retains the tracker itself via NSTimer's target-retain semantics) was never invalidated and kept
//  firing forever — confirmed empirically via a real running app: CONTENT_HEARTBEAT kept landing in
//  NRDB for 90+ seconds after releaseTracker(0), with no crash and no error surfaced.
//
//  This MUST run as the only test in the process (isolated) to actually exercise ID 0 — running
//  alongside other tests that construct their own trackers first (as CoreTests' full array does)
//  would consume tracker ID 0 before this test ever runs, silently testing a non-zero ID instead and
//  missing the exact bug this guards against.
//
import Foundation
import NewRelicVideoCore
import THEOplayerSDK
@testable import NRTHEOplayerTracker

fileprivate let testName = "Test 17"

class Test17: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback

        if !NRVAVideo.isInitialized() {
            let videoConfig = NRVAVideoConfiguration.builder()
                .withApplicationToken("TEST_TOKEN_FOR_DISPATCH_TEST_ONLY")
                .build()
            _ = NRVAVideo.newBuilder().withConfiguration(videoConfig).build()
        }

        var trackerId = -1
        DispatchQueue.main.sync {
            let player = THEOplayer()
            let config = NRVAVideoPlayerConfiguration(playerName: "test17-release-zero", player: player)!
            trackerId = NRVAVideo.addPlayer(config)
        }

        guard trackerId == 0 else {
            self.callback!(testName + " requires isolation (must be the only test running) to actually exercise tracker ID 0 — got \(trackerId) instead", false)
            return
        }

        NRVAVideo.releaseTracker(trackerId)

        if NewRelicVideoAgent.sharedInstance().contentTracker(NSNumber(value: trackerId)) != nil {
            self.callback!(testName + " releaseTracker(0) should actually release the tracker, not silently no-op", false)
            return
        }

        self.callback!(testName, true)
    }
}
