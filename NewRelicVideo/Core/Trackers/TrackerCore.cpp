//
//  TrackerCore.cpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 25/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#include "TrackerCore.hpp"
#include "ValueHolder.hpp"
#include "PlaybackAutomatCore.hpp"
#include "BackendActionsCore.hpp"
#include "NewRelicAgentCAL-Cpp-Interface.hpp"

// TODO: create a TimestampValue in C++

TrackerCore::TrackerCore() {
    automat = new PlaybackAutomatCore();
    // TODO: how to ask if I'm a ads?
    automat->isAd = false;
}

TrackerCore::~TrackerCore() {
    delete automat;
}

void TrackerCore::reset() {
    viewId = "";
    viewIdIndex = 0;
    numErrors = 0;
    heartbeatCounter = 0;
    playNewVideo();
    
    // TODO: setup trackerReadyTimestamp and lastRenditionChangeTimestamp
}

CoreTrackerState TrackerCore::state() {
    return automat->state;
}

void TrackerCore::updateAttribute(std::string name, ValueHolder value, std::string filter) {
    // NOTE: called by subclass of Tracker to update a tracker (the former getters).
    if (filter.empty()) {
        setOption(name, value);
    }
    else {
        setOption(name, value, filter);
    }
}

void TrackerCore::setup() {}

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
    // TODO: set timestamp for lastRenditionChangeTimestamp
}

void TrackerCore::sendError(std::string message) {
    preSend();
    automat->sendError(message);
    numErrors ++;
}

void TrackerCore::sendPlayerReady() {
    automat->getActions()->sendPlayerReady();
}

void TrackerCore::sendDownload() {
    automat->getActions()->sendDownload();
}

void TrackerCore::sendCustomAction(std::string name) {
    automat->getActions()->sendAction(name);
}

void TrackerCore::sendCustomAction(std::string name, std::map<std::string, ValueHolder> attr) {
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
    // TODO: time stuff
}

void TrackerCore::abortTimerEvent() {
    // TODO: timer stuff
}

bool TrackerCore::setTimestamp(double timestamp, std::string attributeName) {
    // TODO: custom timestamp stuff
    return true;
}

// Private methods

void TrackerCore::preSend() {
    // TODO: generate the attributes (?)
}

void TrackerCore::playNewVideo() {
    std::string sid = currentSessionId();
    if (!sid.empty()) {
        viewId = sid + "-" + std::to_string(viewIdIndex);
        viewIdIndex ++;
        numErrors = 0;
    }
}