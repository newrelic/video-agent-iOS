//
//  Test2.swift
//  CoreTests
//
//  Created by Andreu Santaren on 19/3/21.
//

import Foundation
import NewRelicVideoCore

// Test start time, buffering, pause, seeking and related timers.

fileprivate let testName = "Test 2"
fileprivate let TTFF : TimeInterval = 1100.0
fileprivate let BUFFER_TIME : TimeInterval = 800.0
fileprivate let SEEK_TIME : TimeInterval = 1000.0
fileprivate let PAUSE_TIME : TimeInterval = 1200.0

class Test2 : TestProtocol {
    
    var callback : ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())
    
    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).setPlayer(NSNull())
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        
        //Thread.current.
        Thread.sleep(forTimeInterval: TTFF / 1000.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        if !checkPartialResult() {
            self.callback!(testName + " TTFF", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        Thread.sleep(forTimeInterval: BUFFER_TIME / 1000.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " BUFFER_TIME", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekStart()
        Thread.sleep(forTimeInterval: SEEK_TIME / 1000.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        if !checkPartialResult() {
            self.callback!(testName + " SEEK_TIME", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendPause()
        Thread.sleep(forTimeInterval: PAUSE_TIME / 1000.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendResume()
        if !checkPartialResult() {
            self.callback!(testName + " PAUSE_TIME", false)
            return
        }
        
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        
        self.callback!(testName, true)
    }
    
    func checkPartialResult() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult
    }
    
    class TestContentTracker : NRVideoTracker {
        var partialResult = true
        
        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            print("Send Event \(action) with \(attributes)")
            
            if action == CONTENT_START {
                checkTimeSinceAttribute(attr: attributes, name: "timeSinceRequested", target: TTFF)
            }
            else if action == CONTENT_BUFFER_END {
                checkTimeSinceAttribute(attr: attributes, name: "timeSinceBufferBegin", target: BUFFER_TIME)
            }
            else if action == CONTENT_SEEK_END {
                checkTimeSinceAttribute(attr: attributes, name: "timeSinceSeekBegin", target: SEEK_TIME)
            }
            else if action == CONTENT_RESUME {
                checkTimeSinceAttribute(attr: attributes, name: "timeSincePaused", target: PAUSE_TIME)
            }
            
            return false
        }

        func checkTimeSinceAttribute(attr: NSMutableDictionary, name: String, target: TimeInterval) {
            if let ts = attr[name] as? Int {
                if !checkTimeSince(value: TimeInterval(ts), target: target) {
                    partialResult = false
                }
            }
            else {
                partialResult = false
            }
        }
        
        func checkTimeSince(value: TimeInterval, target: TimeInterval) -> Bool {
            return value >= target && value < target + 150   //150ms margin
        }
    }
}
