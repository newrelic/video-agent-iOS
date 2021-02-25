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
 @param filter Filter for the actions where the attribute applies, a regular expression.
 @return Instance.
 */
- (instancetype)initWithAction:(NSString *)action attribute:(NSString *)attribute applyTo:(NSString *)filter;

/**
 Get attribute name.
 
 @return Attribute name.
 */
- (NSString *)attributeName;

/**
 Check if model applies to the given action.
 
 @param action Action.
 @return True if applies, false otherwise.
 */
- (BOOL)isAction:(NSString *)action;

/**
 Check if model matches the action filter.
 
 @param action Action.
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
