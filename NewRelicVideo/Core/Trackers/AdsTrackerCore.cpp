//
//  AdsTrackerCore.cpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/11/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#include "AdsTrackerCore.hpp"
#include "TrackerCore.hpp"

AdsTrackerCore::AdsTrackerCore(ContentsTracker *contentsTracker) {}

AdsTrackerCore::~AdsTrackerCore() {}

// Overwritten from TrackerCore
void AdsTrackerCore::reset() {}

void AdsTrackerCore::preSend() {}

void AdsTrackerCore::sendRequest() {}

void AdsTrackerCore::sendStart() {}

void AdsTrackerCore::sendEnd() {}

void AdsTrackerCore::sendPause() {}

void AdsTrackerCore::sendResume() {}

void AdsTrackerCore::sendSeekStart() {}

void AdsTrackerCore::sendSeekEnd() {}

void AdsTrackerCore::sendBufferStart() {}

void AdsTrackerCore::sendBufferEnd() {}

void AdsTrackerCore::sendHeartbeat() {}

void AdsTrackerCore::sendRenditionChange() {}

void AdsTrackerCore::sendError(std::string message) {}

void AdsTrackerCore::sendPlayerReady() {}

void AdsTrackerCore::sendDownload() {}

void AdsTrackerCore::sendCustomAction(std::string name) {}

void AdsTrackerCore::sendCustomAction(std::string name, std::map<std::string, ValueHolder> attr) {}

bool AdsTrackerCore::setTimestamp(double timestamp, std::string attributeName) {
    return TrackerCore::setTimestamp(timestamp, attributeName);
}

// Specific AdsTracker methods
void AdsTrackerCore::sendAdBreakStart() {}

void AdsTrackerCore::sendAdBreakEnd() {}

void AdsTrackerCore::sendAdQuartile() {}

void AdsTrackerCore::sendAdClick() {}
