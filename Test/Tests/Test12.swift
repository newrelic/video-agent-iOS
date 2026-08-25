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
        // *some* CONTENT_ERROR fired.
        guard let error = tracker.lastError,
              !error.localizedDescription.isEmpty,
              (error.userInfo["errorCode"] as? String)?.isEmpty == false else {
            self.callback!(testName + " sendError should receive a populated NSError, not an empty one", false)
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

        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            captured.append(action)
            return false
        }

        override func sendError(_ error: (any Error)?) {
            lastError = error as NSError?
            super.sendError(error)
        }
    }
}
