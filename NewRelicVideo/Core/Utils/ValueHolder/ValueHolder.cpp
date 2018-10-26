//
//  ValueHolder.cpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#include "ValueHolder.hpp"

ValueHolder::ValueHolder() {
    ValueHolder("");
}

ValueHolder::ValueHolder(std::string dat) {
    valueType = ValueHolderTypeString;
    valueString = dat;
}

ValueHolder::ValueHolder(long dat) {
    valueType = ValueHolderTypeInt;
    valueInt = dat;
}

ValueHolder::ValueHolder(double dat) {
    valueType = ValueHolderTypeFloat;
    valueFloat = dat;
}

ValueHolder::ValueHolder(std::vector<uint8_t> dat) {
    valueType = ValueHolderTypeData;
    valueData = dat;
}

ValueHolder::ValueHolderType ValueHolder::getValueType() {
    return valueType;
}

std::string ValueHolder::getValueString() {
    if (getValueType() == ValueHolderTypeString) {
        return valueString;
    }
    else {
        return "";
    }
}

long ValueHolder::getValueInt() {
    if (getValueType() == ValueHolderTypeInt) {
        return valueInt;
    }
    else {
        return 0;
    }
}

double ValueHolder::getValueFloat() {
    if (getValueType() == ValueHolderTypeFloat) {
        return valueFloat;
    }
    else {
        return 0.0;
    }
}

std::vector<uint8_t> ValueHolder::getValueData() {
    if (getValueType() == ValueHolderTypeData) {
        return valueData;
    }
    else {
        return {};
    }
}