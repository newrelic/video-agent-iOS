//
//  Test2.swift
//  CoreTests
//
//  Created by Andreu Santaren on 19/3/21.
//

import Foundation
import NewRelicVideoCore

// Test start time, buffering, pause, seeking and related timers.

fileprivate let TTFF : UInt32 = 1100
fileprivate let BUFFER_TIME : UInt32 = 800
fileprivate let SEEK_TIME : UInt32 = 1000
fileprivate let PAUSE_TIME : UInt32 = 1200

class Test2 : TestProtocol {
    
    var callback : ((String, Bool) -> Void?)? = nil
    let testName = "Test 2"
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())
    
    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).setPlayer(NSNull())
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        
        usleep(TTFF * 1000)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        if !checkPartialResult() {
            self.callback!(testName, false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        usleep(BUFFER_TIME * 1000)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName, false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekStart()
        usleep(SEEK_TIME * 1000)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        if !checkPartialResult() {
            self.callback!(testName, false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendPause()
        usleep(PAUSE_TIME * 1000)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendResume()
        if !checkPartialResult() {
            self.callback!(testName, false)
            return
        }
        
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

        func checkTimeSinceAttribute(attr: NSMutableDictionary, name: String, target: UInt32) {
            if let ts = attr[name] as? Int {
                if !checkTimeSince(value: ts, target: target) {
                    partialResult = false
                }
            }
            else {
                partialResult = false
            }
        }
        
        func checkTimeSince(value: Int, target: UInt32) -> Bool {
            return value >= target && value < target + 50   //50ms margin
        }
    }
}
