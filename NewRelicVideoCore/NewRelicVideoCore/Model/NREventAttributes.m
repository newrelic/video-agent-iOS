//
//  NREventAttributes.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import "NREventAttributes.h"

@interface NREventAttributes ()

@property (nonatomic) NSMutableDictionary<NSString *, NSMutableDictionary *> *attributeBuckets;

@end

@implementation NREventAttributes

- (instancetype)init {
    if (self = [super init]) {
        self.attributeBuckets = @{}.mutableCopy;
    }
    return self;
}

- (void)setAttribute:(NSString *)key value:(id<NSCopying>)value filter:(nullable NSString *)regexp {
    // If no filter defined, use universal filter that matches any action name
    if (!regexp) {
        regexp = @"[A-Z_]+";
    }
    
    // Attribute doesn't exit yet, create it
    if (![self.attributeBuckets objectForKey:regexp]) {
        [self.attributeBuckets setObject:@{}.mutableCopy forKey:regexp];
    }
    
    [[self.attributeBuckets objectForKey:regexp] setObject:value forKey:key];
}

- (NSMutableDictionary *)generateAttributes:(NSString *)action append:(nullable NSDictionary *)attributes {
    NSMutableDictionary *attr = @{}.mutableCopy;
    
    for (NSString *filter in self.attributeBuckets) {
        if ([self checkFilter:filter withAction:action]) {
            NSMutableDictionary *bucket = self.attributeBuckets[filter];
            for (NSString *attribute in bucket) {
                id<NSCoding> value = bucket[attribute];
                [attr setObject:value forKey:attribute];
            }
        }
    }
    
    if (attributes) {
        [attr addEntriesFromDictionary:attributes];
    }
    
    return attr;
}

- (BOOL)checkFilter:(NSString *)filter withAction:(NSString *)action {
    NSError  *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:filter options:0 error:&error];
    NSRange range = [regex rangeOfFirstMatchInString:action options:0 range:NSMakeRange(0, action.length)];
    return (range.location == 0 && range.length == action.length);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<NREventAttributes: %@>", self.attributeBuckets];
}

@end
