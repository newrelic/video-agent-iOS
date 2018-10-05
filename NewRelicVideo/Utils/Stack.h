//
//  Stack.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 05/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Stack <ObjectType> : NSObject

- (void)push:(nullable ObjectType)item;
- (nullable ObjectType)pop;
- (nullable ObjectType)peek;
- (NSUInteger)count;
- (void)clear;

@end
