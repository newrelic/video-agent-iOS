#import "NRChrono.h"
#import <QuartzCore/QuartzCore.h> 

@interface NRChrono()

@property (nonatomic, assign) CFTimeInterval startTime;

@end

@implementation NRChrono

- (instancetype)init {
    self = [super init];
    if (self) {
        _startTime = 0;
    }
    return self;
}

- (void)start {
        self.startTime = CACurrentMediaTime();
}

- (NSTimeInterval)getDeltaTime {   
    if (self.startTime != 0) {
        CFTimeInterval currentInterval = CACurrentMediaTime() - self.startTime;
        return  currentInterval * 1000;
    } else {
        return 0;
    }
}

@end