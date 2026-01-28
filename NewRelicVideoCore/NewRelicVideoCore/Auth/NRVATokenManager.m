//
//  NRVATokenManager.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVATokenManager.h"
#import "NRVAVideoConfiguration.h"
#import "NRVAUtils.h"
#import "NRVALog.h"

#import <UIKit/UIKit.h>

// Constants optimized for mobile/TV performance
static NSString *const kNRVA_PREFS_NAME = @"nr_video_tokens";
static NSString *const kNRVA_KEY_APP_TOKEN = @"nr_video_tokens.app_token";
static NSString *const kNRVA_KEY_TOKEN_TIMESTAMP = @"nr_video_tokens.token_timestamp";
static const NSTimeInterval kNRVA_TOKEN_VALIDITY_SECONDS = 14 * 24 * 60 * 60; // 14 days for security
static const NSTimeInterval kNRVA_CONNECT_TIMEOUT = 15.0; // 15 seconds for TV networks
static const NSTimeInterval kNRVA_READ_TIMEOUT = 30.0;    // 30 seconds for TV networks

@interface NRVATokenManager ()

@property (nonatomic, strong) NRVAVideoConfiguration *configuration;
@property (nonatomic, strong) NSUserDefaults *prefs;
@property (nonatomic, strong) NSArray<NSNumber *> *cachedToken;
@property (nonatomic, assign) NSTimeInterval lastTokenTime;
@property (nonatomic, strong) dispatch_queue_t tokenQueue;
@property (nonatomic, strong) NSString *tokenEndpoint;
@property (nonatomic, strong) NSMutableArray *pendingCompletions;
@property (nonatomic, assign) BOOL isGeneratingToken;

@end

@implementation NRVATokenManager

- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)configuration {
    self = [super init];
    if (self) {
        if (!configuration) {
            NRVA_ERROR_LOG(@"Configuration cannot be nil");
            return nil;
        }
        
        _configuration = configuration;
        
        // Use standard NSUserDefaults instead of suite to avoid potential crashes
        _prefs = [NSUserDefaults standardUserDefaults];
        if (!_prefs) {
            NRVA_ERROR_LOG(@"Failed to initialize NSUserDefaults");
            return nil;
        }
        
        _tokenQueue = dispatch_queue_create("com.newrelic.videoagent.token", DISPATCH_QUEUE_SERIAL);
        _tokenEndpoint = [self buildTokenEndpoint];
        
        // Load cached token on initialization with safety check
        @try {
            [self loadCachedToken];
        } @catch (NSException *exception) {
            NRVA_ERROR_LOG(@"Exception loading cached token: %@", exception.reason);
        }
        
        // Initialize in-flight request tracking
        _pendingCompletions = [NSMutableArray array];
        _isGeneratingToken = NO;
        
        NRVA_DEBUG_LOG(@"TokenManager initialized for region: %@", configuration.region);
    }
    return self;
}

#pragma mark - Public Methods

- (void)getAppTokenWithCompletion:(void (^)(NSArray<NSNumber *> *token, NSError *error))completion {
    if (!completion) {
        NRVA_ERROR_LOG(@"Completion block cannot be nil");
        return;
    }
    
    dispatch_async(self.tokenQueue, ^{
        // Fast path: check cached token
        if (self.cachedToken && [self isTokenValid]) {
            NRVA_DEBUG_LOG(@"Returning cached token");
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([self.cachedToken copy], nil);
            });
            return;
        }
        
        if (self.isGeneratingToken) {
            NRVA_DEBUG_LOG(@"Token generation already in progress, adding to pending completions");
            [self.pendingCompletions addObject:[completion copy]];
            return;
        }
        
        // Slow path: generate new token
        NRVA_DEBUG_LOG(@"Generating new token from API");
        self.isGeneratingToken = YES;
        [self.pendingCompletions addObject:[completion copy]];
        
        [self generateAppTokenWithCompletion:^(NSArray<NSNumber *> *token, NSError *error) {
            dispatch_async(self.tokenQueue, ^{
                if (token && !error) {
                    self.cachedToken = token;
                    self.lastTokenTime = [[NSDate date] timeIntervalSince1970];
                    [self cacheToken:token];
                    
                    NRVA_DEBUG_LOG(@"New token generated and cached successfully");
                } else {
                    NRVA_ERROR_LOG(@"Failed to generate token: %@", error.localizedDescription);
                }
                
                // Call all pending completions
                NSArray *completionsToCall = [self.pendingCompletions copy];
                [self.pendingCompletions removeAllObjects];
                self.isGeneratingToken = NO;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    for (void (^pendingCompletion)(NSArray<NSNumber *> *, NSError *) in completionsToCall) {
                        pendingCompletion(token ? [token copy] : nil, error);
                    }
                });
            });
        }];
    });
}

