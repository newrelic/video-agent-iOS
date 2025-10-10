//
//  NRVAVideoPlayerConfiguration.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAVideoPlayerConfiguration.h"
#import "Utils/NRVALog.h"


@implementation NRVAVideoPlayerConfiguration

- (instancetype)initWithPlayerName:(NSString *)playerName
                            player:(id)player
                         adEnabled:(BOOL)isAdEnabled
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
        _isAdEnabled = isAdEnabled;
        _customAttributes = customAttributes ? [customAttributes copy] : @{};
    }
    return self;
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
