//
//  GCastTracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContentsTracker.h"

@class GCKSessionManager;

/**
 `GCastTracker` is the base class to manage the content events of a GoogleCast. It can be used directly or subclassed.
 */
@interface GCastTracker : ContentsTracker <ContentsTrackerProtocol>

/**
 Create a `GCastTracker` instance using a `GCKSessionManager` instance.
 
 @param sessionManager The `GCKSessionManager` object.
 */
- (instancetype)initWithGoogleCast:(GCKSessionManager *)sessionManager;

/**
 Set the isAutoplayed state, since AVPlayer doesn't offer a method to obtain it.
 
 @param state A boolean `NSNumber` to indicate whether it is autpolayed or not.
 */
- (void)setIsAutoplayed:(NSNumber *)state;

@end
