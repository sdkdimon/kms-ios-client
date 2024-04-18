// KMSRACSubject.m
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

#import "KMSRACSubject.h"

#import <RACObjC/RACEXTScope.h>
#import <RACObjC/RACCompoundDisposable.h>
#import <RACObjC/RACPassthroughSubscriber.h>

@interface KMSRACSubject ()

// Contains all current subscribers to the receiver.
//
// This should only be used while synchronized on `self`.
@property (nonatomic, strong, readonly) NSMutableArray *subscribers;

// Contains all of the receiver's subscriptions to other signals.
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

// Enumerates over each of the receiver's `subscribers` and invokes `block` for
// each.
- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block;

@end

@implementation KMSRACSubject

- (NSUInteger)subscribersCount
{
    @synchronized (self) {
        return self.subscribers.count;
    }
}

#pragma mark Lifecycle

+ (instancetype)subject {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self == nil) return nil;
    
    _disposable = [RACCompoundDisposable compoundDisposable];
    _subscribers = [[NSMutableArray alloc] initWithCapacity:1];
    
    return self;
}

- (void)dealloc {
    [self.disposable dispose];
}

#pragma mark Subscription

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
    
    RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    subscriber = [[RACPassthroughSubscriber alloc] initWithSubscriber:subscriber signal:self disposable:disposable];
    
    NSMutableArray *subscribers = self.subscribers;
    @synchronized (subscribers) {
        [subscribers addObject:subscriber];
    }
    
    [disposable addDisposable:[RACDisposable disposableWithBlock:^{
        @synchronized (subscribers) {
            // Since newer subscribers are generally shorter-lived, search
            // starting from the end of the list.
            NSUInteger index = [subscribers indexOfObjectWithOptions:NSEnumerationReverse passingTest:^ BOOL (id<RACSubscriber> obj, NSUInteger index, BOOL *stop) {
                return obj == subscriber;
            }];
            
            if (index != NSNotFound) [subscribers removeObjectAtIndex:index];
        }
    }]];
    
    return disposable;
}

- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block {
    NSArray *subscribers;
    @synchronized (self.subscribers) {
        subscribers = [self.subscribers copy];
    }
    
    for (id<RACSubscriber> subscriber in subscribers) {
        block(subscriber);
    }
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
    [self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
        [subscriber sendNext:value];
    }];
}

- (void)sendError:(NSError *)error {
    [self.disposable dispose];
    
    [self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
        [subscriber sendError:error];
    }];
}

- (void)sendCompleted {
    [self.disposable dispose];
    
    [self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
        [subscriber sendCompleted];
    }];
}

- (void)didSubscribeWithDisposable:(RACCompoundDisposable *)d {
    if (d.disposed) return;
    [self.disposable addDisposable:d];
    
    @weakify(self, d);
    [d addDisposable:[RACDisposable disposableWithBlock:^{
        @strongify(self, d);
        [self.disposable removeDisposable:d];
    }]];
}

@end
