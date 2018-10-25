//
//  TrackerCore.hpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 25/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#ifndef TrackerCore_hpp
#define TrackerCore_hpp

#include <stdio.h>
#include <string>
#include <map>

class ValueHolder;
class PlaybackAutomatCore;

class TrackerCore {
private:
    PlaybackAutomatCore *automat;
    std::string viewId;
    int viewIdIndex;
    int numErrors;
    int heartbeatCounter;
    
    void preSend();
    void playNewVideo();
    
public:
    TrackerCore();
    ~TrackerCore();
    void reset();
    void setup();
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
    void setOptions(std::map<std::string, ValueHolder> opts);
    void setOption(std::string key, ValueHolder value);
    void setOptions(std::map<std::string, ValueHolder> opts, std::string action);
    void setOption(std::string key, ValueHolder value, std::string action);
    void startTimerEvent();
    void abortTimerEvent();
    bool setTimestamp(double timestamp, std::string attributeName);
};

#endif /* TrackerCore_hpp */
