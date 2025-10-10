//
//  NRVAHttpClientInterface.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol defining the contract for HTTP client implementations
 * Handles event transmission to New Relic endpoints
 */
@protocol NRVAHttpClientInterface <NSObject>

/**
 * Send events to New Relic with specified harvest type (async)
 * @param events Array of event dictionaries to send
 * @param harvestType Type of harvest ("live" or "ondemand")
 * @param completion Completion block called with success/failure result
 */
- (void)sendEvents:(NSArray<NSDictionary<NSString *, id> *> *)events 
       harvestType:(NSString *)harvestType 
        completion:(void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END