//
//  NRTimeSince.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 15/12/2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Time since model.
 */
@interface NRTimeSince : NSObject

/**
 init model with action, attribute name and filter.
 
 @param action Action.
 @param attribute Attribute name.
 @param filter Filtyer for the actions where the attribute applies.
 @return Instance.
 */
- (instancetype)initWithAction:(NSString *)action attribute:(NSString *)attribute applyTo:(NSString *)filter;

/**
 Get attribute name.
 
 @return Atrribute name.
 */
- (NSString *)attributeName;

/**
 Check if model applies to the given action.
 
 @return True if applies, false otherwise.
 */
- (BOOL)isAction:(NSString *)action;

/**
 Check if model matches the action filter.
 
 @return True if applies, false otherwise.
 */
- (BOOL)isMatch:(NSString *)action;

/**
 Set current timestamp for timeSince attribute.
 */
- (void)now;

/**
 Get current timeSince value.
 
 @return Time since.
 */
- (NSNumber *)timeSince;

@end

NS_ASSUME_NONNULL_END