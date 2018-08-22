//
//  NewRelicVideoAgent.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVPlayer;

@interface NewRelicVideoAgent : NSObject

/*!
 Starts New Relic Video data collection for AVPlayer class.
 
 Call this after having initialized the NewRelicAgent.
 */
+ (void)startWithAVPlayer:(AVPlayer *)player;

@end
