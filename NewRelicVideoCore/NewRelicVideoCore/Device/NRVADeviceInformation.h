//
//  NRVADeviceInformation.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Thread-safe singleton with comprehensive device detection and caching
 * Zero performance impact after initialization with proper error handling
 */
@interface NRVADeviceInformation : NSObject

/**
 * Thread-safe singleton instance with lazy initialization
 */
+ (instancetype)sharedInstance;

// Core device information (immutable after initialization)
@property (nonatomic, readonly) NSString *osName;
@property (nonatomic, readonly) NSString *osVersion;
@property (nonatomic, readonly) NSString *osBuild;
@property (nonatomic, readonly) NSString *model;
@property (nonatomic, readonly) NSString *agentName;
@property (nonatomic, readonly) NSString *agentVersion;
@property (nonatomic, readonly) NSString *manufacturer;
@property (nonatomic, readonly) NSString *deviceId;
@property (nonatomic, readonly) NSString *architecture;
@property (nonatomic, readonly) NSString *runTime;
@property (nonatomic, readonly) NSString *size;
@property (nonatomic, readonly) NSString *applicationFramework;
@property (nonatomic, readonly) NSString *applicationFrameworkVersion;
@property (nonatomic, readonly) NSString *userAgent;
@property (nonatomic, readonly) BOOL isTV;
@property (nonatomic, readonly) BOOL isLowMemoryDevice;

@end

NS_ASSUME_NONNULL_END
