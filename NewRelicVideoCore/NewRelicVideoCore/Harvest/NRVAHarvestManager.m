//
//  NRVAHarvestManager.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAHarvestManager.h"
#import "NRVAVideoConfiguration.h"
#import "NRVAConnection.h"
#import "NRVAOfflineStorage.h"
#import "NRVATokenManager.h"
#import "NRVAUtils.h"
#import "NRVALog.h"

#define kNRVA_VIDEO_AGENT_VERSION      @"4.0.0"

@interface NRVAHarvestManager ()

@property (nonatomic, strong) NRVAVideoConfiguration *config;
@property (nonatomic, strong) NRVAConnection *connection;
@property (nonatomic, strong) NRVAOfflineStorage *offlineStorage;
@property (nonatomic, strong) NRVATokenManager *tokenManager;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *eventQueue;
@property (nonatomic, strong) NSTimer *harvestTimer;
@property (nonatomic, strong) dispatch_queue_t harvestQueue;
@property (nonatomic, assign) BOOL isHarvesting;

@end

@implementation NRVAHarvestManager

- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)config {
    self = [super init];
    if (self) {
        _config = config;
        _connection = [[NRVAConnection alloc] init];
        _connection.applicationToken = config.applicationToken; // Set the application token
        _offlineStorage = [[NRVAOfflineStorage alloc] initWithEndpoint:@"video-events"];
        _tokenManager = [[NRVATokenManager alloc] initWithConfiguration:config];
        _eventQueue = [[NSMutableArray alloc] init];
        _harvestQueue = dispatch_queue_create("com.newrelic.videoagent.harvest", DISPATCH_QUEUE_SERIAL);
        _isHarvesting = NO;
        
        // Configure offline storage size
        [_offlineStorage setMaxOfflineStorageSize:100]; // 100MB
        
        NRVA_DEBUG_LOG(@"HarvestManager initialized with config: %@", config.applicationToken);
    }
    return self;
}

- (void)recordEvent:(NSString *)eventType attributes:(NSDictionary<NSString *, id> *)attributes {
    if (!eventType || eventType.length == 0) {
        NRVA_ERROR_LOG(@"Cannot record event: eventType is nil or empty");
        return;
    }
    
    dispatch_async(self.harvestQueue, ^{
        NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
        event[@"eventType"] = eventType;
        event[@"timestamp"] = @([[NSDate date] timeIntervalSince1970] * 1000); // milliseconds
        event[@"sessionId"] = [NRVAUtils generateSessionId];
        
        // Add device information
        event[@"deviceType"] = [NRVAUtils isTVDevice] ? @"tv" : @"mobile";
        event[@"osName"] = [NRVAUtils osName];
        event[@"deviceModel"] = [NRVAUtils deviceModel];
        
        // Add custom attributes directly to the main event object
        if (attributes && attributes.count > 0) {
            [event addEntriesFromDictionary:attributes];
        }
        
        @synchronized (self.eventQueue) {
            [self.eventQueue addObject:[event copy]];
        }
        
        NRVA_DEBUG_LOG(@"Recorded event: %@ (queue size: %lu)", eventType, (unsigned long)[self queueSize]);
        
        // Check if we need to harvest immediately (queue size limit)
        if ([self queueSize] >= [self currentBatchSize]) {
            [self performHarvest];
        }
    });
}

- (void)startHarvesting {
    dispatch_async(self.harvestQueue, ^{
        if (self.isHarvesting) {
            NRVA_DEBUG_LOG(@"Harvest already running");
            return;
        }
        
        self.isHarvesting = YES;
        
        // Schedule regular harvesting
        dispatch_async(dispatch_get_main_queue(), ^{
            self.harvestTimer = [NSTimer scheduledTimerWithTimeInterval:self.config.harvestCycleSeconds
                                                                 target:self
                                                               selector:@selector(harvestTimerFired:)
                                                               userInfo:nil
                                                                repeats:YES];
        });
        
        NRVA_DEBUG_LOG(@"Harvest started with %ld second cycle", (long)self.config.harvestCycleSeconds);
    });
}

- (void)stopHarvesting {
    dispatch_async(self.harvestQueue, ^{
        self.isHarvesting = NO;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.harvestTimer invalidate];
            self.harvestTimer = nil;
        });
        
        // Final harvest before stopping
        [self performHarvest];
        
        NRVA_DEBUG_LOG(@"Harvest stopped");
    });
}

- (void)forceHarvest {
    dispatch_async(self.harvestQueue, ^{
        [self performHarvest];
    });
}

- (NSUInteger)queueSize {
    @synchronized (self.eventQueue) {
        return self.eventQueue.count;
    }
}

#pragma mark - Private Methods

- (void)harvestTimerFired:(NSTimer *)timer {
    dispatch_async(self.harvestQueue, ^{
        [self performHarvest];
    });
}

