//
//  BackendActionsCore.cpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#include "BackendActionsCore.hpp"
#include "EventDefsCore.hpp"
#include "ValueHolder.hpp"
#include "NewRelicAgentCAL-Cpp-Interface.hpp"

// TODO: implement generaOptions and actionOptions

BackendActionsCore::BackendActionsCore() {
}

BackendActionsCore::~BackendActionsCore() {
}

void BackendActionsCore::sendRequest() {
    sendAction(CONTENT_REQUEST);
}

void BackendActionsCore::sendStart() {
    sendAction(CONTENT_START);
}

void BackendActionsCore::sendEnd() {
    sendAction(CONTENT_END);
}

void BackendActionsCore::sendPause() {
    sendAction(CONTENT_PAUSE);
}

void BackendActionsCore::sendResume() {
    sendAction(CONTENT_RESUME);
}

void BackendActionsCore::sendSeekStart() {
    sendAction(CONTENT_SEEK_START);
}

void BackendActionsCore::sendSeekEnd() {
    sendAction(CONTENT_SEEK_END);
}

void BackendActionsCore::sendBufferStart() {
    sendAction(CONTENT_BUFFER_START);
}

void BackendActionsCore::sendBufferEnd() {
    sendAction(CONTENT_BUFFER_END);
}

void BackendActionsCore::sendHeartbeat() {
    sendAction(CONTENT_HEARTBEAT);
}

void BackendActionsCore::sendRenditionChange() {
    sendAction(CONTENT_RENDITION_CHANGE);
}

void BackendActionsCore::sendError(std::string message) {
    // TODO: send error message
    /*
    message = message ? message : @"";
    [self sendAction:CONTENT_ERROR attr:@{@"errorMessage": message}];
     */
    sendAction(CONTENT_ERROR);
}

void BackendActionsCore::sendAdRequest() {
    sendAction(AD_REQUEST);
}

void BackendActionsCore::sendAdStart() {
    sendAction(AD_START);
}

void BackendActionsCore::sendAdEnd() {
    sendAction(AD_END);
}

void BackendActionsCore::sendAdPause() {
    sendAction(AD_PAUSE);
}

void BackendActionsCore::sendAdResume() {
    sendAction(AD_RESUME);
}

void BackendActionsCore::sendAdSeekStart() {
    sendAction(AD_SEEK_START);
}

void BackendActionsCore::sendAdSeekEnd() {
    sendAction(AD_SEEK_END);
}

void BackendActionsCore::sendAdBufferStart() {
    sendAction(AD_BUFFER_START);
}

void BackendActionsCore::sendAdBufferEnd() {
    sendAction(AD_BUFFER_END);
}

void BackendActionsCore::sendAdHeartbeat() {
    sendAction(AD_HEARTBEAT);
}

void BackendActionsCore::sendAdRenditionChange() {
    sendAction(AD_RENDITION_CHANGE);
}

void BackendActionsCore::sendAdError(std::string message) {
    sendAction(AD_ERROR);
    // TODO: send error message
    /*
    message = message ? message : @"";
    [self sendAction:AD_ERROR attr:@{@"errorMessage": message}];
     */
}

void BackendActionsCore::sendAdBreakStart() {
    sendAction(AD_BREAK_START);
}

void BackendActionsCore::sendAdBreakEnd() {
    sendAction(AD_BREAK_END);
}

void BackendActionsCore::sendAdQuartile() {
    sendAction(AD_QUARTILE);
}

void BackendActionsCore::sendAdClick() {
    sendAction(AD_CLICK);
}

void BackendActionsCore::sendPlayerReady() {
    sendAction(PLAYER_READY);
}

void BackendActionsCore::sendDownload() {
    sendAction(DOWNLOAD);
}

void BackendActionsCore::sendAction(std::string name) {
    sendAction(name, {});
}

void BackendActionsCore::sendAction(std::string name, std::map<std::string, ValueHolder> attr) {
    // TODO: https://stackoverflow.com/questions/35192561/a-map-in-c-which-can-accept-any-type-of-value
    recordCustomEvent(name, attr);
}

// TODO: dictionary stuff
