//
//  AdsTrackerCore.hpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/11/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#ifndef AdsTrackerCore_hpp
#define AdsTrackerCore_hpp

#include <stdio.h>
#include "TrackerCore.hpp"

class ContentsTracker;

class AdsTrackerCore: public TrackerCore {
private:
    ContentsTracker *contentsTracker;
    
protected:
    void preSend();
    
public:
    AdsTrackerCore(ContentsTracker *contentsTracker);
    ~AdsTrackerCore();
    
    // Overwritten from TrackerCore
    void reset();
    void sendRequest();
    void sendStart();
    void sendEnd();
    void sendPause();
    void sendResume();
    void sendSeekStart();
    void sendSeekEnd();
    void sendBufferStart();
    void sendBufferEnd();
    void sendHeartbeat();
    void sendRenditionChange();
    void sendError(std::string message);
    void sendPlayerReady();
    void sendDownload();
    void sendCustomAction(std::string name);
    void sendCustomAction(std::string name, std::map<std::string, ValueHolder> attr);
    bool setTimestamp(double timestamp, std::string attributeName);
    
    // AdsTracker methods
    void sendAdBreakStart();
    void sendAdBreakEnd();
    void sendAdQuartile();
    void sendAdClick();
};

#endif /* AdsTrackerCore_hpp */
