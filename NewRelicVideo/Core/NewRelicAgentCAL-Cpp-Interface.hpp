//
//  NewRelicAgentCAL-Cpp-Interface.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#ifndef NewRelicAgentCAL_Cpp_Interface_h
#define NewRelicAgentCAL_Cpp_Interface_h

#include <string>
#include <map>

class ValueHolder;

bool recordCustomEvent(std::string name, std::map<std::string, ValueHolder> attr);

#endif /* NewRelicAgentCAL_Cpp_Interface_h */
