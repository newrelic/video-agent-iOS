//
//  PlaybackAutomat.cpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 25/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#include "PlaybackAutomatCore.hpp"
#include "BackendActionsCore.hpp"

PlaybackAutomatCore::PlaybackAutomatCore() {
    state = CoreTrackerStateStopped;
    actions = new BackendActionsCore();
}

PlaybackAutomatCore::~PlaybackAutomatCore() {
    delete actions;
}

BackendActionsCore *PlaybackAutomatCore::getActions() {
    return actions;
}

void PlaybackAutomatCore::sendRequest() {
    if (transition(CoreTrackerTransitionClickPlay)) {
        if (!isAd) {
            actions->sendRequest();
        }
        else {
            actions->sendAdRequest();
        }
    }
}

void PlaybackAutomatCore::sendStart() {
    if (transition(CoreTrackerTransitionFrameShown)) {
        if (!isAd) {
            actions->sendStart();
        }
        else {
            actions->sendAdStart();
        }
    }
}

void PlaybackAutomatCore::sendEnd() {
    if (!isAd) {
        actions->sendEnd();
    }
    else {
        actions->sendAdEnd();
    }
    
    stateStack = std::stack<CoreTrackerState>();
    moveState(CoreTrackerStateStopped);
}

void PlaybackAutomatCore::sendPause() {
    if (transition(CoreTrackerTransitionClickPause)) {
        if (!isAd) {
            actions->sendPause();
        }
        else {
            actions->sendAdPause();
        }
    }
}

void PlaybackAutomatCore::sendResume() {
    if (transition(CoreTrackerTransitionClickPlay)) {
        if (!isAd) {
            actions->sendResume();
        }
        else {
            actions->sendAdResume();
        }
    }
}

void PlaybackAutomatCore::sendSeekStart() {
    if (!isAd) {
        actions->sendSeekStart();
    }
    else {
        actions->sendAdSeekStart();
    }
    
    moveStateAndPush(CoreTrackerStateSeeking);
}

void PlaybackAutomatCore::sendSeekEnd() {
    if (transition(CoreTrackerTransitionEndDraggingSlider)) {
        if (!isAd) {
            actions->sendSeekEnd();
        }
        else {
            actions->sendAdSeekEnd();
        }
    }
}

void PlaybackAutomatCore::sendBufferStart() {
    if (!isAd) {
        actions->sendBufferStart();
    }
    else {
        actions->sendAdBufferStart();
    }
    
    moveStateAndPush(CoreTrackerStateBuffering);
}

void PlaybackAutomatCore::sendBufferEnd() {
    if (transition(CoreTrackerTransitionEndBuffering)) {
        if (!isAd) {
            actions->sendBufferEnd();
        }
        else {
            actions->sendAdBufferEnd();
        }
    }
}

void PlaybackAutomatCore::sendHeartbeat() {
    if (!isAd) {
        actions->sendHeartbeat();
    }
    else {
        actions->sendAdHeartbeat();
    }
}

void PlaybackAutomatCore::sendRenditionChange() {
    if (!isAd) {
        actions->sendRenditionChange();
    }
    else {
        actions->sendAdRenditionChange();
    }
}

void PlaybackAutomatCore::sendError(std::string message) {
    if (!isAd) {
        actions->sendError(message);
    }
    else {
        actions->sendAdError(message);
    }
}

bool PlaybackAutomatCore::transition(CoreTrackerTransition tt) {
    
//    AV_LOG(@">>>> TRANSITION %lu", (unsigned long)tt);
    
    switch (state) {
        default:
        case CoreTrackerStateStopped: {
            return performTransitionInStateStopped(tt);
        }
            
        case CoreTrackerStateStarting: {
            return performTransitionInStateStarting(tt);
        }
            
        case CoreTrackerStatePaused: {
            return performTransitionInStatePaused(tt);
        }
            
        case CoreTrackerStatePlaying: {
            return performTransitionInStatePlaying(tt);
        }
            
        case CoreTrackerStateSeeking: {
            return performTransitionInStateSeeking(tt);
        }
            
        case CoreTrackerStateBuffering: {
            return performTransitionInStateBuffering(tt);
        }
    }
}

bool PlaybackAutomatCore::performTransitionInStateStopped(CoreTrackerTransition tt) {
    if (tt == CoreTrackerTransitionAutoplay || tt == CoreTrackerTransitionClickPlay) {
        moveState(CoreTrackerStateStarting);
        return true;
    }
    return false;
}

bool PlaybackAutomatCore::performTransitionInStateStarting(CoreTrackerTransition tt) {
    if (tt == CoreTrackerTransitionFrameShown) {
        moveState(CoreTrackerStatePlaying);
        return true;
    }
    return false;
}

bool PlaybackAutomatCore::performTransitionInStatePlaying(CoreTrackerTransition tt) {
    if (tt == CoreTrackerTransitionClickPause) {
        moveState(CoreTrackerStatePaused);
        return true;
    }
    return false;
}

bool PlaybackAutomatCore::performTransitionInStatePaused(CoreTrackerTransition tt) {
    if (tt == CoreTrackerTransitionClickPlay) {
        moveState(CoreTrackerStatePlaying);
        return true;
    }
    return false;
}

bool PlaybackAutomatCore::performTransitionInStateSeeking(CoreTrackerTransition tt) {
    if (tt == CoreTrackerTransitionEndDraggingSlider) {
        backToState();
        return true;
    }
    // NOTE: just in case seeking gets lost and SEEK_END never arrives. In AVPlayer happens with big videos in streaming
    else if (tt == CoreTrackerTransitionClickPlay) {
        backToState();
        moveState(CoreTrackerStatePlaying);
        return true;
    }
    else if (tt == CoreTrackerTransitionClickPause) {
        backToState();
        moveState(CoreTrackerStatePaused);
        return true;
    }
    return false;
}

bool PlaybackAutomatCore::performTransitionInStateBuffering(CoreTrackerTransition tt) {
    if (tt == CoreTrackerTransitionEndBuffering) {
        backToState();
        return true;
    }
    return false;
}

void PlaybackAutomatCore::moveState(CoreTrackerState newState) {
    state = newState;
}

void PlaybackAutomatCore::moveStateAndPush(CoreTrackerState newState) {
    if (newState != state) {
        stateStack.push(state);
        state = newState;
    }
}

void PlaybackAutomatCore::backToState() {
    if (stateStack.size() > 0) {
        state = stateStack.top();
        stateStack.pop();
    }
    else {
//        AV_LOG(@"STATE STACK UNDERUN!");
    }
}
