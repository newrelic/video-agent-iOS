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

@end
