//
//  Test1.swift
//  Tests
//
//  Created by Andreu Santaren on 18/3/21.
//

import Foundation
import NewRelicVideoCore

// Test basic tracker workflow.

fileprivate let testName = "Test 1"

class Test1 : TestProtocol {
    
    var callback : ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())
    
    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).setPlayer(NSNull())
        if !checkPartialResult() {
            self.callback!(testName + " setPlayer", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        if !checkPartialResult() {
            self.callback!(testName + " sendRequest(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        if !checkPartialResult() {
            self.callback!(testName + " sendRequest(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        if !checkPartialResult() {
            self.callback!(testName + " sendStart(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        if !checkPartialResult() {
            self.callback!(testName + " sendStart(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendPause()
        if !checkPartialResult() {
            self.callback!(testName + " sendPause(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendSeekEnd(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendBufferEnd(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendPause()
        if !checkPartialResult() {
            self.callback!(testName + " sendPause(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendResume()
        if !checkPartialResult() {
            self.callback!(testName + " sendResume(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendResume()
        if !checkPartialResult() {
            self.callback!(testName + " sendResume(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkPartialResult() {
            self.callback!(testName + " sendBufferStart(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkPartialResult() {
            self.callback!(testName + " sendBufferStart(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendBufferEnd(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendBufferEnd(3)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekStart()
        if !checkPartialResult() {
            self.callback!(testName + " sendSeekStart(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekStart()
        if !checkPartialResult() {
            self.callback!(testName + " sendSeekStart(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendSeekEnd(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendSeekEnd(3)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendHeartbeat()
        if !checkPartialResult() {
            self.callback!(testName + " sendHeartbeat", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendEnd(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendEnd(2)", false)
            return
        }
        
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        
        if NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) != nil {
            self.callback!(testName + " release", false)
            return
        }
        
        self.callback!(testName, true)
    }
    
    func checkPartialResult() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult
    }
    
    class TestContentTracker : NRVideoTracker {
        var partialResult = true
        var eventCounter = 0
        
        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            print("Send Event \(action) with \(attributes)")

            if action == TRACKER_READY {
                calcPartialresult(index: 0)
            }
            else if action == PLAYER_READY {
                calcPartialresult(index: 1)
            }
            else if action == CONTENT_REQUEST {
                calcPartialresult(index: 2)
            }
            else if action == CONTENT_START {
                calcPartialresult(index: 3)
            }
            else if action == CONTENT_PAUSE {
                calcPartialresult(index: 4)
            }
            else if action == CONTENT_RESUME {
                calcPartialresult(index: 5)
            }
            else if action == CONTENT_BUFFER_START {
                calcPartialresult(index: 6)
            }
            else if action == CONTENT_BUFFER_END {
                calcPartialresult(index: 7)
            }
            else if action == CONTENT_SEEK_START {
                calcPartialresult(index: 8)
            }
            else if action == CONTENT_SEEK_END {
                calcPartialresult(index: 9)
            }
            else if action == CONTENT_HEARTBEAT {
                calcPartialresult(index: 10)
            }
            else if action == CONTENT_END {
                calcPartialresult(index: 11)
            }
            
            return false
        }
        
        func calcPartialresult(index: Int) {
            if eventCounter != index {
                partialResult = false
            }
            eventCounter = eventCounter + 1
        }
    }
}
