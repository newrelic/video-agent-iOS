//
//  GettersCAL.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 30/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GettersCAL : NSObject

+ (void)registerGetter:(NSString *)name target:(id)target sel:(SEL)selector;

void registerGetter(NSString *name, id target, SEL selector);

@end
