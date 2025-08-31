//
//  NRVADeadLetterEventBuffer.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRVAEventBufferInterface.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Specialized event buffer for dead letter queue - retry events only
 * Does NOT trigger schedulers or callbacks - just stores and retrieves events
 * Simpler, focused implementation without scheduler integration
 */
@interface NRVADeadLetterEventBuffer : NSObject <NRVAEventBufferInterface>

/**
 * Initialize with device type flag
 * @param isTV Whether this is a TV device (affects batch sizes and capacity)
 */
- (instancetype)initWithIsTV:(BOOL)isTV;

@end

NS_ASSUME_NONNULL_END