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
    return [NSBundle bundleWithIdentifier:@"com.newrelic.NewRelicVideo"];
}

+ (NSString *)stringFromPlist:(NSString *)key {
    NSString *str = [[self bundle] objectForInfoDictionaryKey:key];
    return str;
}

+ (NSURL *)urlFromPlist:(NSString *)key {
    NSString *urlAddress = [[self bundle] objectForInfoDictionaryKey:key];
    NSURL *url = [NSURL URLWithString:urlAddress];
    return url;
}

@end
