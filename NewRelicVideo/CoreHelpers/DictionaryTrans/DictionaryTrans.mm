//
//  DictionaryTrans.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "DictionaryTrans.h"
#import "ValueHolder.hpp"
#include <map>

@implementation DictionaryTrans

NSDictionary *fromMapToDictionary(std::map<std::string, ValueHolder> dict) {
    NSMutableDictionary *result = @{}.mutableCopy;
    for (auto& kv : dict) {
        NSString *key = [NSString stringWithUTF8String:kv.first.c_str()];
        ValueHolder value = kv.second;
        id obj = fromValueHolder(value);
        [result setObject:obj forKey:key];
    }
    return result.copy;
}

std::map<std::string, ValueHolder> fromDictionaryToMap(NSDictionary *dict) {
    std::map<std::string, ValueHolder> result;
    NSArray *keys = [dict allKeys];
    
    for (NSString *key in keys) {
        id value = [dict objectForKey:key];
        ValueHolder fValue = fromNSValue(value);
        result[std::string([key UTF8String])] = fValue;
    }
    
    return result;
}

id fromValueHolder(ValueHolder value) {
    switch (value.getValueType()) {
        case ValueHolder::ValueHolderTypeString: {
            NSString *str = [NSString stringWithUTF8String:value.getValueString().c_str()];
            return str;
        }
        case ValueHolder::ValueHolderTypeInt: {
            NSNumber *num = @(value.getValueInt());
            return num;
        }
        case ValueHolder::ValueHolderTypeFloat: {
            NSNumber *num = @(value.getValueFloat());
            return num;
        }
        default:
        case ValueHolder::ValueHolderTypeEmpty: {
            return [NSNull null];
        }
    }
}

ValueHolder fromNSValue(id value) {
    ValueHolder fValue;
    
    if ([value isKindOfClass:[NSString class]]) {
        fValue = ValueHolder(std::string([value UTF8String]));
    }
    else if ([value isKindOfClass:[NSNumber class]]) {
        CFNumberType numberType = CFNumberGetType((CFNumberRef)value);
        if (numberType == kCFNumberFloatType ||
            numberType == kCFNumberDoubleType ||
            numberType == kCFNumberCGFloatType) {
            fValue = ValueHolder(((NSNumber *)value).doubleValue);
        }
        else {
            fValue = ValueHolder(((NSNumber *)value).longValue);
        }
    }
    else {
        // TODO: return an empty response, so it is not included in the dictionary -> ValueHolder()
        
//        AV_LOG(@"ValueHolder unknown type: Creating an \"empty\" value.");
        fValue = ValueHolder("<NULL>");
    }
    
    return fValue;
}

@end
