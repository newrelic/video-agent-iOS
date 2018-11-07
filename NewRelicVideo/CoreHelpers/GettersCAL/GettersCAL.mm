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

@property (nonatomic) NSMutableDictionary<NSValue *, NSMutableDictionary<NSString *, NSArray *> *> *callbacksTree;

@end

@implementation GettersCAL

+ (void)registerGetter:(NSString *)name target:(id)target sel:(SEL)selector origin:(void *)pointer {
    [[self sharedInstance] registerGetterName:name target:target selector:selector origin:[NSValue valueWithPointer:pointer]];
}

+ (instancetype)sharedInstance {
    static GettersCAL *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GettersCAL alloc] init];
        sharedInstance.callbacksTree = @{}.mutableCopy;
    });
    return sharedInstance;
}

- (void)registerGetterName:(NSString *)name target:(id)target selector:(SEL)selector origin:(NSValue *)pointer {
    NSMutableDictionary<NSString *, NSArray *> *callbacks = [self.callbacksTree objectForKey:pointer];
    if (!callbacks) {
        callbacks = @{}.mutableCopy;
        [self.callbacksTree setObject:callbacks forKey:pointer];
    }
    [callbacks setObject:@[target, [NSValue valueWithPointer:selector]] forKey:name];
}

- (id<NSCopying>)callGetterName:(NSString *)name origin:(NSValue *)pointer {
    NSMutableDictionary<NSString *, NSArray *> *callbacks = self.callbacksTree[pointer];
    if (callbacks) {
        NSArray *arr = callbacks[name];
        if (arr) {
            id target = arr[0];
            NSValue *value = arr[1];
            SEL selector = (SEL)[value pointerValue];
            
            if ([target respondsToSelector:selector]) {
                IMP imp = [target methodForSelector:selector];
                id<NSCopying> (*func)(id, SEL) = (id<NSCopying> (*)(id, SEL))imp;
                return func(target, selector);
            }
            else {
                return NSNull.null;
            }
        }
        else {
            return NSNull.null;
        }
    }
    else {
        return NSNull.null;
    }
}

ValueHolder callGetter(std::string name, void *origin) {
    id res = (id)[[GettersCAL sharedInstance] callGetterName:[NSString stringWithUTF8String:name.c_str()]
                                                      origin:[NSValue valueWithPointer:origin]];
    return fromNSValue(res);
}

@end
