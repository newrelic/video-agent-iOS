//
//  Test3.swift
//  CoreTests
//
//  Created by Andreu Santaren on 19/3/21.
//

import Foundation
import NewRelicVideoCore

// Test buffer type.

fileprivate let testName = "Test 3"
fileprivate var startTimestamp : TimeInterval = 0

class Test3 : TestProtocol {
    var callback : ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())
    
    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).setPlayer(NSNull())
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 0 start", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 0 end", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        startTimestamp = NSDate().timeIntervalSince1970
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 1 start", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 1 end", false)
            return
        }
        
        Thread.sleep(forTimeInterval: 1.5)
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 2 start", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 2 end", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendPause()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 3 start", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 3 end", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendResume()
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekStart()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 4 start", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 4 end", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendPause()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekStart()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 5 start", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if !checkPartialResult() {
            self.callback!(testName + " buffer 5 end", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendSeekEnd()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendResume()
        
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        
        self.callback!(testName, true)
    }
    
    func checkPartialResult() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult
    }
    
    class TestContentTracker : NRVideoTracker {
        var partialResult = true
        var bufferingCounter = 0
        
        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            print("Send Event \(action) with \(attributes)")
            
            if action == CONTENT_BUFFER_START {
                self.partialResult = checkBufferType(type: attributes["bufferType"] as? String ?? "")
            }
            else if action == CONTENT_BUFFER_END {
                self.partialResult = checkBufferType(type: attributes["bufferType"] as? String ?? "")
                bufferingCounter = bufferingCounter + 1
            }
            
            return false
        }
        
        func checkBufferType(type: String) -> Bool {
            switch bufferingCounter {
            case 0:
                return type == "initial"
            case 1:
                return type == "initial"
            case 2:
                return type == "connection"
            case 3:
                return type == "pause"
            case 4:
                return type == "seek"
            case 5:
                return type == "seek"
            default:
                return false
            }
        }
        
        override func getPlayhead() -> NSNumber {
            if startTimestamp > 0 {
                return NSNumber(integerLiteral: Int((NSDate().timeIntervalSince1970 - startTimestamp) * 1000))
            }
            else {
                return 0
            }
        }
    }
}
