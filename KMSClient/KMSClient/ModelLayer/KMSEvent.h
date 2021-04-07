// KMSEvent.h
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

#import <Mantle/Mantle.h>

#import <KMSClient/KMSEventType.h>
#import <KMSClient/KMSEventData.h>


@interface KMSEvent : MTLModel <MTLJSONSerializing>

@property(strong,nonatomic,readwrite) KMSEventData *data;
@property(strong,nonatomic,readwrite) NSString *object;
@property(assign,nonatomic,readwrite) KMSEventType type;

@end


@interface KMSEventICECandidate : KMSEvent

@property(strong,nonatomic,readwrite) KMSEventDataICECandidate *data;

@end


@interface KMSEventElementConnection : KMSEvent

@property(strong,nonatomic,readwrite) KMSEventDataElementConnection *data;

@end

@interface KMSEventMediaStateChanged : KMSEvent

@property(strong,nonatomic,readwrite) KMSEventDataMediaStateChanged *data;

@end
