//
//  MTStringHelpers.h
//  NRMediaTailorTracker
//
//  Small JSON-decode helpers shared across the Model layer's
//  fromDictionary: constructors.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Returns `dict[key]` if it's an `NSString`, else `nil`.
FOUNDATION_EXPORT NSString * _Nullable MTStringOrNil(NSDictionary * _Nullable dict, NSString *key);

NS_ASSUME_NONNULL_END
