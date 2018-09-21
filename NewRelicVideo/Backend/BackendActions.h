//
//  BackendActions.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BackendActions : NSObject

@property (nonatomic) NSMutableDictionary *generalOptions;
@property (nonatomic) NSMutableDictionary<NSString *, NSMutableDictionary *> *actionOptions;

- (void)sendRequest;
- (void)sendStart;
- (void)sendEnd;
- (void)sendPause;
- (void)sendResume;
- (void)sendSeekStart;
- (void)sendSeekEnd;
- (void)sendBufferStart;
- (void)sendBufferEnd;
- (void)sendHeartbeat;
- (void)sendRenditionChange;
- (void)sendError:(NSString *)message;

- (void)sendAdRequest;
- (void)sendAdStart;
- (void)sendAdEnd;
- (void)sendAdPause;
- (void)sendAdResume;
- (void)sendAdSeekStart;
- (void)sendAdSeekEnd;
- (void)sendAdBufferStart;
- (void)sendAdBufferEnd;
- (void)sendAdHeartbeat;
- (void)sendAdRenditionChange;
- (void)sendAdError:(NSString *)message;;
- (void)sendAdBreakStart;
- (void)sendAdBreakEnd;
- (void)sendAdQuartile;
- (void)sendAdClick;

- (void)sendPlayerReady;
- (void)sendDownload;

- (void)sendAction:(NSString *)name;
- (void)sendAction:(NSString *)name attr:(NSDictionary *)dict;

@end
