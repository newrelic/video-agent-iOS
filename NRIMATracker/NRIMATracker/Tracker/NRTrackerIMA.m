//
//  NRTrackerIMA.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 02/03/21.
//  Copyright © 2020 New Relic Inc. All rights reserved.
//

#import "NRTrackerIMA.h"
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>

@interface NRTrackerIMA ()

@property (nonatomic, weak) IMAAdEvent *lastEvent;
@property (nonatomic, weak) IMAAdsManager *adsManager;

@end

@implementation NRTrackerIMA

- (void)adEvent:(IMAAdEvent *)event adsManager:(IMAAdsManager *)manager {
    self.lastEvent = event;
    self.adsManager = manager;
    
    if ([event.typeString isEqual:@"Started"]) {
        [self sendRequest];
        [self sendStart];
    }
    else if ([event.typeString isEqual:@"Complete"]) {
        [self sendEnd];
    }
    else if ([event.typeString isEqual:@"First Quartile"]) {
        //TODO: first quartile
        [self sendAdQuartile];
    }
    else if ([event.typeString isEqual:@"Midpoint"]) {
        //TODO: second quartile
        [self sendAdQuartile];
    }
    else if ([event.typeString isEqual:@"Third Quartile"]) {
        //TODO: third quartile
        [self sendAdQuartile];
    }
    else if ([event.typeString isEqual:@"Tapped"] || [event.typeString isEqual:@"Clicked"]) {
        [self sendAdClick];
    }
    
    AV_LOG(@"AdEvent received = %@", event.typeString);
}

- (void)adError:(NSString *)message code:(int)code {
    NSError *error = [[NSError alloc] initWithDomain:@"com.newrelic.video.IMA"
                                                code:code
                                            userInfo:@{ NSLocalizedDescriptionKey:message }];
    [self sendError:error];
}

//TODO: attribute getters

@end
