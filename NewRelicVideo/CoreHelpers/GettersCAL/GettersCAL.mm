//
//  GettersCAL.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 30/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "GettersCAL.h"
#import "ValueHolder.hpp"
#import "DictionaryTrans.h"
#include <string>

@interface GettersCAL ()

@property (nonatomic) NSMutableDictionary<NSString *, NSArray *> *callbacks;

@end

@implementation GettersCAL

+ (instancetype)sharedInstance {
    static GettersCAL *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GettersCAL alloc] init];
        sharedInstance.callbacks = @{}.mutableCopy;
    });
    return sharedInstance;
}

- (void)registerGetterName:(NSString *)name target:(id)target selector:(SEL)selector {
    [self.callbacks setObject:@[target, [NSValue valueWithPointer:selector]] forKey:name];
}

- (id<NSCopying>)callGetterName:(NSString *)name {
    NSArray *arr = self.callbacks[name];
    if (arr) {
        id target = arr[0];
        NSValue *value = arr[1];
        SEL selector = (SEL)[value pointerValue];
        
        if ([target respondsToSelector:selector]) {
            IMP imp = [self methodForSelector:selector];
            id<NSCopying> (*func)(id, SEL) = (id<NSCopying> (*)(id, SEL))imp;
            return func(self, selector);
        }
        else {
            return NSNull.null;
        }
    }
    else {
        return NSNull.null;
    }
}

void registerGetter(NSString *name, id target, SEL selector) {
    [[GettersCAL sharedInstance] registerGetterName:name target:target selector:selector];
}

ValueHolder callGetter(std::string name) {
    id res = (id)[[GettersCAL sharedInstance] callGetterName:[NSString stringWithUTF8String:name.c_str()]];
    return fromNSValue(res);
}

@end