- (void)refreshTokenWithCompletion:(void (^)(NSArray<NSNumber *> *token, NSError *error))completion {
    if (!completion) {
        NRVA_ERROR_LOG(@"Completion block cannot be nil");
        return;
    }
    
    dispatch_async(self.tokenQueue, ^{
        // Clear cached token to force regeneration
        self.cachedToken = nil;
        self.lastTokenTime = 0;
        [self clearCachedToken];
        
        NRVA_DEBUG_LOG(@"Token cache cleared, forcing refresh");
        
        // Generate new token
        [self getAppTokenWithCompletion:completion];
    });
}

- (BOOL)isTokenValid {
    if (!self.cachedToken) {
        return NO;
    }
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval tokenAge = currentTime - self.lastTokenTime;
    return tokenAge < kNRVA_TOKEN_VALIDITY_SECONDS;
}

- (void)clearCachedToken {
    dispatch_async(self.tokenQueue, ^{
        [self.prefs removeObjectForKey:kNRVA_KEY_APP_TOKEN];
        [self.prefs removeObjectForKey:kNRVA_KEY_TOKEN_TIMESTAMP];
        [self.prefs synchronize];
        
        self.cachedToken = nil;
        self.lastTokenTime = 0;
        
        NRVA_DEBUG_LOG(@"Token cache cleared");
    });
}

#pragma mark - Private Methods

- (NSString *)buildTokenEndpoint {
    // If collectorAddress is explicitly set, use it for /connect endpoint
    if (self.configuration.collectorAddress && self.configuration.collectorAddress.length > 0) {
        return [NSString stringWithFormat:@"https://%@/mobile/v5/connect", self.configuration.collectorAddress];
    }

    // Otherwise, auto-detect from region
    NSString *region = self.configuration.region.uppercaseString;

    if ([region isEqualToString:@"EU"]) {
        return @"https://mobile-collector.eu.newrelic.com/mobile/v5/connect";
    } else if ([region isEqualToString:@"AP"]) {
        return @"https://mobile-collector.ap.newrelic.com/mobile/v5/connect";
    } else if ([region isEqualToString:@"GOV"]) {
        return @"https://gov-mobile-collector.newrelic.com/mobile/v5/connect";
    } else {
        return @"https://mobile-collector.newrelic.com/mobile/v5/connect"; // US/DEFAULT
    }
}

- (void)generateAppTokenWithCompletion:(void (^)(NSArray<NSNumber *> *token, NSError *error))completion {
    // Build request payload
    NSArray *payload = [self buildTokenRequestPayload];
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:0
                                                         error:&jsonError];
    
    if (jsonError) {
        NRVA_ERROR_LOG(@"Failed to serialize token request: %@", jsonError.localizedDescription);
        completion(nil, jsonError);
        return;
    }
    
    // Create URL request
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.tokenEndpoint]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;
    request.timeoutInterval = kNRVA_CONNECT_TIMEOUT;
    
    // Set headers
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[self getUserAgent] forHTTPHeaderField:@"User-Agent"];
    [request setValue:self.configuration.applicationToken forHTTPHeaderField:@"X-App-License-Key"];
    
    // Send request
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = kNRVA_CONNECT_TIMEOUT;
    config.timeoutIntervalForResource = kNRVA_READ_TIMEOUT;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            NRVA_ERROR_LOG(@"Token request failed: %@", error.localizedDescription);
            completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            NSError *statusError = [NSError errorWithDomain:@"NRVATokenManager"
                                                       code:httpResponse.statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            NRVA_ERROR_LOG(@"Token generation failed with status: %ld", (long)httpResponse.statusCode);
            completion(nil, statusError);
            return;
        }
        
        // Parse response
        NSArray<NSNumber *> *token = [self parseTokenResponse:data];
        if (token) {
            NRVA_DEBUG_LOG(@"Token parsed successfully: %@", token);
            completion(token, nil);
        } else {
            NSError *parseError = [NSError errorWithDomain:@"NRVATokenManager"
                                                      code:-1
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse token response"}];
            completion(nil, parseError);
        }
    }];
    
    [task resume];
}