- (void)performHarvest {
    NSArray<NSDictionary *> *eventsToSend;
    
    @synchronized (self.eventQueue) {
        if (self.eventQueue.count == 0) {
            NRVA_DEBUG_LOG(@"No events to harvest");
            return;
        }
        
        eventsToSend = [self.eventQueue copy];
        [self.eventQueue removeAllObjects];
    }
    
    NRVA_DEBUG_LOG(@"Harvesting %lu events", (unsigned long)eventsToSend.count);
    
    // Get authentication token for the harvest first
    [self.tokenManager getAppTokenWithCompletion:^(NSArray<NSNumber *> *token, NSError *error) {
        if (error || !token) {
            NRVA_ERROR_LOG(@"Failed to get auth token for harvest: %@", error.localizedDescription);
            // Put events back in queue for retry
            @synchronized (self.eventQueue) {
                [self.eventQueue insertObjects:eventsToSend atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, eventsToSend.count)]];
            }
            return;
        }
        
        // Create harvest payload matching the successful format
        NSString *sessionId = [NRVAUtils generateSessionId];
        NSString *osVersion = [[UIDevice currentDevice] systemVersion];
        NSString *deviceModel = [[UIDevice currentDevice] model];
        
        NSArray *payload = @[
            token, // First array - data token from token manager
            @[   // Second array - device info
                [self osName],                                    // OS name
                osVersion,                                        // OS version  
                @"arm64",                                         // Architecture
                @"NewRelicVideoAgent-iOS",                       // Agent name
                kNRVA_VIDEO_AGENT_VERSION,                       // Agent version
                sessionId,                                        // Session ID
                @"",                                              // Empty string
                @"",                                              // Empty string  
                @"Apple",                                         // Manufacturer
                @{                                                // Platform info
                    @"platform": [self osName],
                    @"size": [NRVAUtils isTVDevice] ? @"TV" : @"Phone",
                    @"platformVersion": osVersion
                }
            ],
            @0,   // Third element - number (0)
            @[],  // Fourth array - empty
            @[],  // Fifth array - empty
            @[],  // Sixth array - empty
            @[],  // Seventh array - empty
            @[],  // Eighth array - empty
            @{},  // Ninth element - empty object
            eventsToSend  // Tenth element - events array
        ];
        
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload 
                                                           options:NSJSONWritingPrettyPrinted 
                                                             error:&jsonError];
        
        if (jsonError) {
            NRVA_ERROR_LOG(@"Failed to serialize harvest payload: %@", jsonError.localizedDescription);
            // Put events back in queue
            @synchronized (self.eventQueue) {
                [self.eventQueue insertObjects:eventsToSend atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, eventsToSend.count)]];
            }
            return;
        }
        
        // Send the data
        [self sendHarvestData:jsonData originalEvents:eventsToSend];
    }];
}

- (void)sendHarvestData:(NSData *)data originalEvents:(NSArray<NSDictionary *> *)originalEvents {
    NSString *endpoint = [self getHarvestEndpoint];
    
    [self.connection postData:data 
                       toURL:endpoint 
           completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        
        if (error) {
            NRVA_ERROR_LOG(@"Harvest failed: %@", error.localizedDescription);
            
            // Check if we should store offline
            if ([NRVAOfflineStorage checkErrorToPersist:error]) {
                [self.offlineStorage persistDataToDisk:data];
                NRVA_DEBUG_LOG(@"Stored failed harvest data offline");
            } else {
                // Put events back in queue for retry
                @synchronized (self.eventQueue) {
                    [self.eventQueue insertObjects:originalEvents 
                                          atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, originalEvents.count)]];
                }
            }
        } else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
                NRVA_DEBUG_LOG(@"Harvest successful: %ld events sent", (long)originalEvents.count);
                
                // Process any offline data
                [self processOfflineData];
            } else {
                NRVA_ERROR_LOG(@"Harvest failed with status code: %ld", (long)httpResponse.statusCode);
                
                // Store offline for retry
                [self.offlineStorage persistDataToDisk:data];
            }
        }
    }];
}

- (void)processOfflineData {
    NSArray<NSData *> *offlineData = [self.offlineStorage getAllOfflineData:YES];
    
    if (offlineData.count == 0) {
        return;
    }
    
    NRVA_DEBUG_LOG(@"Processing %lu offline data items", (unsigned long)offlineData.count);
    
    for (NSData *data in offlineData) {
        NSString *endpoint = [self getHarvestEndpoint];
        
        [self.connection postData:data 
                           toURL:endpoint 
               completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
            
            if (error) {
                NRVA_ERROR_LOG(@"Offline data upload failed: %@", error.localizedDescription);
                // Don't re-store, it will be retried next time
            } else {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
                    NRVA_DEBUG_LOG(@"Offline data uploaded successfully");
                } else {
                    NRVA_ERROR_LOG(@"Offline data upload failed with status code: %ld", (long)httpResponse.statusCode);
                }
            }
        }];
    }
}

- (NSString *)getHarvestEndpoint {
    NSString *baseURL;
    
    if ([self.config.region isEqualToString:@"EU"]) {
        baseURL = @"https://mobile-collector.eu.newrelic.com";
    } else if ([self.config.region isEqualToString:@"AP"]) {
        baseURL = @"https://mobile-collector.ap.newrelic.com";
    } else if ([self.config.region isEqualToString:@"GOV"]) {
        baseURL = @"https://mobile-collector.gov.newrelic.com";
    } else {
        baseURL = @"https://mobile-collector.newrelic.com";
    }
    
    return [NSString stringWithFormat:@"%@/mobile/v3/data", baseURL];
}

- (NSString *)osName {
    #if TARGET_OS_TV
        return @"tvOS";
    #else
        return @"iOS";
    #endif
}

- (NSInteger)currentBatchSize {
    // TODO: Consider live vs regular content for batch sizing
    return self.config.regularBatchSizeBytes / 1024; // Convert to approximate event count
}

@end
