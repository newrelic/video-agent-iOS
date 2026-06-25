//
//  MediaTailorSamples.h
//  SimplePlayerUsingPods
//
//  Sample stream URLs and helpers for exercising the NRMediaTailorTracker
//  module. None of these point at internal AWS infrastructure — you must
//  supply your own MediaTailor session URL (or one of the AWS-documented
//  public samples) before running the integration smoke test (T13).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaTailorSamples : NSObject

/// A MediaTailor HLS master URL. The host MUST contain "mediatailor" or
/// start with one of the documented segment-marker prefixes for the
/// tracker's detector to activate. Replace with your AWS account's actual
/// MediaTailor session URL before running.
+ (NSString *)defaultSampleURLString;

@end

NS_ASSUME_NONNULL_END
