//
//  AVPlayerTracker.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TrackerProtocol.h"

@class AVPlayer;

@interface AVPlayerTracker : NSObject <TrackerProtocol>

- (instancetype)initWithAVPlayer:(AVPlayer *)player;

@end
