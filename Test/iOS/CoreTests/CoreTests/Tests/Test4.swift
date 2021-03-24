//
//  Test4.swift
//  CoreTests
//
//  Created by Andreu Santaren on 19/3/21.
//

import Foundation
import NewRelicVideoCore

// Test playtimes.

fileprivate let testName = "Test 4"

class Test4 : TestProtocol {
    var callback : ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())
    
    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        if !checkPartialResult() {
            self.callback!(testName + " sendRequest", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        if !checkPartialResult() {
            self.callback!(testName + " sendStart", false)
            return
        }
        Thread.sleep(forTimeInterval: 1.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendPause()
        if !checkPartialResult() {
            self.callback!(testName + " sendPause", false)
            return
        }
        Thread.sleep(forTimeInterval: 1.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendResume()
        if !checkPartialResult() {
            self.callback!(testName + " sendResume", false)
            return
        }
        Thread.sleep(forTimeInterval: 1.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendHeartbeat()
        if !checkPartialResult() {
            self.callback!(testName + " sendHeartbeat", false)
            return
        }
        Thread.sleep(forTimeInterval: 1.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkPartialResult() {
            self.callback!(testName + " sendBufferStart", false)
            return
        }
        Thread.sleep(forTimeInterval: 1.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendBufferEnd", false)
            return
        }
        Thread.sleep(forTimeInterval: 1.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekStart()
        if !checkPartialResult() {
            self.callback!(testName + " sendSeekStart", false)
            return
        }
        Thread.sleep(forTimeInterval: 1.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendSeekEnd", false)
            return
        }
        Thread.sleep(forTimeInterval: 1.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEvent("TEST_ACTION")
        if !checkPartialResult() {
            self.callback!(testName + " send TEST_ACTION", false)
            return
        }
        Thread.sleep(forTimeInterval: 1.0)
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEnd()
        if !checkPartialResult() {
            self.callback!(testName + " sendEnd", false)
            return
        }
        
        self.callback!(testName, true)
    }
    
    func checkPartialResult() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult
    }
    
    class TestContentTracker : NRVideoTracker {
        var partialResult = true
        var totalPlaytime = 0
        
        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            print("Event \(action):")
            print("\tAttribute playtimeSinceLastEvent = \(attributes["playtimeSinceLastEvent"] ?? -1)")
            print("\tAttribute totalPlaytime = \(attributes["totalPlaytime"] ?? -1)")

            if action == CONTENT_REQUEST {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 0)
            }
            else if action == CONTENT_START {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 0)
            }
            else if action == CONTENT_PAUSE {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 1000)
            }
            else if action == CONTENT_RESUME {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 0)
            }
            else if action == CONTENT_HEARTBEAT {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 1000)
            }
            else if action == CONTENT_BUFFER_START {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 1000)
            }
            else if action == CONTENT_BUFFER_END {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 0)
            }
            else if action == CONTENT_SEEK_START {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 1000)
            }
            else if action == CONTENT_SEEK_END {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 0)
            }
            else if action == "TEST_ACTION" {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 1000)
            }
            else if action == CONTENT_END {
                self.partialResult = checkPlaytimes(total: attributes["totalPlaytime"] as! Int, sinceLast: attributes["playtimeSinceLastEvent"] as! Int, timeRef: 1000)
            }
            
            return false
        }
        
        func checkPlaytimes(total: Int, sinceLast: Int, timeRef: Int) -> Bool {
            self.totalPlaytime = self.totalPlaytime + sinceLast
            
            print("Current totalPlaytime = \(self.totalPlaytime)")
            
            if total != self.totalPlaytime {
                return false
            }
            if sinceLast < timeRef || sinceLast > timeRef + 200 {
                return false
            }
            
            return true
        }
    }
}
