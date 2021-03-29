//
//  NRVideoTracker.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 14/12/2020.
//

#import <NewRelicVideoCore/NRTracker.h>
#import <NewRelicVideoCore/NRTrackerState.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Defines the basic behaviour of a video tracker.
 */
@interface NRVideoTracker : NRTracker

/**
 Return tracker state.
 
 @return Tracker state..
 */
- (NRTrackerState *)state;

/**
 Set player.
 
 @param player Player instance.
 */
- (void)setPlayer:(id)player;

/**
 Set number of ads.
 
 @param number Number of ads.
 */
- (void)setNumberOfAds:(int)number;

/**
 Start heartbeat timer.
 */
- (void)startHeartbeat;

/**
 Stop heartbeat timer.
 */
- (void)stopHeartbeat;

/**
 Set heartbeat interval.
 
 @param seconds Time interval in seconds. Min 1 second.  0 disables HB.
 */
- (void)setHeartbeatTime:(int)seconds;

/**
 Send request event.
 */
- (void)sendRequest;

/**
 Send start event.
 */
- (void)sendStart;

/**
 Send pause event.
 */
- (void)sendPause;

/**
 Send resume event.
 */
- (void)sendResume;

/**
 Send end event.
 */
- (void)sendEnd;

/**
 Send seek start event.
 */
- (void)sendSeekStart;

/**
 Send seek end event.
 */
- (void)sendSeekEnd;

/**
 Send buffer start event.
 */
- (void)sendBufferStart;

/**
 Send buffer start event.
 */
- (void)sendBufferEnd;

/**
 Send heartbeat event.
 */
- (void)sendHeartbeat;

/**
 Send rendition change event.
 */
- (void)sendRenditionChange;

/**
 Send error event.
 */
- (void)sendError;

/**
 Send error event with an error object.
 
 @param error Error instance.
 */
- (void)sendError:(nullable NSError *)error;

/**
 Send ad break start event.
 */
- (void)sendAdBreakStart;

/**
 Send ad break end event.
 */
- (void)sendAdBreakEnd;

/**
 Send ad quartile event.
 */
- (void)sendAdQuartile;

/**
 Send ad click event.
 */
- (void)sendAdClick;

/**
 Tracker is for Ads or not. To be overwritten by a subclass that inplements an Ads tracker.
 
 @return True if tracker is for Ads. Default False.
 */
- (NSNumber *)getIsAd;

/**
 Get the tracker version.
 
 @return Attribute.
 */
- (NSString *)getTrackerVersion;

/**
 Get the tracker name.
 
 @return Attribute.
 */
- (NSString *)getTrackerName;

/**
 Get player version.
 
 @return Attribute.
 */
- (NSString *)getPlayerVersion;

/**
 Get player name.
 */
- (NSString *)getPlayerName;

/**
 Get video title.
 
 @return Attribute.
 */
- (NSString *)getTitle;

/**
 Get video bitrate in bits per second.
 
 @return Attribute.
 */
- (NSNumber *)getBitrate;

/**
 Get video rendition bitrate in bits per second.
 
 @return Attribute.
 */
- (NSNumber *)getRenditionBitrate;

/**
 Get video width.
 
 @return Attribute.
 */
- (NSNumber *)getRenditionWidth;

/**
 Get video height.
 
 @return Attribute.
 */
- (NSNumber *)getRenditionHeight;

/**
 Get video duration in milliseconds.
 
 @return Attribute.
 */
- (NSNumber *)getDuration;

/**
 Get current playback position in milliseconds.
 
 @return Attribute.
 */
- (NSNumber *)getPlayhead;

/**
 Get video language.
 
 @return Attribute.
 */
- (NSString *)getLanguage;

/**
 Get video source. Usually a URL.
 
 @return Attribute.
 */
- (NSString *)getSrc;

/**
 Get whether video is muted or not.
 
 @return Attribute.
 */
- (NSNumber *)getIsMuted;

/**
 Get video frames per second.
 
 @return Attribute.
 */
- (NSNumber *)getFps;

/**
 Get whether video playback is live or not.
 
 @return Attribute.
 */
- (NSNumber *)getIsLive;

/**
 Get Ad creative ID.
 
 @return Attribute.
 */
- (NSString *)getAdCreativeId;

/**
 Get Ad position, pre, mid or post.
 
 @return Attribute.
 */
- (NSString *)getAdPosition;

/**
 Get Ad quartile.
 
 It is 0 before first, 1 after first quartile, 2 after midpoint, 3 after third quartile, 4 when completed.
 
 @return Attribute.
 */
- (NSNumber *)getAdQuartile;

/**
 Get ad partner name.
 
 @return Attribute.
 */
- (NSString *)getAdPartner;

/**
 Get ad break id.
 
 @return Attribute.
 */
- (NSString *)getAdBreakId;

/**
 Get total ad playtime of the last ad break.
 
 @return Attribute.
 */
- (NSNumber *)getTotalAdPlaytime;

/**
 Get view session.
 
 @return Attribute.
 */
- (NSString *)getViewSession;

/**
 Get view ID.
 
 @return Attribute.
 */
- (NSString *)getViewId;

/**
 Get video ID.
 
 @return Attribute.
 */
- (NSString *)getVideoId;

/**
 Get bufferType.
 
 @return Attribute.
 */
- (NSString *)getBufferType;

/**
 Notify that an Ad just ended.
 */
- (void)adHappened;

@end

NS_ASSUME_NONNULL_END
