//
//  ContentsTrackerCore.hpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 29/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#ifndef ContentsTrackerCore_hpp
#define ContentsTrackerCore_hpp

#include <stdio.h>
#include "TrackerCore.hpp"

class TimestampHolder;

class ContentsTrackerCore: public TrackerCore {
private:
    // Time Counts
    double totalPlaytimeTimestamp;
    double playtimeSinceLastEventTimestamp;
    double totalPlaytime;
    
    // Time Since
    TimestampHolder *requestTimestamp;
    TimestampHolder *heartbeatTimestamp;
    TimestampHolder *startedTimestamp;
    TimestampHolder *pausedTimestamp;
    TimestampHolder *bufferBeginTimestamp;
    TimestampHolder *seekBeginTimestamp;
    TimestampHolder *lastAdTimestamp;
    
public:
    ContentsTrackerCore();
    ~ContentsTrackerCore();
    
    // Overwritten from TrackerCore
    void reset();
    void preSend();
    void sendRequest();
    void sendStart();
    void sendEnd();
    void sendPause();
    void sendResume();
    void sendSeekStart();
    void sendBufferStart();
    void sendHeartbeat();
    bool setTimestamp(double timestamp, std::string attributeName);
};

#endif /* ContentsTrackerCore_hpp */
