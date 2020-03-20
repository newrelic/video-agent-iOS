//
//  GCastTracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContentsTracker.h"

@class GCKSessionManager;
@class GCKRequest;

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
 Set the GCKRequest instance.
 
 @param request GCKRequest object.
 */
- (void)setMediaRequestInstance:(GCKRequest *)request;

@end
