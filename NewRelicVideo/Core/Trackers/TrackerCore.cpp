//
//  TrackerCore.cpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 25/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#include "TrackerCore.hpp"
#include "ValueHolder.hpp"
#include "TimestampHolder.hpp"
#include "PlaybackAutomatCore.hpp"
#include "BackendActionsCore.hpp"
#include "CAL.hpp"

TrackerCore::TrackerCore() {
    automat = new PlaybackAutomatCore();
    lastRenditionChangeTimestamp = new TimestampHolder(0);
    trackerReadyTimestamp = new TimestampHolder(0);
    
    ValueHolder val = callGetter("isAd");
    if (val.getValueType() == ValueHolder::ValueHolderTypeInt) {
        automat->isAd = (bool)val.getValueInt();
    }
    else {
        automat->isAd = false;
    }
}

TrackerCore::~TrackerCore() {
    delete automat;
    delete lastRenditionChangeTimestamp;
    delete trackerReadyTimestamp;
}

void TrackerCore::reset() {
    viewId = "";
    viewIdIndex = 0;
    numErrors = 0;
    heartbeatCounter = 0;
    trackerReadyTimestamp->setMain(systemTimestamp());
    lastRenditionChangeTimestamp->setMain(0.0);
    playNewVideo();
    preSend();
}

CoreTrackerState TrackerCore::state() {
    return automat->state;
}

// TODO: updateAttribute and setOptions are aliases, one must disapear (setOption is less clear, I would keep updateAttribute).
// also add updateAttributes to replace setOptions
void TrackerCore::updateAttribute(std::string name, ValueHolder value, std::string filter) {
    setOption(name, value, filter);
}

void TrackerCore::updateAttribute(std::string name, ValueHolder value) {
    setOption(name, value);
}

void TrackerCore::setup() {}

std::string TrackerCore::getViewId() {
    return viewId;
}

int TrackerCore::getNumberOfVideos() {
    return viewIdIndex;
}

std::string TrackerCore::getCoreVersion() {
    return PRODUCT_VERSION_STR;
}

std::string TrackerCore::getViewSession() {
    return currentSessionId();
}

int TrackerCore::getNumberOfErrors() {
    return numErrors;
}

// NOTE: build all attributes before sending an event to NR
void TrackerCore::preSend() {
    updateAttribute("timeSinceTrackerReady", ValueHolder(trackerReadyTimestamp->sinceMillis()));
    updateAttribute("timeSinceLastRenditionChange", ValueHolder(lastRenditionChangeTimestamp->sinceMillis()), "_RENDITION_CHANGE");
    
    // TrackerCore getters
    updateAttribute("viewId", ValueHolder(getViewId()));
    updateAttribute("numberOfVideos", ValueHolder(getNumberOfVideos()));
    updateAttribute("coreVersion", ValueHolder(getCoreVersion()));
    updateAttribute("viewSession", ValueHolder(getViewSession()));
    updateAttribute("numberOfErrors", ValueHolder(getNumberOfErrors()));
    
    // Sub TrackerCore getters
    updateAttribute("trackerName", callGetter("trackerName"));
    updateAttribute("trackerVersion", callGetter("trackerVersion"));
    updateAttribute("playerVersion", callGetter("playerVersion"));
    updateAttribute("playerName", callGetter("playerName"));
    updateAttribute("isAd", callGetter("isAd"));
}

void TrackerCore::sendRequest() {
    preSend();
    automat->sendRequest();
    startTimerEvent();
}

void TrackerCore::sendStart() {
    preSend();
    automat->sendStart();
}

void TrackerCore::sendEnd() {
    preSend();
    automat->sendEnd();
    playNewVideo();
    abortTimerEvent();
}

void TrackerCore::sendPause() {
    preSend();
    automat->sendPause();
}

void TrackerCore::sendResume() {
    preSend();
    automat->sendResume();
}

void TrackerCore::sendSeekStart() {
    preSend();
    automat->sendSeekStart();
}

void TrackerCore::sendSeekEnd() {
    preSend();
    automat->sendSeekEnd();
}

void TrackerCore::sendBufferStart() {
    preSend();
    automat->sendBufferStart();
}

void TrackerCore::sendBufferEnd() {
    preSend();
    automat->sendBufferEnd();
}

void TrackerCore::sendHeartbeat() {
    preSend();
    automat->sendHeartbeat();
}

void TrackerCore::sendRenditionChange() {
    preSend();
    automat->sendRenditionChange();
    lastRenditionChangeTimestamp->setMain(systemTimestamp());
}

void TrackerCore::sendError(std::string message) {
    preSend();
    automat->sendError(message);
    numErrors ++;
}

void TrackerCore::sendPlayerReady() {
    preSend();
    automat->getActions()->sendPlayerReady();
}

/*
 TODO:
 - Implement DOWNLOAD's "state" attribute. Argument to sendDownload method.
 */

void TrackerCore::sendDownload() {
    preSend();
    automat->getActions()->sendDownload();
}

void TrackerCore::sendCustomAction(std::string name) {
    preSend();
    automat->getActions()->sendAction(name);
}

void TrackerCore::sendCustomAction(std::string name, std::map<std::string, ValueHolder> attr) {
    preSend();
    automat->getActions()->sendAction(name, attr);
}

void TrackerCore::setOptions(std::map<std::string, ValueHolder> opts) {
    automat->getActions()->generalOptions = opts;
}

void TrackerCore::setOption(std::string key, ValueHolder value) {
    automat->getActions()->generalOptions[key] = value;
}

void TrackerCore::setOptions(std::map<std::string, ValueHolder> opts, std::string action) {
    automat->getActions()->actionOptions[action] = opts;
}

void TrackerCore::setOption(std::string key, ValueHolder value, std::string action) {
    automat->getActions()->actionOptions[action][key] = value;
}

void TrackerCore::startTimerEvent() {
    startTimer(this);
}

void TrackerCore::abortTimerEvent() {
    abortTimer();
}

void TrackerCore::trackerTimeEvent() {
    heartbeatCounter ++;
    
    if (heartbeatCounter >= HEARTBEAT_COUNT) {
        heartbeatCounter = 0;
        sendHeartbeat();
    }
}

bool TrackerCore::setTimestamp(double timestamp, std::string attributeName) {
    if (attributeName == "timeSinceTrackerReady") {
        trackerReadyTimestamp->setExternal(timestamp);
    }
    else if (attributeName == "timeSinceLastRenditionChange") {
        lastRenditionChangeTimestamp->setExternal(timestamp);
    }
    else {
        return false;
    }
    
    return true;
}

// Private methods

void TrackerCore::playNewVideo() {
    std::string sid = currentSessionId();
    if (!sid.empty()) {
        viewId = sid + "-" + std::to_string(viewIdIndex);
        viewIdIndex ++;
        numErrors = 0;
    }
}
