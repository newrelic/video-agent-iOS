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
+ (NSNumber *)appNumber:(NSString *)key;
+ (NSMutableArray *)readPlist:(NSString *)fileName;
+ (BOOL)writeArray:(NSMutableArray *)array toPlist:(NSString *)fileName;
+ (BOOL)plistExists:(NSString *)fileName;
+ (BOOL)removePlist:(NSString *)fileName;

@end
