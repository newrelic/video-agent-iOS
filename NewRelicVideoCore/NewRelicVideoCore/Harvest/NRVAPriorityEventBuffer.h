//
//  NRVAPriorityEventBuffer.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRVAEventBufferInterface.h"

@class NRVAVideoConfiguration;

NS_ASSUME_NONNULL_BEGIN

/**
 * Video-optimized priority event buffer for mobile/TV environments
 * Separates live streaming events from on-demand content events
 * Uses thread-safe collections for better reliability
 * Simple overflow detection triggers immediate harvest
 */
@interface NRVAPriorityEventBuffer : NSObject <NRVAEventBufferInterface>

/**
 * Initialize with configuration for capacity optimization
 * @param configuration The video configuration containing buffer capacity settings
 */
- (instancetype)initWithIsTV:(BOOL *)isTV;

@end

NS_ASSUME_NONNULL_END
