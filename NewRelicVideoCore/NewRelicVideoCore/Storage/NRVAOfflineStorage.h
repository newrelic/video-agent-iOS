//
//  NRVAOfflineStorage.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRVAOfflineStorage : NSObject

- (instancetype)initWithEndpoint:(NSString *)name;
- (instancetype)initWithEndpoint:(NSString *)name maxStorageSizeMB:(NSUInteger)maxStorageSizeMB;
- (BOOL)persistDataToDisk:(NSData *)data;
- (NSArray<NSData *> *)getAllOfflineData:(BOOL)clear;
- (BOOL)clearAllOfflineFiles;
+ (BOOL)clearAllOfflineDirectories;
+ (BOOL)checkErrorToPersist:(NSError *)error;
- (void)setMaxOfflineStorageSize:(NSUInteger)size;
- (NSString *)offlineDirectoryPath;
+ (NSString *)allOfflineDirectorysPath;
- (NSInteger)getEventCount;

// Simple selective file management
- (NSArray<NSString *> *)getAllOfflineFileNames;
- (NSData *)getDataFromFile:(NSString *)filename;
- (BOOL)clearSpecificFiles:(NSArray<NSString *> *)filenames;

// EFFICIENT: Simple poll-and-remove method (matches Android SQLite pattern)
- (NSArray<NSDictionary *> *)pollAndRemoveEventsFromFile:(NSString *)filename maxEvents:(NSInteger)maxEvents;

@end
