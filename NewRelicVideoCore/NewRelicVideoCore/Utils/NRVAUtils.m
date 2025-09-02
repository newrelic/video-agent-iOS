//
//  NRVAUtils.m
//  NewRelicVideoCore
//
//  Video agent utility functions
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRVAUtils.h"

@implementation NRVAUtils

+ (BOOL)isTVDevice {
    #if TARGET_OS_TV
        return YES;
    #else
        return NO;
    #endif
}

+ (NSString *)osName {
    #if TARGET_OS_TV
        return @"tvOS";
    #else
        return @"iOS";
    #endif
}

+ (NSString *)deviceModel {
    return [[UIDevice currentDevice] model];
}

+ (NSString *)generateSessionId {
    return [[NSProcessInfo processInfo] globallyUniqueString];
}

@end
