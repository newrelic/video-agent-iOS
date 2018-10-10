//
//  Vars.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 29/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "Vars.h"

@implementation Vars

+ (NSBundle *)bundle {
    return [NSBundle mainBundle];
}

+ (NSString *)string:(NSString *)key {
    NSString *str = [[self bundle] objectForInfoDictionaryKey:key];
    return str;
}

+ (NSURL *)url:(NSString *)key {
    NSString *urlAddress = [[self bundle] objectForInfoDictionaryKey:key];
    NSURL *url = [NSURL URLWithString:urlAddress];
    return url;
}

+ (NSNumber *)appNumber:(NSString *)key {
    NSNumber *num = [[self bundle] objectForInfoDictionaryKey:key];
    return num;
}

@end
