//
//  NRTimeSince.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 15/12/2020.
//

#import "NRTimeSince.h"

@interface NRTimeSince ()

@property (nonatomic) NSString *action;
@property (nonatomic) NSString *attributeName;
@property (nonatomic) NSString *filter;
@property (nonatomic) NSTimeInterval timestamp;

@end

@implementation NRTimeSince

- (instancetype)initWithAction:(NSString *)action attribute:(NSString *)attribute applyTo:(NSString *)filter {
    if (self = [super init]) {
        self.action = action;
        self.attributeName = attribute;
        self.filter = filter;
        self.timestamp = 0;
    }
    return self;
}

- (BOOL)isAction:(NSString *)action {
    return [self.action isEqual:action];
}

- (BOOL)isMatch:(NSString *)action {
    NSError  *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:self.filter options:0 error:&error];
    NSRange range = [regex rangeOfFirstMatchInString:action options:0 range:NSMakeRange(0, action.length)];
    return (range.location == 0 && range.length == action.length);
}

- (void)now {
    self.timestamp = [[NSDate date] timeIntervalSince1970];
}

- (NSNumber *)timeSince {
    if (self.timestamp > 0) {
        return @((long)(1000.0f * ([[NSDate date] timeIntervalSince1970] - self.timestamp)));
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

@end
