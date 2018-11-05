//
//  ContentsTrackerCore.cpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 29/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#include "ContentsTrackerCore.hpp"
#include "TimestampHolder.hpp"
#include "ValueHolder.hpp"
#include "CAL.hpp"
#include "EventDefsCore.hpp"

ContentsTrackerCore::ContentsTrackerCore() {
    requestTimestamp = new TimestampHolder(0);
    heartbeatTimestamp = new TimestampHolder(0);
    startedTimestamp = new TimestampHolder(0);
    pausedTimestamp = new TimestampHolder(0);
    bufferBeginTimestamp = new TimestampHolder(0);
    seekBeginTimestamp = new TimestampHolder(0);
    lastAdTimestamp = new TimestampHolder(0);
}

ContentsTrackerCore::~ContentsTrackerCore() {
    delete requestTimestamp;
    delete heartbeatTimestamp;
    delete startedTimestamp;
    delete pausedTimestamp;
    delete bufferBeginTimestamp;
    delete seekBeginTimestamp;
    delete lastAdTimestamp;
}

// TODO: Must registerGetter for those attributes:
//updateAttribute("trackerName", callGetter("trackerName"));
//updateAttribute("trackerVersion", callGetter("trackerVersion"));
//updateAttribute("playerVersion", callGetter("playerVersion"));
//updateAttribute("playerName", callGetter("playerName"));
//updateAttribute("isAd", callGetter("isAd"));

// TODO: FIX double sendXXX

void ContentsTrackerCore::reset() {
    TrackerCore::reset();
    
    totalPlaytime = 0;
    playtimeSinceLastEventTimestamp = 0;
    totalPlaytimeTimestamp = 0;
    
    requestTimestamp->setMain(0);
    heartbeatTimestamp->setMain(0);
    startedTimestamp->setMain(0);
    pausedTimestamp->setMain(0);
    bufferBeginTimestamp->setMain(0);
    seekBeginTimestamp->setMain(0);
    lastAdTimestamp->setMain(0);
    
    // TODO: call all getters and update attributes.
    //[self updateContentsAttributes];
}

void ContentsTrackerCore::preSend() {
    TrackerCore::preSend();
    
    // TODO: call all getters and update attributes.
    //[self updateContentsAttributes];
    
    // Special time calculations, accumulative timestamps
    
    if (state() == CoreTrackerStatePlaying) {
        totalPlaytime += timeSince(totalPlaytimeTimestamp);
        totalPlaytimeTimestamp = systemTimestamp();
    }
    updateAttribute("totalPlaytime", ValueHolder(1000.0f * totalPlaytime), "CONTENT_");
    
    if (playtimeSinceLastEventTimestamp == 0) {
        playtimeSinceLastEventTimestamp = systemTimestamp();
    }
    updateAttribute("playtimeSinceLastEvent", ValueHolder(1000.0f * timeSince(playtimeSinceLastEventTimestamp)), "CONTENT_");
    playtimeSinceLastEventTimestamp = systemTimestamp();
    
    // Regular offset timestamps, time since
    
    if (heartbeatTimestamp->timestamp() > 0.0) {
        updateAttribute("timeSinceLastHeartbeat", ValueHolder(heartbeatTimestamp->sinceMillis()), "CONTENT_");
    }
    else {
        updateAttribute("timeSinceLastHeartbeat", ValueHolder(requestTimestamp->sinceMillis()), "CONTENT_");
    }
    
    updateAttribute("timeSinceRequested", ValueHolder(requestTimestamp->sinceMillis()));
    updateAttribute("timeSinceStarted", ValueHolder(startedTimestamp->sinceMillis()));
    updateAttribute("timeSincePaused", ValueHolder(pausedTimestamp->sinceMillis()), CONTENT_RESUME);
    updateAttribute("timeSinceBufferBegin", ValueHolder(bufferBeginTimestamp->sinceMillis()), CONTENT_BUFFER_END);
    updateAttribute("timeSinceSeekBegin", ValueHolder(seekBeginTimestamp->sinceMillis()), CONTENT_SEEK_END);
    updateAttribute("timeSinceLastAd", ValueHolder(lastAdTimestamp->sinceMillis()));
}

void ContentsTrackerCore::sendRequest() {
    requestTimestamp->setMain(systemTimestamp());
    TrackerCore::sendRequest();
}

void ContentsTrackerCore::sendStart() {
    if (state() == CoreTrackerStateStarting) {
        startedTimestamp->setMain(systemTimestamp());
    }
    totalPlaytimeTimestamp = systemTimestamp();
    TrackerCore::sendStart();
}

void ContentsTrackerCore::sendEnd() {
    TrackerCore::sendEnd();
    totalPlaytime = 0;
    lastAdTimestamp->setMain(0);
}

void ContentsTrackerCore::sendPause() {
    pausedTimestamp->setMain(systemTimestamp());
    TrackerCore::sendPause();
}

void ContentsTrackerCore::sendResume() {
    totalPlaytimeTimestamp = systemTimestamp();
    TrackerCore::sendResume();
}

void ContentsTrackerCore::sendSeekStart() {
    seekBeginTimestamp->setMain(systemTimestamp());
    TrackerCore::sendSeekStart();
}

void ContentsTrackerCore::sendBufferStart() {
    bufferBeginTimestamp->setMain(systemTimestamp());
    TrackerCore::sendBufferStart();
}

void ContentsTrackerCore::sendHeartbeat() {
    heartbeatTimestamp->setMain(systemTimestamp());
    TrackerCore::sendHeartbeat();
}

void ContentsTrackerCore::adHappened(double time) {
    lastAdTimestamp->setMain(time);
}

bool ContentsTrackerCore::setTimestamp(double timestamp, std::string attributeName) {
    if (!TrackerCore::setTimestamp(timestamp, attributeName)) {
        if (attributeName == "timeSinceRequested") {
            requestTimestamp->setExternal(timestamp);
        }
        else if (attributeName == "timeSinceStarted") {
            startedTimestamp->setExternal(timestamp);
        }
        else if (attributeName == "timeSincePaused") {
            pausedTimestamp->setExternal(timestamp);
        }
        else if (attributeName == "timeSinceBufferBegin") {
            bufferBeginTimestamp->setExternal(timestamp);
        }
        else if (attributeName == "timeSinceSeekBegin") {
            seekBeginTimestamp->setExternal(timestamp);
        }
        else if (attributeName == "timeSinceLastAd") {
            lastAdTimestamp->setExternal(timestamp);
        }
        else if (attributeName == "timeSinceLastHeartbeat") {
            heartbeatTimestamp->setExternal(timestamp);
        }
        else {
            return false;
        }
    }
    
    return true;
}