- (NSArray *)buildTokenRequestPayload {
    // Application information
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *appName = [mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: 
                       [mainBundle objectForInfoDictionaryKey:@"CFBundleName"] ?: @"Unknown";
    NSString *appVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    NSString *bundleId = [mainBundle bundleIdentifier] ?: @"unknown";
    
    // First array: App information [appName, appVersion, bundleId]
    NSArray *appInfo = @[appName, appVersion, bundleId];
    
    // Device information
    NSString *osName = [NRVAUtils osName];
    NSString *osVersion = [[UIDevice currentDevice] systemVersion];
    NSString *architecture = [self getArchitecture];
    NSString *agentName = @"NewRelic-VideoAgent-iOS";
    NSString *agentVersion = @"4.0.3";
    NSString *deviceId = [NRVAUtils generateSessionId]; // Use session ID as device identifier
    NSString *manufacturer = @"Apple";
    
    // Device metadata
    NSDictionary *deviceMetadata = @{
        @"size": [self getDeviceSize],
        @"platform": @"iOS",
        @"platformVersion": osVersion
    };
    
    // Second array: Device and agent information
    NSArray *deviceInfo = @[
        osName,
        osVersion,
        architecture,
        agentName,
        agentVersion,
        deviceId,
        @"", // carrier (not used)
        @"", // network type (not used)
        manufacturer,
        deviceMetadata
    ];
    
    return @[appInfo, deviceInfo];
}

- (NSArray<NSNumber *> *)parseTokenResponse:(NSData *)data {
    if (!data) {
        return nil;
    }
    
    NSError *jsonError;
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:&jsonError];
    
    if (jsonError || ![response isKindOfClass:[NSDictionary class]]) {
        NRVA_ERROR_LOG(@"Failed to parse JSON response: %@", jsonError.localizedDescription);
        return nil;
    }
    
    // Look for data_token array
    NSArray *dataToken = response[@"data_token"];
    if (![dataToken isKindOfClass:[NSArray class]] || dataToken.count == 0) {
        NRVA_ERROR_LOG(@"data_token field not found or invalid in response");
        return nil;
    }
    
    // Validate and convert to NSNumber array
    NSMutableArray<NSNumber *> *tokenNumbers = [[NSMutableArray alloc] init];
    for (id tokenValue in dataToken) {
        if ([tokenValue isKindOfClass:[NSNumber class]]) {
            [tokenNumbers addObject:(NSNumber *)tokenValue];
        } else if ([tokenValue isKindOfClass:[NSString class]]) {
            // Try to parse string as number
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            NSNumber *number = [formatter numberFromString:(NSString *)tokenValue];
            if (number) {
                [tokenNumbers addObject:number];
            } else {
                NRVA_ERROR_LOG(@"Invalid token value in response: %@", tokenValue);
                return nil;
            }
        } else {
            NRVA_ERROR_LOG(@"Invalid token value type in response: %@", tokenValue);
            return nil;
        }
    }
    
    return [tokenNumbers copy];
}

- (void)loadCachedToken {
    NSString *tokenStr = [self.prefs stringForKey:kNRVA_KEY_APP_TOKEN];
    NSTimeInterval timestamp = [self.prefs doubleForKey:kNRVA_KEY_TOKEN_TIMESTAMP];
    
    if (tokenStr && timestamp > 0) {
        NSArray<NSNumber *> *tokens = [self parseStoredToken:tokenStr];
        if (tokens && tokens.count > 0) {
            self.cachedToken = tokens;
            self.lastTokenTime = timestamp;
            NRVA_DEBUG_LOG(@"Loaded cached token from storage");
        }
    }
}

- (void)cacheToken:(NSArray<NSNumber *> *)tokens {
    if (!tokens || tokens.count == 0) {
        return;
    }
    
    // Convert to comma-separated string
    NSMutableArray<NSString *> *tokenStrings = [[NSMutableArray alloc] init];
    for (NSNumber *token in tokens) {
        [tokenStrings addObject:[token stringValue]];
    }
    NSString *tokenStr = [tokenStrings componentsJoinedByString:@","];
    
    [self.prefs setObject:tokenStr forKey:kNRVA_KEY_APP_TOKEN];
    [self.prefs setDouble:[[NSDate date] timeIntervalSince1970] forKey:kNRVA_KEY_TOKEN_TIMESTAMP];
    [self.prefs synchronize];
    
    NRVA_DEBUG_LOG(@"Token cached to storage");
}

- (NSArray<NSNumber *> *)parseStoredToken:(NSString *)tokenStr {
    if (!tokenStr || tokenStr.length == 0) {
        return nil;
    }
    
    NSArray<NSString *> *tokenStrings = [tokenStr componentsSeparatedByString:@","];
    NSMutableArray<NSNumber *> *tokens = [[NSMutableArray alloc] init];
    
    for (NSString *tokenString in tokenStrings) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        NSNumber *number = [formatter numberFromString:[tokenString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        if (number) {
            [tokens addObject:number];
        } else {
            NRVA_ERROR_LOG(@"Failed to parse stored token value: %@", tokenString);
            return nil;
        }
    }
    
    return [tokens copy];
}

- (NSString *)getUserAgent {
    return [NSString stringWithFormat:@"NewRelicVideoAgent-iOS/1.0.0 (%@; %@)", 
            [NRVAUtils deviceModel], [NRVAUtils osName]];
}

- (NSString *)getArchitecture {
    #if TARGET_CPU_ARM64
        return @"arm64";
    #elif TARGET_CPU_X86_64
        return @"x86_64";
    #else
        return @"unknown";
    #endif
}

- (NSString *)getDeviceSize {
    if ([NRVAUtils isTVDevice]) {
        return @"large";
    } else {
        // Determine based on screen size
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = MAX(screenBounds.size.width, screenBounds.size.height);
        
        if (screenWidth >= 768) {
            return @"large"; // iPad
        } else {
            return @"normal"; // iPhone
        }
    }
}

@end
