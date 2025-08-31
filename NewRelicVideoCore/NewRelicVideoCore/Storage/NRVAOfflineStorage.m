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

- (NSInteger)getEventCount {
    @synchronized (self) {
        NSInteger eventCount = 0;
        
        // Check if offline directory exists
        if (![[NSFileManager defaultManager] fileExistsAtPath:[self offlineDirectoryPath] isDirectory:nil]) {
            return 0;
        }
        
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self offlineDirectoryPath] error:NULL];
        
        for (NSString *filename in files) {
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", [self offlineDirectoryPath], filename];
            NSData *data = [NSData dataWithContentsOfFile:filePath];
            
            if (data) {
                @try {
                    NSArray *events = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if ([events isKindOfClass:[NSArray class]]) {
                        eventCount += events.count;
                    } else {
                        // Single event stored as object
                        eventCount += 1;
                    }
                } @catch (NSException *exception) {
                    // Skip corrupted files
                    NSLog(@"[NRVA] Failed to parse offline file %@: %@", filename, exception.reason);
                }
            }
        }
        
        return eventCount;
    }
}

#pragma mark - Selective File Management

- (NSArray<NSString *> *)getAllOfflineFileNames {
    @synchronized (self) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:[self offlineDirectoryPath] isDirectory:nil]) {
            return @[];
        }
        
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self offlineDirectoryPath] error:NULL];
        return [files sortedArrayUsingSelector:@selector(compare:)]; // FIFO order
    }
}

- (NSData *)getDataFromFile:(NSString *)filename {
    @synchronized (self) {
        if (!filename || filename.length == 0) return nil;
        
        NSString *filePath = [NSString stringWithFormat:@"%@/%@", [self offlineDirectoryPath], filename];
        return [[NSFileManager defaultManager] fileExistsAtPath:filePath] ? [NSData dataWithContentsOfFile:filePath] : nil;
    }
}

- (BOOL)clearSpecificFiles:(NSArray<NSString *> *)filenames {
    @synchronized (self) {
        if (!filenames || filenames.count == 0) return YES;
        
        NSUInteger totalSizeReduced = 0;
        for (NSString *filename in filenames) {
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", [self offlineDirectoryPath], filename];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                NSUInteger fileSize = [attributes fileSize];
                
                if ([[NSFileManager defaultManager] removeItemAtPath:filePath error:nil]) {
                    totalSizeReduced += fileSize;
                    NSLog(@"[NRVA] Cleared offline file: %@", filename);
                }
            }
        }
        
        // Update storage tracking
        if (totalSizeReduced > 0) {
            NSUInteger currentSize = [[NSUserDefaults standardUserDefaults] integerForKey:kNRVAOfflineStorageCurrentSizeKey];
            currentSize = (currentSize >= totalSizeReduced) ? currentSize - totalSizeReduced : 0;
            [[NSUserDefaults standardUserDefaults] setInteger:currentSize forKey:kNRVAOfflineStorageCurrentSizeKey];
        }
        
        return totalSizeReduced > 0;
    }
}

#pragma mark - Clean Event-Level Processing

- (NSArray<NSDictionary *> *)getUnprocessedEventsFromFile:(NSString *)filename maxEvents:(NSInteger)maxEvents {
    @synchronized (self) {
        NSData *data = [self getDataFromFile:filename];
        if (!data) return @[];
        
        @try {
            NSArray *allEvents = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![allEvents isKindOfClass:[NSArray class]]) {
                allEvents = allEvents ? @[allEvents] : @[];
            }
            
            // Filter unprocessed events and limit count
            NSMutableArray *unprocessedEvents = [[NSMutableArray alloc] init];
            for (NSDictionary *event in allEvents) {
                if (unprocessedEvents.count >= maxEvents) break;
                
                // Skip events marked as processed
                if (![event[@"_processed"] boolValue]) {
                    [unprocessedEvents addObject:event];
                }
            }
            
            NSLog(@"[NRVA] File %@: found %ld unprocessed events (limit: %ld)", 
                  filename, (long)unprocessedEvents.count, (long)maxEvents);
            
            return [unprocessedEvents copy];
            
        } @catch (NSException *exception) {
            NSLog(@"[NRVA] Failed to parse file %@: %@", filename, exception.reason);
            return @[];
        }
    }
}

- (BOOL)removeProcessedEventsFromFile:(NSString *)filename {
    @synchronized (self) {
        NSData *data = [self getDataFromFile:filename];
        if (!data) return NO;
        
        @try {
            NSArray *allEvents = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![allEvents isKindOfClass:[NSArray class]]) {
                allEvents = allEvents ? @[allEvents] : @[];
            }
            
            // Keep only unprocessed events
            NSMutableArray *unprocessedEvents = [[NSMutableArray alloc] init];
            NSInteger processedCount = 0;
            
            for (NSDictionary *event in allEvents) {
                if ([event[@"_processed"] boolValue]) {
                    processedCount++;
                } else {
                    [unprocessedEvents addObject:event];
                }
            }
            
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", [self offlineDirectoryPath], filename];
            
            if (unprocessedEvents.count == 0) {
                // No unprocessed events left - delete entire file
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                NSLog(@"[NRVA] File %@ fully processed - deleted", filename);
                return YES;
            } else {
                // Update file with remaining unprocessed events
                NSData *updatedData = [NSJSONSerialization dataWithJSONObject:unprocessedEvents options:0 error:nil];
                BOOL success = [updatedData writeToFile:filePath atomically:YES];
                NSLog(@"[NRVA] File %@: removed %ld processed events, %ld remaining", 
                      filename, (long)processedCount, (long)unprocessedEvents.count);
                return success;
            }
            
        } @catch (NSException *exception) {
            NSLog(@"[NRVA] Failed to update file %@: %@", filename, exception.reason);
            return NO;
        }
    }
}

@end
