//
//  Test16.swift
//  Tests
//
//  NRTrackerTHEOplayer — unregisterListeners() must actually detach from the real THEOplayer instance,
//  not just clear its own bookkeeping array. Test11 only asserts tracker.listeners.isEmpty after
//  unregister, which trivially passes even if unregisterListeners() never calls
//  player.removeEventListener at all — that was the exact bug: listeners.removeAll() emptied the local
//  array while THEOplayer kept invoking the (still-attached) closures underneath.
//
//  Reuses Test12's real ERROR-after-construction signal (Test/iOS/CoreTests deliberately has no valid
//  THEOplayerLicense configured, so a real THEOError fires a few seconds after construction) as a
//  differential probe: unregister immediately after setPlayer, before that real error has any chance to
//  fire, then confirm CONTENT_ERROR never reaches this tracker even after waiting *longer* than Test12's
//  own worst-case observation window (20 attempts * 0.25s = up to 5s) — waiting less than that would let
//  a real regression land after this test already asserted and go undetected. If unregisterListeners()
//  only cleared local bookkeeping, the [weak self] closure captured in registerListeners() would still
//  be live on the real player and CONTENT_ERROR would still land despite unregistering.
//
import Foundation
import NewRelicVideoCore
import THEOplayerSDK
@testable import NRTHEOplayerTracker

fileprivate let testName = "Test 16"

class Test16: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker

        // THEOplayer's initializer touches UIKit internally and asserts it's running on the main
        // thread — same fix as Test11/Test12.
        DispatchQueue.main.sync {
            let player = THEOplayer()
            tracker.setPlayer(player)
            // Unregister immediately, before the real license error (confirmed by Test12 to take up to
            // ~5s to fire) has any chance to. If removeEventListener never actually ran, the ERROR
            // closure is still live on `player` and will call handleError -> sendError once the error
            // does arrive.
            tracker.unregisterListeners()
        }

        // Longer than Test12's own worst-case wait (20 * 0.25s = 5s) for the same real error signal —
        // asserting on a window shorter than that would risk a false pass if the error simply hadn't
        // fired yet.
        Thread.sleep(forTimeInterval: 7.0)

        if tracker.hasCaptured(CONTENT_ERROR) {
            self.callback!(testName + " unregisterListeners() should detach from the real THEOplayer instance, not just clear local bookkeeping — CONTENT_ERROR still arrived after unregister", false)
            return
        }

        DispatchQueue.main.sync {
            tracker.player = nil
        }
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        self.callback!(testName, true)
    }

    class TestContentTracker: NRTrackerTHEOplayer {
        // Same cross-thread access as Test12.swift (main-thread real event callbacks vs. this test's
        // background-thread poll after the fixed 7s wait) — same lock-guarded fix.
        private let capturedLock = NSLock()
        private var captured: [String] = []

        func hasCaptured(_ action: String) -> Bool {
            capturedLock.lock()
            defer { capturedLock.unlock() }
            return captured.contains(action)
        }

        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            capturedLock.lock()
            captured.append(action)
            capturedLock.unlock()
            return false
        }
    }
}
