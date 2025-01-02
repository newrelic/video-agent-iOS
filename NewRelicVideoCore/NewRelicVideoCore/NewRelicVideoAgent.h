//
//  NewRelicVideoAgent.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NRTracker;

/**
 `NewRelicVideoAgent` contains the methods to start the Video Agent and access tracker instances.
 */
@interface NewRelicVideoAgent : NSObject

/**
 Get shared instance.
 
 @return Shared instance.
 */
+ (instancetype)sharedInstance;

/**
 Get session ID.
 
 @return Session ID.
 */
- (NSString *)sessionId;


/**
 Sets User ID.
 */
- (void)setUserId:(NSString *)userId;

/**
 Set logging state.
 
 @param state YES or NO.
 */
- (void)setLogging:(BOOL)state;

/**
 Get logging state.
 
 @return The logging state.
 */
- (BOOL)logging;

/**
 Start a contant tracker.
 
 @param contentTracker Tracker instance for contents.
 @return Tracker ID.
 */
- (NSNumber *)startWithContentTracker:(NRTracker *)contentTracker;

/**
 Start a contant and an ad tracker.
 
 @param contentTracker Tracker instance for contents.
 @param adTracker Tracker instance for ads.
 @return Tracker ID.
 */
- (NSNumber *)startWithContentTracker:(nullable NRTracker *)contentTracker adTracker:(nullable NRTracker *)adTracker;

/**
 Release a tracker.
 
 @param trackerId Tracker ID.
 */
- (void)releaseTracker:(NSNumber *)trackerId;

/**
 Get content tracker.
 
 @param trackerId Tracker ID.
 @return Content tracker.
 */
- (nullable NRTracker *)contentTracker:(NSNumber *)trackerId;

/**
 Get ad tracker.
 
 @param trackerId Tracker ID.
 @return Content tracker.
 */
- (nullable NRTracker *)adTracker:(NSNumber *)trackerId;

@end

NS_ASSUME_NONNULL_END
