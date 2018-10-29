//
//  System-Interface.hpp
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#ifndef System_Interface_h
#define System_Interface_h

#include <string>
#include <map>

class ValueHolder;

bool recordCustomEvent(std::string name, std::map<std::string, ValueHolder> attr);
std::string currentSessionId();
double timeSince(double timestamp);

#endif /* System_Interface_h */
