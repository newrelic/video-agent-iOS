//
//  Test5.swift
//  Tests
//
//  Created by Andreu Santaren on 23/3/21.
//

import Foundation
import NewRelicVideoCore

// Test tracker states.

fileprivate let testName = "Test 5"

class Test5 : TestProtocol {
    
    var callback : ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())
    
    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).setPlayer(NSNull())
        if !checkPlayerReady() {
            self.callback!(testName + " isPlayerReady", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        if !checkRequested() {
            self.callback!(testName + " isRequested", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        if !(checkStarted() && checkPlaying()) {
            self.callback!(testName + " isStarted", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendPause()
        if !checkPaused() {
            self.callback!(testName + " isPaused", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendResume()
        if !checkPlaying() {
            self.callback!(testName + " isPlaying", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkBuffering() {
            self.callback!(testName + " isBuffering", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if checkBuffering() {
            self.callback!(testName + " not isBuffering", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekStart()
        if !checkSeeking() {
            self.callback!(testName + " isSeeking", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        if checkSeeking() {
            self.callback!(testName + " not isSeeking", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendPause()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekStart()
        if !checkSeeking() {
            self.callback!(testName + " isSeeking", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !(checkBuffering() && checkPaused() && !checkSeeking()) {
            self.callback!(testName + " isBuffering & isPaused & not iSeeking", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendResume()
        if !(checkPlaying() && !checkBuffering()) {
            self.callback!(testName + " isPlaying & not isBuffering", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEnd()
        if !(!checkPlaying() && !checkBuffering() && !checkPaused() && !checkSeeking() && !checkStarted()) {
            self.callback!(testName + " END state", false)
            return
        }
        
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        
        self.callback!(testName, true)
    }
    
    func checkPlayerReady() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).state().isPlayerReady()
    }
    
    func checkRequested() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).state().isRequested()
    }
    
    func checkStarted() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).state().isStarted()
    }
    
    func checkPaused() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).state().isPaused()
    }
    
    func checkBuffering() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).state().isBuffering()
    }
    
    func checkSeeking() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).state().isSeeking()
    }

    func checkPlaying() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).state().isPlaying()
    }

    class TestContentTracker : NRVideoTracker {
        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            print("Send Event \(action) with \(attributes)")
            return false
        }
    }
}
