//
//  Test15.swift
//  Tests
//
//  NRVAVideo.addPlayer: must NOT silently create an NRTrackerAVPlayer for an object that is neither a
//  real AVPlayer nor a real THEOplayer, when the caller also never set an explicit playerType. Before
//  this fix, NRPlayerTypeAVPlayer being 0 (the zero-init default) meant "never set" and "explicitly
//  AVPlayer" were indistinguishable, so detection falling through silently produced an AVPlayer tracker
//  for literally any unrecognized object — a wrapped/custom player would get mis-tracked with no error
//  at all. NRPlayerTypeUnspecified (also 0, but the enum's *first* case, not NRPlayerTypeAVPlayer) fixes
//  this: playerType now reads back Unspecified on its own when never touched, so addPlayer: can tell the
//  difference without any extra tracking property.
//
import Foundation
import NewRelicVideoCore

fileprivate let testName = "Test 15"

class Test15: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback

        if !NRVAVideo.isInitialized() {
            let videoConfig = NRVAVideoConfiguration.builder()
                .withApplicationToken("TEST_TOKEN_FOR_DISPATCH_TEST_ONLY")
                .build()
            _ = NRVAVideo.newBuilder().withConfiguration(videoConfig).build()
        }

        // Neither an AVPlayer nor a THEOplayer — e.g. a client's own wrapper object. Deliberately not
        // setting config.playerType either, to exercise the exact "nobody said what this is" case.
        let unrecognizedPlayer = NSObject()
        let config = NRVAVideoPlayerConfiguration(playerName: "test15-unrecognized", player: unrecognizedPlayer)!
        let trackerId = NRVAVideo.addPlayer(config)

        let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(NSNumber(value: trackerId))
        guard tracker == nil else {
            let className = NSStringFromClass(type(of: tracker!))
            self.callback!(testName + " addPlayer: with an unrecognized player and no explicit playerType should not create a tracker, created \(className) instead", false)
            return
        }

        NRVAVideo.releaseTracker(trackerId)
        self.callback!(testName, true)
    }
}
