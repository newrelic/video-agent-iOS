//
//  NRTrackerState.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 14/12/2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Holds the state of a tracker.
 */
@interface NRTrackerState : NSObject

/**
 Reset all states.
 */
- (void)reset;

/**
 Return state isPlayerReady.
 
 @return state..
 */
- (BOOL)isPlayerReady;

/**
 Return state isRequested.
 
 @return state..
 */
- (BOOL)isRequested;

/**
 Return state isStarted.
 
 @return state..
 */
- (BOOL)isStarted;

/**
 Return state isPlaying.
 
 @return state..
 */
- (BOOL)isPlaying;

/**
 Return state isPaused.
 
 @return state..
 */
- (BOOL)isPaused;

/**
 Return state isSeeking.
 
 @return state..
 */
- (BOOL)isSeeking;

/**
 Return state isBuffering.
 
 @return state..
 */
- (BOOL)isBuffering;

/**
 Return state isAd.
 
 @return state..
 */
- (BOOL)isAd;

/**
 Return state isAdBreak.
 
 @return state..
 */
- (BOOL)isAdBreak;

/**
 Set state isAd.
 
 @param isAd State.
 */
- (void)setIsAd:(BOOL)isAd;

/**
 Check to send event PLAYER_READY..
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goPlayerReady;

/**
 Check to send event REQUEST..
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goRequest;

/**
 Check to send event START..
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goStart;

/**
 Check to send event END..
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goEnd;

/**
 Check to send event PAUSE..
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goPause;

/**
 Check to send event RESUME.
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goResume;

/**
 Check to send event BUFFER_START.
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goBufferStart;

/**
 Check to send event BUFFER_END.
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goBufferEnd;

/**
 Check to send event SEEK_START.
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goSeekStart;

/**
 Check to send event SEEK_END.
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goSeekEnd;

/**
 Check to send event AD_BREAK_START.
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goAdBreakStart;

/**
 Check to send event AD_BREAK_END.
 
 @return True if state changed. False otherwise.
 */
- (BOOL)goAdBreakEnd;

@end

NS_ASSUME_NONNULL_END
