//
//  ContentsTracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "Tracker.h"

/**
 `ContentsTrackerProtocol` defines the getters every `ContentsTracker` must or should implement.
 */
@protocol ContentsTrackerProtocol <TrackerProtocol>

@optional

/**
 Get speed of video playback, normalized to 1 (normal speed).
 */
- (NSNumber *)getPlayrate;

/**
 Get whether video playback is live or not.
 */
- (NSNumber *)getIsLive;

/**
 Get whether video is autoplayed or not.
 */
- (NSNumber *)getIsAutoplayed;

/**
 Get the video preload policy.
 */
- (NSString *)getPreload;

/**
 Get whether video is in full screen or not.
 */
- (NSNumber *)getIsFullscreen;

@end

/**
 `ContentsTracker` is the base class to manage the content events of a player.
 
 @warning Should never be instantiated directly, but subclassed.
 */
@interface ContentsTracker : NSObject <TrackerProtocol>

/**
 Current player tracker state.
 */
- (TrackerState)state;

/**
 Reset the tracker's state.
 */
- (void)reset;

/**
 Inititialize the tracker's state.
 */
- (void)setup;

/**
 Pre-send method, called right before any `send` method is executed.
 */
- (void)preSend;

/**
 Send a `_REQUEST` action.
 */
- (void)sendRequest;

/**
 Send a `_START` action.
 */
- (void)sendStart;

/**
 Send a `_END` action.
 */
- (void)sendEnd;

/**
 Send a `_PAUSE` action.
 */
- (void)sendPause;

/**
 Send a `_RESUME` action.
 */
- (void)sendResume;

/**
 Send a `_SEEK_START` action.
 */
- (void)sendSeekStart;

/**
 Send a `_SEEK_END` action.
 */
- (void)sendSeekEnd;

/**
 Send a `_BUFFER_START` action.
 */
- (void)sendBufferStart;

/**
 Send a `_BUFFER_END` action.
 */
- (void)sendBufferEnd;

/**
 Send a `_HEARTBEAT` action.
 */
- (void)sendHeartbeat;

/**
 Send a `_RENDITION_CHANGE` action.
 */
- (void)sendRenditionChange;

/**
 Send a `_ERROR` action.
 
 @param message Error message.
 */
- (void)sendError:(NSString *)message;

/**
 Send a `PLAYER_READY` action.
 */
- (void)sendPlayerReady;

/**
 Send a `DOWNLOAD` action.
 */
- (void)sendDownload;

/**
 Send a custom action.
 
 @param name Name of action.
 */
- (void)sendCustomAction:(NSString *)name;

/**
 Send a custom action.
 
 @param name Name of action.
 @param attr Dictionary of parameters sent along the action.
 */
- (void)sendCustomAction:(NSString *)name attr:(NSDictionary *)attr;

/**
 Set custom parameters for actions.
 
 @param opts Dictionary of parameters sent along the actions.
 */
- (void)setOptions:(NSDictionary *)opts;

/**
 Set custom single parameter for actions.
 
 @param key Name of parameter.
 @param value Value of parameter.
 */
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value;

/**
 Set custom parameters for a specific action.
 
 @param opts Dictionary of parameters sent along the actions.
 @param action Name of action.
 */
- (void)setOptions:(NSDictionary *)opts forAction:(NSString *)action;

/**
 Set custom single parameter for a specific action.
 
 @param key Name of parameter.
 @param value Value of parameter.
 @param action Name of action
 */
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action;

/**
 Start timer. Timer is used for heartbeats and other time dependant calculations.
 It is automatically started when a `sendRequest` happens and aborted when a `sendEnd`.
 */
- (void)startTimerEvent;

/**
 Abort timer.
 */
- (void)abortTimerEvent;

/**
 Timer handler. The method called everytime a timer event happens.
 */
- (void)trackerTimeEvent;

/**
 Set custom timestamp for a given timer attribute.
 
 @param timestamp Timestamp.
 @param attr Attribute name.
 @return True if attribute name is recognized, False if not.
 */
- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr;

@end
