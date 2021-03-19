//
//  Test1.swift
//  CoreTests
//
//  Created by Andreu Santaren on 18/3/21.
//

import Foundation
import NewRelicVideoCore

// Test basic tracker workflow.

class Test1 : TestProtocol {
    
    var callback : ((String, Bool) -> Void?)? = nil
    let testName = "Test 1"
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())
    
    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).setPlayer(NSNull())
        if !(NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult {
            self.callback!(testName, false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        if !(NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult {
            self.callback!(testName, false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        if !(NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult {
            self.callback!(testName, false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        if !(NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult {
            self.callback!(testName, false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        if !(NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult {
            self.callback!(testName, false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEnd()
        if !(NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult {
            self.callback!(testName, false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEnd()
        if !(NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! TestContentTracker).partialResult {
            self.callback!(testName, false)
            return
        }
        
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        
        if NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) != nil {
            self.callback!(testName, false)
            return
        }
        
        self.callback!(testName, true)
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
            else if action == CONTENT_END {
                calcPartialresult(index: 4)
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
