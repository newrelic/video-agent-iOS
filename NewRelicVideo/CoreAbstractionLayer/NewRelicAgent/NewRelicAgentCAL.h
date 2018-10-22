//
//  NewRelicAgentCAL.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NewRelicAgentCAL : NSObject

+ (BOOL)recordCustomEvent:(NSString* _Nonnull)eventType
               attributes:(NSDictionary* _Nullable)attributes;

@end
