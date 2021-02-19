//
//  NRVideoLog.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRVideoLog : NSObject

void AV_LOG(NSString *format, ...);

@end

NS_ASSUME_NONNULL_END
