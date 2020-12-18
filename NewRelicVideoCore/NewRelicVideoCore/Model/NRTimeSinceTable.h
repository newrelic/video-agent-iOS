//
//  NRTimeSinceTable.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 16/12/2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NRTimeSince;

/**
 Time since table model.
 */
@interface NRTimeSinceTable : NSObject

/**
 Add entry to TimeSince table.
 
 @param action Action.
 @param attribute Attribute name.
 @param filter Filtyer for the actions where the attribute applies.
 */
- (void)addEntryWithAction:(NSString *)action attribute:(NSString *)attribute applyTo:(NSString *)filter;

/**
 Add entry using NRTimeSince model.
 
 @param ts Model.
 */
- (void)addEntry:(NRTimeSince *)ts;
/**
 Apply timeSince attributes to a given action.
 
 @param action Action.
 @param attr Attribute list.
 */
- (void)applyAttributes:(NSString *)action attributes:(NSMutableDictionary *)attr;

@end

NS_ASSUME_NONNULL_END
