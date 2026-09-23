//
//  Test8.swift
//  Tests
//
//  NRTrackerTHEOplayer — playback lifecycle event -> send*() mapping, and SOURCE_CHANGE mid-playback
//  ordering (CDD §8). Drives the handler methods directly rather than through a real THEOplayer
//  instance — they don't need one for these events, and this is exactly why they were split out as
//  directly-callable methods in the first place.
//
import Foundation
import NewRelicVideoCore
@testable import NRTHEOplayerTracker

fileprivate let testName = "Test 8"

class Test8: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker

        // start(withContentTracker:) already fired TRACKER_READY before doTest() runs, so captured
        // isn't empty at this point — check the last action, not exact array equality.
        tracker.handleSourceChange()
        if tracker.captured.last != CONTENT_REQUEST {
            self.callback!(testName + " SOURCE_CHANGE -> sendRequest", false)
            return
        }

        tracker.handlePlaying()
        if tracker.captured.last != CONTENT_START {
            self.callback!(testName + " PLAYING -> sendStart", false)
            return
        }

        tracker.handlePause()
        if tracker.captured.last != CONTENT_PAUSE {
            self.callback!(testName + " PAUSE -> sendPause", false)
            return
        }

        tracker.handlePlay()
        if tracker.captured.last != CONTENT_RESUME {
            self.callback!(testName + " PLAY after pause -> sendResume", false)
            return
        }

        tracker.handleSeeking()
        if tracker.captured.last != CONTENT_SEEK_START {
            self.callback!(testName + " SEEKING -> sendSeekStart", false)
            return
        }

        tracker.handleSeeked()
        if tracker.captured.last != CONTENT_SEEK_END {
            self.callback!(testName + " SEEKED -> sendSeekEnd", false)
            return
        }

        // Mid-playback SOURCE_CHANGE: must close the prior session (CONTENT_END) before opening the
        // next (CONTENT_REQUEST) — CDD §6.3.
        let countBefore = tracker.captured.count
        tracker.handleSourceChange()
        let newActions = tracker.captured.suffix(from: countBefore)
        guard let endIndex = newActions.firstIndex(of: CONTENT_END),
              let requestIndex = newActions.lastIndex(of: CONTENT_REQUEST),
              endIndex < requestIndex else {
            self.callback!(testName + " SOURCE_CHANGE mid-playback ordering", false)
            return
        }

        tracker.handleEnded()
        if tracker.captured.last != CONTENT_END {
            self.callback!(testName + " ENDED -> sendEnd", false)
            return
        }

        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        self.callback!(testName, true)
    }

    class TestContentTracker: NRTrackerTHEOplayer {
        var captured: [String] = []

        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            captured.append(action)
            return false // suppress real sending — this test only cares which actions fired, and in what order
        }
    }
}
