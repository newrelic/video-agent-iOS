//
//  TrackerProtocol.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 24/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TrackerProtocol <NSObject>

@required
- (void)reset;
- (void)setup;

@optional

@end
