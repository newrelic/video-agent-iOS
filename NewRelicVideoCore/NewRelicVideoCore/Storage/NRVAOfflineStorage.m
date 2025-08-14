//
//  NRVAOfflineStorage.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAOfflineStorage.h"
#import "NRVAUtils.h"

#define kNRVAOfflineStorageCurrentSizeKey @"com.newrelic.videoAgent.offlineStorageCurrentSize"
#define kNRVA_Offline_folder @"com.newrelic.videoAgent.OfflinePayloads"

@implementation NRVAOfflineStorage {
    NSUInteger maxOfflineStorageSize;
    NSString *_name;
}

- (instancetype)initWithEndpoint:(NSString *)name {
    self = [super init];
    if (self) {
        _name = name;
        maxOfflineStorageSize = 100 * 1000000; // Default 100MB
    }
    return self;
}

- (void)createDirectory {
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self offlineDirectoryPath] isDirectory:nil];
    if (!fileExists) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[self offlineDirectoryPath] 
                                       withIntermediateDirectories:YES 
                                                        attributes:nil 
                                                             error:&error]) {
            NSLog(@"[NRVA] Failed to create directory \"%@\". Error: %@", [self offlineDirectoryPath], error);
        }
    }
}

- (BOOL)persistDataToDisk:(NSData *)data {
    @synchronized (self) {
        [self createDirectory];
        
        NSUInteger currentOfflineStorageSize = [[NSUserDefaults standardUserDefaults] integerForKey:kNRVAOfflineStorageCurrentSizeKey];
        currentOfflineStorageSize += data.length;
        
        if (currentOfflineStorageSize > maxOfflineStorageSize) {
            NSLog(@"[NRVA] Not saving to offline storage because max storage size has been reached.");
            return NO;
        }
        
        NSError *error = nil;
        if (data) {
            NSString *filePath = [self newOfflineFilePath];
            if ([data writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
                [[NSUserDefaults standardUserDefaults] setInteger:currentOfflineStorageSize forKey:kNRVAOfflineStorageCurrentSizeKey];
                double storageSizeKB = currentOfflineStorageSize / 1024.0;
                NSLog(@"[NRVA] Successfully persisted failed upload data to disk for offline storage. File: %@, Current offline storage: %.2f KB (%lu bytes)", filePath, storageSizeKB, (unsigned long)currentOfflineStorageSize);
                return YES;
            }
        }
        NSLog(@"[NRVA] Failed to persist data to disk %@", error.description);
        
        return NO;
    }
}

- (NSArray<NSData *> *)getAllOfflineData:(BOOL)clear {
    @synchronized (self) {
        NSMutableArray<NSData *> *combinedPosts = [NSMutableArray array];
        
        NSArray *dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self offlineDirectoryPath]
                                                                             error:NULL];
        [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *filename = (NSString *)obj;
            NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", [self offlineDirectoryPath], filename]];
            NSLog(@"[NRVA] Offline storage to be uploaded from %@", filename);
            
            [combinedPosts addObject:data];
        }];
        
        if (clear) {
            [self clearAllOfflineFiles];
        }
        
        return [combinedPosts copy];
    }
}

- (BOOL)clearAllOfflineFiles {
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self offlineDirectoryPath] isDirectory:nil]) {
        return YES;
    }
    
    NSError *error;
    if ([[NSFileManager defaultManager] removeItemAtPath:[self offlineDirectoryPath] error:&error]) {
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kNRVAOfflineStorageCurrentSizeKey];
        return YES;
    }
    NSLog(@"[NRVA] Failed to clear offline storage: %@", error);
    return NO;
}

+ (BOOL)clearAllOfflineDirectories {
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NRVAOfflineStorage allOfflineDirectorysPath] isDirectory:nil]) {
        return YES;
    }
    
    NSError *error;
    if ([[NSFileManager defaultManager] removeItemAtPath:[NRVAOfflineStorage allOfflineDirectorysPath] error:&error]) {
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kNRVAOfflineStorageCurrentSizeKey];
        return YES;
    }
    NSLog(@"[NRVA] Failed to clear offline storage: %@", error);
    return NO;
}

- (NSString *)offlineDirectoryPath {
    return [NSString stringWithFormat:@"%@/%@/%@", [self getStorePath], kNRVA_Offline_folder, _name];
}

+ (NSString *)allOfflineDirectorysPath {
    return [NSString stringWithFormat:@"%@/%@", [[[NRVAOfflineStorage alloc] init] getStorePath], kNRVA_Offline_folder];
}

- (NSString *)newOfflineFilePath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];

    return [NSString stringWithFormat:@"%@/%@%@", [self offlineDirectoryPath], date, @".txt"];
}

- (void)setMaxOfflineStorageSize:(NSUInteger)size {
    maxOfflineStorageSize = (size * 1000000);
}

+ (BOOL)checkErrorToPersist:(NSError *)error {
    return (error.code == NSURLErrorNotConnectedToInternet || 
            error.code == NSURLErrorTimedOut || 
            error.code == NSURLErrorCannotFindHost || 
            error.code == NSURLErrorNetworkConnectionLost || 
            error.code == NSURLErrorCannotConnectToHost);
}

- (NSString *)getStorePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:@"com.newrelic.videoAgent"];
}

@end
