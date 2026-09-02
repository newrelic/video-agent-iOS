//
//  Test12.swift
//  Tests
//
//  NRTrackerTHEOplayer — real ERROR wiring test. Test/iOS/CoreTests deliberately has no
//  THEOplayerLicense configured in its Info.plist (unlike Examples/iOS/SimpleTheoplayerTest), so
//  constructing a real THEOplayer here reliably fires a real license/configuration ERROR shortly after
//  init — a deterministic, reproducible way to drive a genuine THEOError through
//  registerListeners() -> handleError() -> NRTheoErrorHandler -> sendError(), without mocking anything.
//
import Foundation
import NewRelicVideoCore
import THEOplayerSDK
@testable import NRTHEOplayerTracker

fileprivate let testName = "Test 12"

class Test12: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker

        // THEOplayer's initializer touches UIKit internally and asserts it's running on the main
        // thread — see the comment in Test11.swift; same fix applies here.
        DispatchQueue.main.sync {
            let player = THEOplayer()
            tracker.setPlayer(player)
        }

        var attempts = 0
        while !tracker.captured.contains(CONTENT_ERROR) && attempts < 20 {
            Thread.sleep(forTimeInterval: 0.25)
            attempts += 1
        }

        if !tracker.captured.contains(CONTENT_ERROR) {
            self.callback!(testName + " real ERROR event (no license configured) never reached handleError() via registerListeners()", false)
            return
        }

        // Confirm real, non-empty error data actually flowed through NRTheoErrorHandler, not just that
        // *some* CONTENT_ERROR fired. Checking category via the spy (not error.userInfo) deliberately —
        // NRVideoTracker.m's sendError: never reads userInfo, only error.domain/.code/.localizedDescription,
        // so category/cause only ever reach NRDB via the scoped "category"/"cause" custom attributes on
        // CONTENT_ERROR (see NRTrackerTHEOplayer.handleError). Not asserting error.code != 0 either:
        // THEOErrorCode's first case (CONFIGURATION_ERROR) has raw value 0, so 0 is a legitimate real
        // error code here, not just the old bug's placeholder.
        guard let error = tracker.lastError,
              !error.localizedDescription.isEmpty,
              let category = tracker.lastErrorCategory,
              !category.isEmpty else {
            self.callback!(testName + " sendError should receive a populated NSError with a real category attribute", false)
            return
        }

        DispatchQueue.main.sync {
            tracker.player = nil
        }
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        self.callback!(testName, true)
    }

    class TestContentTracker: NRTrackerTHEOplayer {
        var captured: [String] = []
        var lastError: NSError?
        var lastErrorCategory: String?

        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            captured.append(action)
            if action == CONTENT_ERROR, let category = attributes["category"] as? String {
                lastErrorCategory = category
            }
            return false
        }

        override func sendError(_ error: (any Error)?) {
            lastError = error as NSError?
            super.sendError(error)
        }
    }
}
