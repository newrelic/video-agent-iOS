//
//  MTTrackingResponse.h
//  NRMediaTailorTracker
//
//  Top-level decoded response from `GET /v1/tracking/<sessionId>`. Owns the
//  avail list, non-linear avails, and (Bug B1) the pagination `nextToken` which
//  the tracking client must round-trip on the next call. First fetch sends
//  no token; server returns a token; subsequent fetches must include it.
//

#import <Foundation/Foundation.h>

@class MTAvail;
@class MTNonLinearAvail;

NS_ASSUME_NONNULL_BEGIN

@interface MTTrackingResponse : NSObject

@property (nonatomic, copy, readonly) NSArray<MTAvail *> *avails;
@property (nonatomic, copy, readonly) NSArray<MTNonLinearAvail *> *nonLinearAvails;

/// Bug B1 — pagination token. Nil on first fetch; populated by server on each
/// response; the next request MUST send the last received value back.
@property (nonatomic, copy, readonly, nullable) NSString *nextToken;

- (instancetype)initWithAvails:(NSArray<MTAvail *> *)avails
               nonLinearAvails:(NSArray<MTNonLinearAvail *> *)nonLinearAvails
                     nextToken:(nullable NSString *)nextToken NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Convenience: parse from `NSData` (raw HTTP body). Returns nil on parse failure.
+ (nullable instancetype)fromJSONData:(NSData *)data error:(NSError **)error;

/// Build from a parsed dictionary (top-level tracking JSON).
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
