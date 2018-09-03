//
//  NSMutableArray+Stack.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray<ObjectType> (Stack)

- (void)push:(nullable ObjectType)item;
- (nullable ObjectType)pop;
- (nullable ObjectType)peek;
@end
