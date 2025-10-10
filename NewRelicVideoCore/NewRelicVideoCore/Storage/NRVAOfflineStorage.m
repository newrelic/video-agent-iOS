//
//  NRVAOfflineStorage.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAOfflineStorage.h"
#import "NRVAUtils.h"
#import "NRVALog.h"

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

- (instancetype)initWithEndpoint:(NSString *)name maxStorageSizeMB:(NSUInteger)maxStorageSizeMB {
    self = [super init];
    if (self) {
        _name = name;
        maxOfflineStorageSize = maxStorageSizeMB * 1000000; // Convert MB to bytes
        NRVA_DEBUG_LOG(@"NRVAOfflineStorage initialized with endpoint '%@' and max storage size %lu MB (%lu bytes)", 
                      name, (unsigned long)maxStorageSizeMB, (unsigned long)maxOfflineStorageSize);
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
            NRVA_DEBUG_LOG(@"Failed to create directory \"%@\". Error: %@", [self offlineDirectoryPath], error);
        }
    }
}

- (BOOL)persistDataToDisk:(NSData *)data {
    @synchronized (self) {
        [self createDirectory];
        
        NSUInteger currentOfflineStorageSize = [[NSUserDefaults standardUserDefaults] integerForKey:kNRVAOfflineStorageCurrentSizeKey];
        currentOfflineStorageSize += data.length;
        
        if (currentOfflineStorageSize > maxOfflineStorageSize) {
            NRVA_DEBUG_LOG(@"Not saving to offline storage because max storage size has been reached.");
            return NO;
        }
        
        NSError *error = nil;
        if (data) {
            NSString *filePath = [self newOfflineFilePath];
            if ([data writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
                [[NSUserDefaults standardUserDefaults] setInteger:currentOfflineStorageSize forKey:kNRVAOfflineStorageCurrentSizeKey];
                double storageSizeKB = currentOfflineStorageSize / 1024.0;
                 NRVA_DEBUG_LOG(@"Successfully persisted failed upload data to disk for offline storage. File: %@, Current offline storage: %.2f KB (%lu bytes), Total events stored: %ld", filePath, storageSizeKB, (unsigned long)currentOfflineStorageSize, (long)[self getEventCount]);
                return YES;
            }
        }
        NRVA_DEBUG_LOG(@"Failed to persist data to disk %@", error.description);
        
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
            NRVA_DEBUG_LOG(@"Offline storage to be uploaded from %@", filename);
            
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
    NRVA_DEBUG_LOG(@"Failed to clear offline storage: %@", error);
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
    NRVA_DEBUG_LOG(@"Failed to clear offline storage: %@", error);
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
                    NRVA_DEBUG_LOG(@"Failed to parse offline file %@: %@", filename, exception.reason);
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
                    NRVA_DEBUG_LOG(@"Cleared offline file: %@", filename);
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

// EFFICIENT: Simple poll-and-remove method (uses FIFO - no priority separation)
- (NSArray<NSDictionary *> *)pollAndRemoveEventsFromFile:(NSString *)filename maxEvents:(NSInteger)maxEvents {
    @synchronized (self) {
        NSData *data = [self getDataFromFile:filename];
        if (!data) return @[];
        
        @try {
            NSArray *allEvents = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![allEvents isKindOfClass:[NSArray class]]) {
                allEvents = allEvents ? @[allEvents] : @[];
            }
            
            // Take up to maxEvents from the beginning (FIFO - mixed live/ondemand)
            NSInteger eventsToTake = MIN(maxEvents, allEvents.count);
            NSArray *polledEvents = [allEvents subarrayWithRange:NSMakeRange(0, eventsToTake)];
            
            // Remove polled events from file
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", [self offlineDirectoryPath], filename];
            
            if (eventsToTake >= allEvents.count) {
                // All events taken - delete entire file
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                NRVA_DEBUG_LOG(@"File %@ fully consumed - deleted", filename);
            } else {
                // Keep remaining events in file
                NSArray *remainingEvents = [allEvents subarrayWithRange:NSMakeRange(eventsToTake, allEvents.count - eventsToTake)];
                NSData *updatedData = [NSJSONSerialization dataWithJSONObject:remainingEvents options:0 error:nil];
                [updatedData writeToFile:filePath atomically:YES];
                NRVA_DEBUG_LOG(@"File %@: polled %ld offline events, %ld remaining", filename, (long)eventsToTake, (long)remainingEvents.count);
            }
            
            return polledEvents;
            
        } @catch (NSException *exception) {
            NRVA_DEBUG_LOG(@"Failed to poll offline events from file %@: %@", filename, exception.reason);
            return @[];
        }
    }
}

@end
