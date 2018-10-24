//
//  DictionaryTrans.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <string>
#include <map>

class ValueHolder;

@interface DictionaryTrans : NSObject

NSDictionary *fromMapToDictionary(std::map<std::string, ValueHolder> dict);
std::map<std::string, ValueHolder> fromDictionaryToMap(NSDictionary *dict);
id fromValueHolder(ValueHolder value);
ValueHolder fromNSValue(id value);

@end
