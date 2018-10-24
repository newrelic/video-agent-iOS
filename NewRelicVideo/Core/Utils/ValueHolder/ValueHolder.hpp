//
//  ValueHolder.hpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#ifndef ValueHolder_hpp
#define ValueHolder_hpp

#include <stdio.h>
#include <string>
#include <vector>

class ValueHolder {
public:
    typedef enum {
        ValueHolderTypeInt,
        ValueHolderTypeFloat,
        ValueHolderTypeString,
        ValueHolderTypeData
    } ValueHolderType;
    
private:
    ValueHolderType valueType;
    std::string valueString;
    long valueInt;
    double valueFloat;
    std::vector<uint8_t> valueData;
    
public:
    ValueHolder();
    ValueHolder(std::string);
    ValueHolder(long);
    ValueHolder(double);
    ValueHolder(std::vector<uint8_t>);
    
    ValueHolderType getValueType();
    std::string getValueString();
    long getValueInt();
    double getValueFloat();
    std::vector<uint8_t> getValueData();
};

#endif /* ValueHolder_hpp */
