//
//  Test10.swift
//  Tests
//
//  NRTrackerTHEOplayer — nil-safety with no player attached, and safe attribute defaults (CDD §8).
//  A tracker that never had setPlayer: called (e.g. constructed but not yet wired up) must not crash
//  and must report sane defaults rather than propagating a force-unwrap failure.
//
import Foundation
import NewRelicVideoCore
@testable import NRTHEOplayerTracker

fileprivate let testName = "Test 10"

class Test10: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker

        // No player attached at all — every handler below must no-op safely, not crash.
        tracker.handleActiveQualityChanged()
        if tracker.captured.contains(CONTENT_RENDITION_CHANGE) {
            self.callback!(testName + " handleActiveQualityChanged with no player should not send", false)
            return
        }

        tracker.handleRateChange()
        // No crash is the assertion here; there's no send to check since it's a custom attribute.

        if tracker.getPlayerName() != "theoplayer" {
            self.callback!(testName + " getPlayerName default", false)
            return
        }
        if !tracker.getPlayerVersion().isEmpty {
            // THEOplayer.version is a static string from the SDK itself, unrelated to player attachment —
            // just confirm it's non-crashing and non-garbage (a real dotted version string).
            if !tracker.getPlayerVersion().contains(".") {
                self.callback!(testName + " getPlayerVersion looks malformed", false)
                return
            }
        }
        if tracker.nrGetSrc() != "" {
            self.callback!(testName + " nrGetSrc default with no player", false)
            return
        }
        if tracker.getDuration() != 0 {
            self.callback!(testName + " getDuration default with no player", false)
            return
        }
        if tracker.getIsLive().boolValue != false {
            self.callback!(testName + " getIsLive default with no player", false)
            return
        }
        if tracker.getIsMuted().boolValue != false {
            self.callback!(testName + " getIsMuted default with no player", false)
            return
        }
        if tracker.getTitle() != "" {
            self.callback!(testName + " getTitle default with no player", false)
            return
        }

        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        self.callback!(testName, true)
    }

    class TestContentTracker: NRTrackerTHEOplayer {
        var captured: [String] = []

        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            captured.append(action)
            return false
        }
    }
}
