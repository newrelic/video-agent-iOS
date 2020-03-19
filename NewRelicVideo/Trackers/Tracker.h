//
//  Tracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, TrackerState) {
    /** Tracker state Stopped */
    TrackerStateStopped = 0,
    /** Tracker state Starting */
    TrackerStateStarting,
    /** Tracker state Playing */
    TrackerStatePlaying,
    /** Tracker state Paused */
    TrackerStatePaused,
    /** Tracker state Buffering */
    TrackerStateBuffering,
    /** Tracker state Seeking */
    TrackerStateSeeking
};

/**
 `TrackerProtocol` defines the basic getters every Tracker must or should implement.
 */
@protocol TrackerProtocol <NSObject>

@optional

/**
 Stop current item.
 */
- (void)stop;

@required

/**
 Get tracker name.
 */
- (NSString *)getTrackerName;

/**
 Get tracker version.
 */
- (NSString *)getTrackerVersion;

/**
 Get player version.
 */
- (NSString *)getPlayerVersion;

/**
 Get player name.
 */
- (NSString *)getPlayerName;

/**
 Get whether it is an Ads tracker or not.
 */
- (NSNumber *)getIsAd;

/**
 Register a getter method.
 
 @param name Name of getter.
 @param selector Selector.
 */
- (void)registerGetter:(NSString *)name sel:(SEL)selector;

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
 
 @param error Error object.
 */
- (void)sendError:(NSError *)error;

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
 Set custom single parameter for actions.
 
 @param key Name of parameter.
 @param value Value of parameter.
 */
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value;

/**
 Set custom single parameter for a specific action.
 
 @param key Name of parameter.
 @param value Value of parameter.
 @param action Name of action.
 */
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action;

/**
 Set custom timestamp for a given timer attribute.
 
 @param timestamp Timestamp.
 @param attr Attribute name.
 @return True if attribute name is recognized, False if not.
 */
- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr;

/**
 Enable heartbeats.
 */
- (void)enableHeartbeat;

/**
 Disable heartbeats.
 */
- (void)disableHeartbeat;

/**
 Set custom time for heartbeat.
 
 @param seconds Time in seconds. Minimum 5 seconds.
 */
- (void)setHeartbeatTime:(int)seconds;

@optional

/**
 Get video ID.
 */
- (NSString *)getVideoId;

/**
 Get video title.
 */
- (NSString *)getTitle;

/**
 Get video bitrate in bits per second.
 */
- (NSNumber *)getBitrate;

/**
 Get video rendition name.
 */
- (NSString *)getRenditionName;

/**
 Get video rendition bitrate in bits per second.
 */
- (NSNumber *)getRenditionBitrate;

/**
 Get video width.
 */
- (NSNumber *)getRenditionWidth;

/**
 Get video height.
 */
- (NSNumber *)getRenditionHeight;

/**
 Get video duration in milliseconds.
 */
- (NSNumber *)getDuration;

/**
 Get current playback position in milliseconds.
 */
- (NSNumber *)getPlayhead;

/**
 Get video language.
 */
- (NSString *)getLanguage;

/**
 Get video source. Usually a URL.
 */
- (NSString *)getSrc;

/**
 Get whether video is muted or not.
 */
- (NSNumber *)getIsMuted;

/**
 Get name of the CDN serving content.
 */
- (NSString *)getCdn;

/**
 Get video frames per second.
 */
- (NSNumber *)getFps;

@end
