// KMSLog.h
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

#import <KMSClient/KMSLogger.h>

#ifdef DEBUG
#   define KMSLog(lvl,fmt ...) [[KMSLog sharedInstance] logLevel:lvl format:fmt]
#else
#   define KMSLog(lvl,fmt ...)
#endif

NS_ASSUME_NONNULL_BEGIN

@interface KMSLog : NSObject

+ (instancetype)sharedInstance;

@property(strong,nonatomic,readwrite) id <KMSLogger> logger;

- (void)logLevel:(KMSLogMessageLevel)level format:(NSString *)format,...;

@end

NS_ASSUME_NONNULL_END
