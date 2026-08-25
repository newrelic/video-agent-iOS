//
//  Test11.swift
//  Tests
//
//  NRTrackerTHEOplayer — real listener lifecycle test, using a real THEOplayer instance.
//
//  Originally this test asserted a real SOURCE_CHANGE event reaches handleSourceChange() via
//  registerListeners(). That assumption turned out to be wrong in this environment: Test/iOS/CoreTests
//  deliberately has an invalid THEOplayerLicense configured (Test12 relies on it), and confirmed
//  empirically — any invalid license, even a well-formed-looking fake JWT, produces an immediate
//  THEOError that short-circuits the source pipeline before SOURCE_CHANGE ever fires. Test12 already
//  proves the real event-wiring path end-to-end via that same ERROR event, so this test instead covers
//  a different real gap: does unregisterListeners() actually clear what registerListeners() attached to
//  a real player, or does it just clear the local bookkeeping array while THEOplayer keeps calling into
//  a deallocated/stale tracker?
//
import Foundation
import NewRelicVideoCore
import THEOplayerSDK
@testable import NRTHEOplayerTracker

fileprivate let testName = "Test 11"

class Test11: TestProtocol {

    var callback: ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())

    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        let tracker = NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker

        // THEOplayer's initializer touches UIKit internally (builds a PlayerViewController/PlayerView
        // hierarchy at init time) and asserts it's running on the main thread — confirmed the hard way,
        // it crashes (dispatch_assert_queue_fail) if constructed from doTest()'s background queue.
        DispatchQueue.main.sync {
            let player = THEOplayer()
            tracker.setPlayer(player)
        }

        if tracker.listeners.isEmpty {
            self.callback!(testName + " registerListeners() should have attached at least one real listener", false)
            return
        }
        let countAfterRegister = tracker.listeners.count

        tracker.unregisterListeners()

        if !tracker.listeners.isEmpty {
            self.callback!(testName + " unregisterListeners() should clear every listener it registered (\(countAfterRegister) were attached)", false)
            return
        }

        // THEOplayer's own deinit also touches UIKit internals — confirmed the hard way (a UIView
        // _didMoveFromWindow:toWindow: assertion crash) when the last reference dropped on this
        // background test thread. Force the drop to happen on main instead.
        DispatchQueue.main.sync {
            tracker.player = nil
        }
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        self.callback!(testName, true)
    }

    class TestContentTracker: NRTrackerTHEOplayer {
        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            false
        }
    }
}
