//
//  NewRelicVideoAgent.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NewRelicVideoAgent : NSObject

/*!
 Starts New Relic Video data collection for "player"
 
 Call this after having initialized the NewRelicAgent.
 */
+ (void)startWithPlayer:(id)player;

@end
