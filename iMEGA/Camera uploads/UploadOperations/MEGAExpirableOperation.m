
#import "MEGAExpirableOperation.h"

@interface MEGAExpirableOperation ()

@property (strong, nonatomic) NSTimer *watchTimer;
@property (nonatomic) NSTimeInterval expireTimeInterval;

@end

@implementation MEGAExpirableOperation

- (instancetype)initWithExpirationTimeInterval:(NSTimeInterval)timeInterval {
    self = [super initWithBackgroundTaskExpirationHandler:nil];
    if (self) {
        _expireTimeInterval = timeInterval;
    }
    return self;
}

- (void)start {
    [super start];
    
    __weak __typeof__(self) weakSelf = self;
    self.watchTimer = [NSTimer scheduledTimerWithTimeInterval:self.expireTimeInterval repeats:NO block:^(NSTimer * _Nonnull timer) {
        MEGALogDebug(@"%@ expired after time interval %.2f", NSStringFromClass(weakSelf.class), self.expireTimeInterval);
        [weakSelf finishOperation];
    }];
}

- (void)finishOperation {
    [super finishOperation];
    [self.watchTimer invalidate];
}


@end
