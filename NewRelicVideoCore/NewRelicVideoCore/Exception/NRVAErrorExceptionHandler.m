//
//  NRVAErrorExceptionHandler.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAErrorExceptionHandler.h"

// Default error code for unhandled exceptions
static const NSInteger DEFAULT_ERROR_CODE = -9999;

@interface NRVAErrorExceptionHandler ()

@property (nonatomic, readwrite) NSInteger errorCode;
@property (nonatomic, readwrite) NSString *errorMessage;
@property (nonatomic, readwrite) NSString *errorDomain;

@end

@implementation NRVAErrorExceptionHandler

- (instancetype)initWithError:(NSError *)error {
    self = [super init];
    if (self) {
        [self processError:error];
    }
    return self;
}

- (instancetype)initWithException:(NSException *)exception {
    self = [super init];
    if (self) {
        [self processException:exception];
    }
    return self;
}

- (void)processError:(NSError *)error {
    self.errorCode = DEFAULT_ERROR_CODE;
    self.errorMessage = error.localizedDescription ?: @"Unknown error";
    self.errorDomain = error.domain;
    
    if (!error) {
        return;
    }
    
    // Use original error code and message directly
    self.errorCode = (NSInteger)error.code;
    self.errorMessage = error.localizedDescription ?: error.description ?: @"Unknown error";
    self.errorDomain = error.domain;
}

- (void)processException:(NSException *)exception {
    self.errorCode = DEFAULT_ERROR_CODE;
    self.errorMessage = exception.reason ?: @"Unknown exception";
    self.errorDomain = @"Exception";
    
    if (!exception) {
        return;
    }
    
    // Use original exception name and reason directly
    self.errorMessage = exception.reason ?: exception.name ?: @"Unknown exception";
}

@end