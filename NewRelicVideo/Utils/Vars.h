//
//  Vars.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 29/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Vars : NSObject

+ (NSString *)string:(NSString *)key;
+ (NSURL *)url:(NSString *)key;

@end
