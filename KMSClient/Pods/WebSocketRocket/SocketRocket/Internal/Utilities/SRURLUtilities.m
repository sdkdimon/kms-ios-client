//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRURLUtilities.h"

#import "SRHash.h"

NS_ASSUME_NONNULL_BEGIN

NSString *SRURLOrigin(NSURL *url)
{
    NSMutableString *origin = [NSMutableString string];

    NSString *scheme = url.scheme.lowercaseString;
    if ([scheme isEqualToString:@"wss"]) {
        scheme = @"https";
    } else if ([scheme isEqualToString:@"ws"]) {
        scheme = @"http";
    }
    [origin appendFormat:@"%@://%@", scheme, url.host];

    NSNumber *port = url.port;
    BOOL portIsDefault = (!port ||
                          ([scheme isEqualToString:@"http"] && port.integerValue == 80) ||
                          ([scheme isEqualToString:@"https"] && port.integerValue == 443));
    if (!portIsDefault) {
        [origin appendFormat:@":%@", port.stringValue];
    }
    return origin;
}

extern BOOL SRURLRequiresSSL(NSURL *url)
{
    NSString *scheme = url.scheme.lowercaseString;
    return ([scheme isEqualToString:@"wss"] || [scheme isEqualToString:@"https"]);
}

extern NSString *_Nullable SRBasicAuthorizationHeaderFromURL(NSURL *url)
{
    NSData *data = [[NSString stringWithFormat:@"%@:%@", url.user, url.password] dataUsingEncoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"Basic %@", SRBase64EncodedStringFromData(data)];
}

extern NSString *_Nullable SRStreamNetworkServiceTypeFromURLRequestNetworkService(NSURLRequestNetworkServiceType networkServiceType)
{
    switch (networkServiceType) {
        
        case NSURLNetworkServiceTypeVoIP: return NSStreamNetworkServiceTypeVoIP;
        case NSURLNetworkServiceTypeVideo: return NSStreamNetworkServiceTypeVideo;
        case NSURLNetworkServiceTypeBackground: return NSStreamNetworkServiceTypeBackground;
        case NSURLNetworkServiceTypeVoice: return NSStreamNetworkServiceTypeVoice;
        case NSURLNetworkServiceTypeDefault:
        case NSURLNetworkServiceTypeResponsiveData:
        case NSURLNetworkServiceTypeAVStreaming:
        case NSURLNetworkServiceTypeResponsiveAV: return nil;
        case NSURLNetworkServiceTypeCallSignaling: return NSStreamNetworkServiceTypeCallSignaling;
        default: return nil;
    }
}

NS_ASSUME_NONNULL_END
