//
//  Tracker.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import "NRTracker.h"
#import "NRVideoLog.h"
#import "NREventAttributes.h"
#import "NRVideoDefs.h"
#import "NRTimeSinceTable.h"
#import "NewRelicVideoAgent.h"
#import <NewRelic/NewRelic.h>

@interface NRTracker ()

@property (nonatomic, weak) NRTracker *linkedTracker;
@property (nonatomic) NREventAttributes *eventAttributes;
@property (nonatomic) NRTimeSinceTable *timeSinceTable;

@end

@implementation NRTracker

- (instancetype)init {
    if (self = [super init]) {
        [self generateTimeSinceTable];
        self.eventAttributes = [[NREventAttributes alloc] init];
    }
    return self;
}

- (void)trackerReady {
    [self sendEvent:TRACKER_READY];
}

- (void)setAttribute:(NSString *)key value:(id<NSCopying>)value {
    [self setAttribute:key value:value forAction:nil];
}

- (void)setAttribute:(NSString *)key value:(id<NSCopying>)value forAction:(nullable NSString *)action {
    [self.eventAttributes setAttribute:key value:value filter:action];
    
    AV_LOG(@"Event Attribiutes = %@", self.eventAttributes);
}

- (NSMutableDictionary *)getAttributes:(NSString *)action attributes:(nullable NSDictionary *)attributes {
    NSMutableDictionary *attr = [self.eventAttributes generateAttributes:action append:attributes];
    [attr setObject:[self getCoreVersion] forKey:@"coreVersion"];
    [attr setObject:[self getAgentSession] forKey:@"agentSession"];
    return attr;
}

// Method placeholder, to be implemented by a subclass
- (void)registerListeners {}

// Method placeholder, to be implemented by a subclass
- (void)unregisterListeners {}

- (void)dispose {
    [self unregisterListeners];
}

// Last chance to decide if the event must be sent or not.
- (BOOL)preSendAction:(NSString *)action attributes:(NSMutableDictionary *)attributes {
    return YES;
}

- (void)sendEvent:(NSString *)action {
    [self sendEvent:action attributes:nil];
}

- (void)sendEvent:(NSString *)action attributes:(nullable NSDictionary *)attributes {
    
    NSMutableDictionary *attr = (NSMutableDictionary *)[self getAttributes:action attributes:attributes];
    
    [self.timeSinceTable applyAttributes:action attributes:attr];
    
    AV_LOG(@"SEND EVENT %@ => %@", action, attr);
    
    // Clean NSNull values
    NSArray *keys = [attr allKeys];
    for (NSString *key in keys) {
        if ([attr[key] isKindOfClass:[NSNull class]]) {
            [attr removeObjectForKey:key];
        }
    }
    
    if ([self preSendAction:action attributes:attr]) {
        [attr setObject:action forKey:@"actionName"];
        
        if (![NewRelic recordCustomEvent:NR_VIDEO_EVENT attributes:attr]) {
            AV_LOG(@"⚠️ Failed to recordCustomEvent. Maybe the NewRelicAgent is not initialized or the attribute list contains invalid/empty values. ⚠️");
            AV_LOG(@"-->Attributes = %@", attr);
        }
    }
}

- (NSString *)getCoreVersion {
    return NRVIDEO_CORE_VERSION;
}

- (NSString *)getAgentSession {
    return [[NewRelicVideoAgent sharedInstance] sessionId];
}

- (void)addTimeSinceEntryWithAction:(NSString *)action attribute:(NSString *)attribute applyTo:(NSString *)filter {
    [self.timeSinceTable addEntryWithAction:action attribute:attribute applyTo:filter];
}

- (void)addTimeSinceEntry:(NRTimeSince *)ts {
    [self.timeSinceTable addEntry:ts];
}

- (void)generateTimeSinceTable {
    self.timeSinceTable = [[NRTimeSinceTable alloc] init];
    [self addTimeSinceEntryWithAction:TRACKER_READY attribute:@"timeSinceTrackerReady" applyTo:@"[A-Z_]+"];
}

@end
