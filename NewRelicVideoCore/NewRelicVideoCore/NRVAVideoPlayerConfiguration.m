//
//  NRVAVideoPlayerConfiguration.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAVideoPlayerConfiguration.h"

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
        
        if (!player) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:@"Player instance cannot be nil"
                                         userInfo:nil];
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

- (NSString *)description {
    return [NSString stringWithFormat:@"NRVAVideoPlayerConfiguration: playerName=%@, adEnabled=%@, customAttributes=%@",
            self.playerName, 
            self.isAdEnabled ? @"YES" : @"NO",
            self.customAttributes];
}

@end
