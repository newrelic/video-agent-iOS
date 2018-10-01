//
//  TimestampValue.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 28/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TimestampValue : NSObject

@property (nonatomic) NSTimeInterval timestamp;

+ (instancetype)build:(NSTimeInterval)timestamp;
- (void)setMain:(NSTimeInterval)timestamp;
- (void)setExternal:(NSTimeInterval)timestamp;
- (NSTimeInterval)sinceMillis;

@end
