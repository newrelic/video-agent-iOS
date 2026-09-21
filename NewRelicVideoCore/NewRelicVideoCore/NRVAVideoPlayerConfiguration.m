//
//  NRVAVideoPlayerConfiguration.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAVideoPlayerConfiguration.h"
#import "Utils/NRVALog.h"


@interface NRAdConfig ()
@property (nonatomic, readwrite) NRAdTrackerType type;
@property (nonatomic, readwrite, copy, nullable) NSString *adSegmentPrefix;
@property (nonatomic, readwrite, copy, nullable) NSString *trackingUrl;
@end

@implementation NRAdConfig

+ (instancetype)csai {
    NRAdConfig *c = [[NRAdConfig alloc] init];
    c.type = NRAdTrackerTypeCSAI;
    return c;
}

+ (instancetype)mediaTailor {
    return [self mediaTailorWithSegmentPrefix:nil trackingUrl:nil];
}

+ (instancetype)mediaTailorWithSegmentPrefix:(NSString *)adSegmentPrefix {
    return [self mediaTailorWithSegmentPrefix:adSegmentPrefix trackingUrl:nil];
}

+ (instancetype)mediaTailorWithSegmentPrefix:(NSString *)adSegmentPrefix
                                 trackingUrl:(NSString *)trackingUrl {
    NRAdConfig *c = [[NRAdConfig alloc] init];
    c.type = NRAdTrackerTypeMediaTailor;
    c.adSegmentPrefix = adSegmentPrefix;
    c.trackingUrl = trackingUrl;
    return c;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"NRAdConfig: type=%@, adSegmentPrefix=%@, trackingUrl=%@",
            self.type == NRAdTrackerTypeMediaTailor ? @"MediaTailor" : @"CSAI",
            self.adSegmentPrefix, self.trackingUrl];
}

@end


@implementation NRVAVideoPlayerConfiguration

- (instancetype)initWithPlayerName:(NSString *)playerName
                            player:(id)player
                          adConfig:(NRAdConfig *)adConfig
                  customAttributes:(NSDictionary<NSString *, id> *)customAttributes {
    self = [super init];
    if (self) {
        if (!playerName || playerName.length == 0) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:@"Player name cannot be nil or empty"
                                         userInfo:nil];
        }

        // Allow nil player for convenience methods, but require it for normal usage
        if (!player) {
            NRVA_DEBUG_LOG(@"Creating configuration without player for convenience method");
        }

        _playerName = [playerName copy];
        _player = player;
        _adConfig = adConfig;
        _isAdEnabled = (adConfig != nil);
        _customAttributes = customAttributes ? [customAttributes copy] : @{};
    }
    return self;
}

- (instancetype)initWithPlayerName:(NSString *)playerName
                            player:(id)player
                         adEnabled:(BOOL)isAdEnabled
                  customAttributes:(NSDictionary<NSString *, id> *)customAttributes {
    // Legacy path: adEnabled:YES means client-side ads (IMA).
    return [self initWithPlayerName:playerName
                             player:player
                           adConfig:(isAdEnabled ? [NRAdConfig csai] : nil)
                   customAttributes:customAttributes];
}

- (instancetype)initWithPlayerName:(NSString *)playerName
                            player:(id)player
                         adEnabled:(BOOL)isAdEnabled {
    return [self initWithPlayerName:playerName
                             player:player
                          adEnabled:isAdEnabled
                   customAttributes:nil];
}

- (instancetype)initWithPlayerName:(NSString *)playerName
                            player:(id)player {
    return [self initWithPlayerName:playerName
                             player:player
                          adEnabled:NO
                   customAttributes:nil];
}

- (instancetype)initWithPlayerName:(NSString *)playerName
                         adEnabled:(BOOL)isAdEnabled
                  customAttributes:(NSDictionary<NSString *, id> *)customAttributes {
    // Convenience method - calls main initializer with nil player
    return [self initWithPlayerName:playerName
                             player:nil
                          adEnabled:isAdEnabled
                   customAttributes:customAttributes];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"NRVAVideoPlayerConfiguration: playerName=%@, adEnabled=%@, customAttributes=%@",
            self.playerName, 
            self.isAdEnabled ? @"YES" : @"NO",
            self.customAttributes];
}

@end
