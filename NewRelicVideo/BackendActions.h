//
//  BackendActions.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BackendActions : NSObject

- (void)sendResume;
- (void)sendPause;
- (void)sendBufferEnd;
- (void)sendBufferStart;
- (void)sendError;
- (void)sendRequest;
- (void)sendStart:(NSTimeInterval)timeToStart;
- (void)sendEnd;

@end
