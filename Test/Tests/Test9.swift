//
//  Test9.swift
//  Tests
//
//  NRTrackerTHEOplayer — WAITING-during-seek guard (CDD §8, §6.3). THEOplayer fires WAITING for both
//  real rebuffers and seeks; only a real rebuffer should start a buffer event.
//
import Foundation
import NewRelicVideoCore
@testable import NRTHEOplayerTracker

fileprivate let testName = "Test 9"

class Test9: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker

        // goBufferStart (NRTrackerState.m) requires isRequested — a session must be open first.
        tracker.handleSourceChange()

        // WAITING while seeking must NOT start a buffer event.
        tracker.handleWaiting(isSeeking: true)
        if tracker.captured.contains(CONTENT_BUFFER_START) {
            self.callback!(testName + " WAITING during seek incorrectly started buffering", false)
            return
        }

        // WAITING while not seeking (a real rebuffer) must start a buffer event.
        tracker.handleWaiting(isSeeking: false)
        if tracker.captured.last != CONTENT_BUFFER_START {
            self.callback!(testName + " WAITING while not seeking should start buffering", false)
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
