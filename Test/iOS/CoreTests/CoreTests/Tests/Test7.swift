//
//  Test7.swift
//  CoreTests
//
//  Created by Andreu Santaren on 23/3/21.
//

import Foundation
import NewRelicVideoCore

// Test Ad specific stuff.

fileprivate let testName = "Test 7"
fileprivate var numberOfAds = -1
fileprivate var bufferType = ""
fileprivate var ADBREAK_TIME : TimeInterval = 0

class Test7 : TestProtocol {
    
    var callback : ((String, Bool) -> Void?)? = nil
    let trackerId = NewRelicVideoAgent.sharedInstance().start(withContentTracker: TestContentTracker(), adTracker: TestAdTracker())
    
    func doTest(_ callback: @escaping (String, Bool) -> Void) {
        self.callback = callback
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).setPlayer(NSNull())
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendRequest()
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendAdBreakStart()
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if bufferType != "ad" {
            self.callback!(testName + " sendBufferStart", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendRequest()
        Thread.sleep(forTimeInterval: 0.5)
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendStart()
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendEnd()
        
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendRequest()
        Thread.sleep(forTimeInterval: 0.5)
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendStart()
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendEnd()
        
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendAdBreakEnd()
        if !checkAdPartialResult() {
            self.callback!(testName + " sendAdBreakEnd", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if bufferType != "ad" {
            self.callback!(testName + " sendBufferEnd", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendStart()
        if !(numberOfAds == 2) {
            self.callback!(testName + " content sendStart", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferStart()
        if bufferType != "initial" {
            self.callback!(testName + " sendBufferStart(2)", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().contentTracker(trackerId) as! NRVideoTracker).sendBufferEnd()
        if bufferType != "initial" {
            self.callback!(testName + " sendBufferEnd(2)", false)
            return
        }
        
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendAdBreakStart()
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendRequest()
        Thread.sleep(forTimeInterval: 0.5)
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendStart()
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendEnd()
        if numberOfAds != 3 {
            self.callback!(testName + " content ad sendEnd", false)
            return
        }
        (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! NRVideoTracker).sendAdBreakEnd()
        
        NewRelicVideoAgent.sharedInstance().releaseTracker(trackerId)
        
        self.callback!(testName, true)
    }
    
    func checkAdPartialResult() -> Bool {
        return (NewRelicVideoAgent.sharedInstance().adTracker(trackerId) as! TestAdTracker).partialResult
    }
    
    class TestContentTracker : NRVideoTracker {
        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            print("Send Event \(action) with \(attributes)")
            
            if let n = attributes["numberOfAds"] as? Int {
                numberOfAds = n
            }
            
            if action == CONTENT_BUFFER_START || action == CONTENT_BUFFER_END {
                if let bt = attributes["bufferType"] as? String {
                    bufferType = bt
                }
            }
            
            return false
        }
    }
    
    class TestAdTracker : NRVideoTracker {
        var partialResult = true
        override func preSendAction(_ action: String, attributes: NSMutableDictionary) -> Bool {
            print("Send Ad Event \(action) with \(attributes)")
            
            if let n = attributes["numberOfAds"] as? Int {
                numberOfAds = n
            }
            
            if action == AD_END {
                if let ts = attributes["timeSinceAdRequested"] as? Int {
                    ADBREAK_TIME = ADBREAK_TIME + TimeInterval(ts)
                }
            }
            else if action == AD_BREAK_END {
                if let ts = attributes["timeSinceAdBreakBegin"] as? Int {
                    if TimeInterval(ts) < ADBREAK_TIME || TimeInterval(ts) > ADBREAK_TIME + 100 {
                        partialResult = false
                    }
                }
            }
            
            return false
        }
    }
}
