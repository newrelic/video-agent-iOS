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

#pragma mark - Methods to work with background events persiistence

+ (NSMutableArray *)readPlist:(NSString *)fileName {
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docsDir stringByAppendingFormat:@"/%@.plist", fileName];
    NSMutableArray *arr = [NSMutableArray arrayWithContentsOfFile:path];
    return arr == nil ? @[].mutableCopy : arr;
}

+ (BOOL)writeArray:(NSMutableArray *)array toPlist:(NSString *)fileName {
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docsDir stringByAppendingFormat:@"/%@.plist", fileName];
    NSError *err;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:array
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&err];
    if (!err) {
        return [data writeToFile:path atomically:YES];
    }
    else {
        AV_LOG(@"Error while writing the file: %@", err);
        return NO;
    }
}

+ (BOOL)plistExists:(NSString *)fileName {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docsDir stringByAppendingFormat:@"/%@.plist", fileName];
    
    if ([fileManager fileExistsAtPath:path]) {
        return YES;
    }
    else {
        return NO;
    }
}

+ (BOOL)removePlist:(NSString *)fileName {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docsDir stringByAppendingFormat:@"/%@.plist", fileName];
    
    if ([fileManager fileExistsAtPath:path]) {
        NSError *err;
        BOOL ret = [fileManager removeItemAtPath:path error:&err];
        if (err) {
            AV_LOG(@"Error while deleting the file: %@", err);
        }
        return ret;
    }
    else {
        return NO;
    }
}

@end
