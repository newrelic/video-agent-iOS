//
//  Test13.swift
//  Tests
//
//  NRTrackerTHEOplayer — QoE shift-direction math, rendition getter caching, and dropped-frames/shift
//  custom attributes (CDD §6.4), driven with synthetic quality data. A real multi-rendition ABR switch
//  needs a real license + real network, neither available in an automated test — this exercises the
//  exact same code path (handleActiveQualityChanged(width:height:bandwidth:droppedFrames:)) that a real
//  ACTIVE_QUALITY_CHANGED event calls into, just with concrete numbers instead of a live THEOplayer
//  VideoQuality object.
//
import Foundation
import NewRelicVideoCore
@testable import NRTHEOplayerTracker

fileprivate let testName = "Test 13"

class Test13: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker

        // First rendition: nothing cached yet (0x0), so any real resolution counts as "up".
        tracker.handleActiveQualityChanged(width: 640, height: 360, bandwidth: 500_000, droppedFrames: 2)
        if tracker.captured.last != CONTENT_RENDITION_CHANGE {
            self.callback!(testName + " first quality change should send CONTENT_RENDITION_CHANGE", false)
            return
        }
        if tracker.getRenditionWidth().intValue != 640 || tracker.getRenditionHeight().intValue != 360 {
            self.callback!(testName + " getRenditionWidth/Height should reflect the cached quality", false)
            return
        }
        if tracker.getBitrate().intValue != 500_000 || tracker.getRenditionBitrate().intValue != 500_000 {
            self.callback!(testName + " getBitrate/getRenditionBitrate should reflect the cached bandwidth", false)
            return
        }

        // Step up to a higher rendition — shift should be "up".
        tracker.handleActiveQualityChanged(width: 1280, height: 720, bandwidth: 1_500_000, droppedFrames: 5)
        if tracker.lastShift != "up" {
            self.callback!(testName + " stepping up in resolution should report shift=up", false)
            return
        }
        if tracker.getRenditionWidth().intValue != 1280 || tracker.getRenditionHeight().intValue != 720 {
            self.callback!(testName + " getRenditionWidth/Height should update to the new quality", false)
            return
        }

        // Step down to a lower rendition — shift should be "down".
        tracker.handleActiveQualityChanged(width: 640, height: 360, bandwidth: 500_000, droppedFrames: 5)
        if tracker.lastShift != "down" {
            self.callback!(testName + " stepping down in resolution should report shift=down", false)
            return
        }

        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        self.callback!(testName, true)
    }

    class TestContentTracker: NRTrackerTHEOplayer {
        var captured: [String] = []
        var lastShift: String?

        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            captured.append(action)
            if let shift = attributes["shift"] as? String {
                lastShift = shift
            }
            return false
        }
    }
}
