//
//  Tracker.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NRTimeSince;

/**
 Defines the basic behaviour of a tracker.
 */
@interface NRTracker : NSObject

/**
 Tracker is ready.
 */
- (void)trackerReady;

/**
 Set linked tracker.
 
 @param linkedTracker Tracker instance.
 */
- (void)setLinkedTracker:(NRTracker *)linkedTracker;

/**
 Set custom attribute for all events.
 
 @param key Attribute name.
 @param value Attribute value.
 */
- (void)setAttribute:(NSString *)key value:(id<NSCopying>)value;

/**
 Set custom attribute for selected events.
 
 WARNING: if the same attribute is defined for multiple action filters that could potentially match the same action, the behaviour is undefined. The user is responsable for designing filters that are sufficiently selective.
 
 @param key Attribute name.
 @param value Attribute value.
 @param action Action filter, a regexp.
 */
- (void)setAttribute:(NSString *)key value:(id<NSCopying>)value forAction:(nullable NSString *)action;

/**
 Generate attributes for a given action.
 
 @param action Action being generated.
 @param attributes Specific attributes sent along the action.
 @return Dictionary of attributes.
 */
- (NSMutableDictionary *)getAttributes:(NSString *)action attributes:(nullable NSDictionary *)attributes;

/**
 Register tracker listeners.
 */
- (void)registerListeners;

/**
 Unregister tracker listeners.
 */
- (void)unregisterListeners;

/**
 Dispose of the tracker. Internally call `unregisterListeners`.
 */
- (void)dispose;

/**
 Method called right before sending the event to New Relic.
 
 Last chance to decide if the event must be sent or not, or to modify the attributes.
 
 @param action Action name.
 @param attributes Action atteributes.
 @return Must be send or not.
 */
- (BOOL)preSendAction:(NSString *)action attributes:(NSMutableDictionary *)attributes;

/**
 Send event.
 
 @param action Action name.
 */
- (void)sendEvent:(NSString *)action;

/**
 Send event with attributes.
 
 @param action Action name.
 @param attributes Action atteributes.
 */
- (void)sendEvent:(NSString *)action attributes:(nullable NSDictionary *)attributes;

/**
 Get the core version.
 
 @return Core version.
 */
- (NSString *)getCoreVersion;

/**
 Get agent session.
 
 @return Agent session ID.
 */
- (NSString *)getAgentSession;

/**
 Add an entry to the timeSince table.
 
 @param action Action name.
 @param attribute Attribute name.
 @param filter Filtyer for the actions where the attribute applies.
 */
- (void)addTimeSinceEntryWithAction:(NSString *)action attribute:(NSString *)attribute applyTo:(NSString *)filter;

/**
 Add entry using NRTimeSince model.
 
 @param ts Model.
 */
- (void)addTimeSinceEntry:(NRTimeSince *)ts;

/**
 Generate table of timeSince attributes.
 */
- (void)generateTimeSinceTable;

@end

NS_ASSUME_NONNULL_END
