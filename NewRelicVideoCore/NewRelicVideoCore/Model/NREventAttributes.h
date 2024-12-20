//
//  NREventAttributes.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Event attributes model.
 */
@interface NREventAttributes : NSObject

/**
 Set attribute for a given action filter.
 
 @param key Attribute name.
 @param value Attribute value.
 @param regexp Action filter, a regular expression.
 */
- (void)setAttribute:(NSString *)key value:(id<NSCopying>)value filter:(nullable NSString *)regexp;

/**
 Set userId.
 
 @param userId The userId.
 */
- (void)setUserId:(NSString *)userId;

/**
 Generate list of attributes for a given action.
 
 @param action Action.
 @param attributes Append attributes.
 @return Dictionary of attributes.
 */
- (NSMutableDictionary *)generateAttributes:(NSString *)action append:(nullable NSDictionary *)attributes;

@end

NS_ASSUME_NONNULL_END
