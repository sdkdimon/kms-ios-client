// KMSAPIService.h
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

#import <Foundation/Foundation.h>

#import <RACObjC/RACObjC.h>

@class KMSRequestMessage;
@class KMSSessionConnectionMonitor;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, KMSSessionState) {
    KMSSessioStateClosed = 0,
    KMSSessioStateClosing,
    KMSSessioStateOpen,
    KMSSessioStateOpening
};

@interface KMSSession : NSObject

- (instancetype)initWithURL:(NSURL *)url;

@property (strong, nonatomic, readonly) NSURL *url;
@property (strong, nonatomic, readonly) RACSignal *eventSignal;
@property (strong, nonatomic, readonly) RACSignal *errorSignal;
@property (assign, nonatomic, readonly) KMSSessionState state;
@property (strong, nonatomic, readonly) NSString *sessionId;
@property (strong, nonatomic, readwrite) KMSSessionConnectionMonitor *connectionMonitor;

- (RACSignal *)sendMessageSignal:(KMSRequestMessage *)requestMessage;
- (RACSignal *)openSignal;
- (RACSignal *)closeSignal;

@end

NS_ASSUME_NONNULL_END
