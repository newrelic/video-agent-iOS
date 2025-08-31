//
//  NRVADefaultSizeEstimator.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVADefaultSizeEstimator.h"

// Prevent deep recursion that can cause stack overflow on mobile
static const int MAX_RECURSION_DEPTH = 5;

// Cache for repeated string size calculations (mobile optimization)
static const int MAX_CACHE_SIZE = 100;

@interface NRVADefaultSizeEstimator ()
@property (nonatomic, strong) NSCache<NSString *, NSNumber *> *sizeCache;
- (NSInteger)estimateWithObject:(id)obj depth:(int)depth; // Private helper declaration
@end

@implementation NRVADefaultSizeEstimator

- (instancetype)init {
    self = [super init];
    if (self) {
        _sizeCache = [[NSCache alloc] init];
        _sizeCache.countLimit = MAX_CACHE_SIZE;
    }
    return self;
}

// MODIFIED: Public method now specifically accepts an NSDictionary
- (NSInteger)estimate:(NSDictionary<NSString *, id> *)event {
    return [self estimateWithObject:event depth:0];
}

// Private helper method remains unchanged to handle all object types recursively
- (NSInteger)estimateWithObject:(id)obj depth:(int)depth {
    if (obj == nil || [obj isKindOfClass:[NSNull class]] || depth >= MAX_RECURSION_DEPTH) {
        return 0;
    }

    // Handle Strings
    if ([obj isKindOfClass:[NSString class]]) {
        NSString *str = (NSString *)obj;
        NSNumber *cachedSize = [self.sizeCache objectForKey:str];
        if (cachedSize != nil) {
            return [cachedSize integerValue];
        }
        NSInteger size = [str lengthOfBytesUsingEncoding:NSUTF16StringEncoding];
        [self.sizeCache setObject:@(size) forKey:str];
        return size;
    }

    // Handle Numbers (including Booleans)
    if ([obj isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)obj;
        const char *type = [number objCType];
        if (strcmp(type, @encode(int)) == 0 || strcmp(type, @encode(float)) == 0) return 4;
        if (strcmp(type, @encode(long)) == 0 || strcmp(type, @encode(double)) == 0 || strcmp(type, @encode(long long)) == 0) return 8;
        if (strcmp(type, @encode(short)) == 0) return 2;
        if (strcmp(type, @encode(char)) == 0 || strcmp(type, @encode(BOOL)) == 0) return 1;
        return 8;
    }
    
    // Handle Dictionaries (Maps)
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)obj;
        NSInteger size = 0;
        int count = 0;
        for (id key in dict) {
            if (++count > 20) break;
            size += [self estimateWithObject:key depth:depth + 1];
            size += [self estimateWithObject:dict[key] depth:depth + 1];
        }
        return size;
    }
    
    // Handle Arrays (Lists)
    if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *array = (NSArray *)obj;
        NSInteger size = 0;
        NSInteger maxItems = MIN(array.count, 20);
        for (int i = 0; i < maxItems; i++) {
            size += [self estimateWithObject:array[i] depth:depth + 1];
        }
        return size;
    }

    // Default for other object types
    return 16;
}

@end