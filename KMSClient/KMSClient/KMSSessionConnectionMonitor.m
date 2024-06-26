// KMSSessionConnectionMonitor.m
// Copyright (c) 2016 Dmitry Lizin (sdkdimon@gmail.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "KMSSessionConnectionMonitor.h"

@interface KMSSessionConnectionMonitorTimer : NSObject

+ (instancetype)timerWithTimeInterval:(NSTimeInterval)timeInterval;
- (instancetype)initWithTimeInterval:(NSTimeInterval)timeInterval;

@property (assign, nonatomic, readonly) NSTimeInterval timeInterval;

- (void)startTimer:(void (^)(void))block;
- (void)cancelTimer;

@end

dispatch_source_t CreateDispatchTimer(double interval, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (timer)
    {
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, interval * NSEC_PER_SEC), interval * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    return timer;
}


@implementation KMSSessionConnectionMonitorTimer
{
    dispatch_source_t _timer;
}

+ (instancetype)timerWithTimeInterval:(NSTimeInterval)timeInterval
{
    return [[self alloc] initWithTimeInterval:timeInterval];
}
- (instancetype)initWithTimeInterval:(NSTimeInterval)timeInterval
{
    self = [super init];
    if (self != nil)
    {
        _timeInterval = timeInterval;
    }
    return self;
}


- (void)startTimer:(void (^)(void))block
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    double secondsToFire = _timeInterval;
    _timer = CreateDispatchTimer(secondsToFire, queue, ^{
        dispatch_async(dispatch_get_main_queue(), block);
    });
}

- (void)cancelTimer
{
    if (_timer)
    {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

- (void)dealloc
{
    [self cancelTimer];
}

@end

static NSString * const KMS_SESSION_CONNECTION_MONITOR_DATA = @"kms_session_connection_monitor_data";

@interface KMSSessionConnectionMonitor ()

@property (strong, nonatomic, readwrite) KMSSessionConnectionMonitorTimer *timer;
@property (assign, nonatomic, readwrite) NSUInteger count;

@end

@implementation KMSSessionConnectionMonitor

- (instancetype)initWithPingTimeInterval:(NSTimeInterval)pingTimeInterval pingFailCount:(NSUInteger)pingFailCount
{
    self = [super init];
    if (self != nil)
    {
        _pingTimeInterval = pingTimeInterval;
        _pingFailCount = pingFailCount;
    }
    return self;
}

- (void)start
{
    __weak typeof (self) welf = self;
    _timer = [[KMSSessionConnectionMonitorTimer alloc] initWithTimeInterval:_pingTimeInterval];
    [_timer startTimer:^{
        [welf sendPing];
        welf.count++;
    }];
}

- (void)stop
{
    [_timer cancelTimer];
    _timer = nil;
    _count = 0;
}

- (void)sendPing
{
    if (self.count < _pingFailCount)
    {
        NSData *data = [KMS_SESSION_CONNECTION_MONITOR_DATA dataUsingEncoding:NSUTF8StringEncoding];
        [self.ping sendPing:data];
    }
    else
    {
        [self stop];
        [self.ping didFailReceivePong];
    }
}

- (void)didReceivePong:(NSData *)pongPayload
{
    NSString *dataString = [[NSString alloc] initWithData:pongPayload encoding:NSUTF8StringEncoding];
    if ([dataString isEqualToString:KMS_SESSION_CONNECTION_MONITOR_DATA])
    {
        self.count = 0;
    }
}

@end
