//
//  NRVATokenManager.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRVAVideoConfiguration;

/**
 * Manages authentication tokens for the video agent
 * Thread-safe token generation, caching, and validation
 * Follows Android TokenManager pattern
 */
@interface NRVATokenManager : NSObject

/**
 * Initialize with video configuration
 * @param configuration Video configuration containing app token and region
 */
- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)configuration;

/**
 * Get valid app token array (async operation)
 * Returns cached token if valid, otherwise generates new one
 * @param completion Completion block with token array or error
 */
- (void)getAppTokenWithCompletion:(void (^)(NSArray<NSNumber *> *token, NSError *error))completion;

/**
 * Force refresh of token (clears cache and generates new)
 * @param completion Completion block with new token array or error
 */
- (void)refreshTokenWithCompletion:(void (^)(NSArray<NSNumber *> *token, NSError *error))completion;

/**
 * Check if current cached token is still valid
 * @return YES if token exists and is within validity period
 */
- (BOOL)isTokenValid;

/**
 * Clear cached token (useful for logout/reset scenarios)
 */
- (void)clearCachedToken;

@end
