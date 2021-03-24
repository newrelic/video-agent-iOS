//
//  Test6.swift
//  Tests
//
//  Created by Andreu Santaren on 23/3/21.
//

import Foundation
import NewRelicVideoCore

// Test counters and IDs.

fileprivate let testName = "Test 6"
fileprivate var numberOfVideos = -1
fileprivate var numberOfErrors = -1
fileprivate var viewIds : [String : Bool] = [:]

class Test6 : TestProtocol {
    
    var callback : ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker())
    
    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).setPlayer(NSNull())
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        if viewIds.count != 1 {
            self.callback!(testName + " sendRequest(1)", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEnd()
        if !(numberOfVideos == 1 && numberOfErrors == 0) {
            self.callback!(testName + " sendEnd(1)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        if viewIds.count != 2 {
            self.callback!(testName + " sendRequest(2)", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendError()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEnd()
        if !(numberOfVideos == 2 && numberOfErrors == 1) {
            self.callback!(testName + " sendEnd(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        if viewIds.count != 3 {
            self.callback!(testName + " sendRequest(3)", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendError()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendError()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendEnd()
        if !(numberOfVideos == 3 && numberOfErrors == 2) {
            self.callback!(testName + " sendEnd(3)", false)
            return
        }
        
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        
        self.callback!(testName, true)
    }
    
    class TestContentTracker : NRVideoTracker {
        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            print("Send Event \(action) with \(attributes)")
            
            if action == CONTENT_REQUEST {
                if let vid = attributes["viewId"] as? String {
                    viewIds[vid] = true
                }
            }
            else if action == CONTENT_END {
                if let n = attributes["numberOfVideos"] as? Int {
                    numberOfVideos = n
                }
                if let n = attributes["numberOfErrors"] as? Int {
                    numberOfErrors = n
                }
            }
            
            return false
        }
    }
}
