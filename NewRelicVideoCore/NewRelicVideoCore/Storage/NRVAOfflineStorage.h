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

// Clean event-level processing (your suggested approach)
- (NSArray<NSDictionary *> *)getUnprocessedEventsFromFile:(NSString *)filename maxEvents:(NSInteger)maxEvents;
- (BOOL)removeProcessedEventsFromFile:(NSString *)filename;

@end
