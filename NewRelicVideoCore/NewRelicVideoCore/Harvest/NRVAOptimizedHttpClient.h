//
//  NRVAOptimizedHttpClient.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRVAHttpClientInterface.h"

@class NRVAVideoConfiguration;

NS_ASSUME_NONNULL_BEGIN

/**
 * Optimized HTTP client for video event transmission
 */
@interface NRVAOptimizedHttpClient : NSObject <NRVAHttpClientInterface>

/**
 * Initialize with configuration and context
 * @param configuration Video configuration
 */
- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END