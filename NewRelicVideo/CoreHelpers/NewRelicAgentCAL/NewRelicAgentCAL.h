//
//  NewRelicAgentCAL.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NewRelicAgentCAL : NSObject

+ (instancetype)sharedInstance;
- (void)generateUUID;

@end
