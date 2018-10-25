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

// TODO: create a TimestampValue in C++

TrackerCore::TrackerCore() {
    automat = new PlaybackAutomatCore();
    // TODO: set isAd somehow
}

TrackerCore::~TrackerCore() {
    delete automat;
}

void TrackerCore::reset() {
    // TODO: set initial state
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
    // TODO: new video
}
