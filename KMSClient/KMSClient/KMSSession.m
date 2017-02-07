// KMSAPIService.m
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

#import "KMSSession.h"
#import <SocketRocket/SRWebSocket.h>
#import "KMSResponseMessage.h"
#import "KMSRequestMessage.h"
#import "KMSLog.h"

@interface KMSSession () <SRWebSocketDelegate>

@property(strong,nonatomic,readwrite) NSString *sessionId;

@property(strong,nonatomic,readwrite) RACCompoundDisposable *subscriptionDisposables;

@property (strong, nonatomic, readwrite) SRWebSocket *webSocket;


@property(assign,nonatomic,readwrite) KMSSessionState state;

@property (strong, nonatomic, readwrite) RACSubject *websocketDidReceiveMessageSubject;
@property (strong, nonatomic, readwrite) RACSubject *websocketDidOpenSubject;
@property (strong, nonatomic, readwrite) RACSubject *websocketDidCloseSubject;
@property (strong, nonatomic, readwrite) RACSubject *websocketDidFailWithErrorSubject;

@end

@implementation KMSSession

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self != nil)
    {
        _url = url;
        _websocketDidReceiveMessageSubject = [RACSubject subject];
        _websocketDidOpenSubject = [RACSubject subject];
        _websocketDidCloseSubject = [RACSubject subject];
        _websocketDidFailWithErrorSubject = [RACSubject subject];
        
        _eventSignal =
        [[_websocketDidReceiveMessageSubject filter:^BOOL(RACTuple *args) {
            KMSMessage *message = [args second];
            return [message identifier] == nil;
        }] map:^id(RACTuple *args) {
            KMSRequestMessageEvent *message = [args second];
            return [[message params] value];
        }];
    }
    return self;
}

- (SRWebSocket *)createWebSocket
{
    SRWebSocket *webSocket = [[SRWebSocket alloc] initWithURL:_url];
    [webSocket setDelegate:self];
    [self setWebSocket:webSocket];
    return webSocket;
}

- (void)disposeWebsocket
{
    _webSocket = nil;
}


- (RACSignal *)openIfNeededSignal
{
    switch (_state) {
            
        case KMSSessioStateClosed:
        {
            return [self openSignal];
            
        }
            
        case KMSSessioStateClosing:
        {
            return [RACSignal error:nil];
        }
            
        case KMSSessioStateOpen:
        {
            return [RACSignal return:nil];
        }
            
        case KMSSessioStateOpening:
        {
            return [RACSignal error:nil];
        }
            
        default:
        {
            return [RACSignal error:nil];
        }
    }
    
}



- (RACSignal *)sendMessageSignal:(KMSRequestMessage *)message
{
    RACSignal *openIfNeededSignal = [self openIfNeededSignal];
    @weakify(self);
    RACSignal *sendMesageSignal =
    [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self);
        RACSignal *webSocketDidReceiveMessageSignal = [self websocketDidReceiveMessageSubject];
        RACSignal *webSocketDidFailWithErrorSignal = [self websocketDidFailWithErrorSubject];
        
        RACCompoundDisposable *cloeseSignalDisposable = [RACCompoundDisposable compoundDisposable];
        
        RACDisposable *webSocketDidReceiveMessageSignalDisposable =
        [webSocketDidReceiveMessageSignal subscribeNext:^(RACTuple *args) {
            KMSResponseMessage *responseMessage = [args second];
            NSString *responseMessageId = [responseMessage identifier];
            if (responseMessageId != nil  && [responseMessageId isEqualToString:[message identifier]])
            {
                KMSResponseMessageResult *responseMessageResult = [responseMessage result];
                [self setSessionId:[responseMessageResult sessionId]];
                [subscriber sendNext:[responseMessageResult value]];
                [subscriber sendCompleted];
            }
        }];
        RACDisposable *webSocketDidFailWithErrorSignalDisposable =
        [webSocketDidFailWithErrorSignal subscribeNext:^(RACTuple *args) {
            NSError *error = [args second];
            [subscriber sendError:error];
        }];
        
        [cloeseSignalDisposable addDisposable:webSocketDidReceiveMessageSignalDisposable];
        [cloeseSignalDisposable addDisposable:webSocketDidFailWithErrorSignalDisposable];
        
        NSData *messageData = [self transformRequestMessage:message];
        [[self webSocket] send:messageData];
        
        return cloeseSignalDisposable;
    }];
    
    
    return [[openIfNeededSignal ignoreValues] concat:sendMesageSignal]; //sendMesageSignal;
}


- (RACSignal *)closeSignal
{
    @weakify(self);
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self);
        KMSSessionState oldState = [self state];
        [self setState:KMSSessioStateClosing];
        RACSignal *webSocketDidCloseSignal = [self websocketDidCloseSubject];
        RACSignal *webSocketDidFailWithErrorSignal = [self websocketDidFailWithErrorSubject];
        
        RACCompoundDisposable *cloeseSignalDisposable = [RACCompoundDisposable compoundDisposable];
        RACDisposable *webSocketDidCloseSignalDisposable =
        [webSocketDidCloseSignal subscribeNext:^(RACTuple *args) {
            [self setState:KMSSessioStateClosed];
            [self disposeWebsocket];
            [subscriber sendNext:nil];
            [subscriber sendCompleted];
        }];
        
        RACDisposable *webSocketDidFailWithErrorSignalDisposable =
        [webSocketDidFailWithErrorSignal subscribeNext:^(RACTuple *args) {
            [self setState:oldState];
            [subscriber sendError:[args second]];
        }];
        
        [cloeseSignalDisposable addDisposable:webSocketDidCloseSignalDisposable];
        [cloeseSignalDisposable addDisposable:webSocketDidFailWithErrorSignalDisposable];
        
        [[self webSocket] close];
        
        return cloeseSignalDisposable;
    }];
}


- (RACSignal *)openSignal
{
    @weakify(self);
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self);
        KMSSessionState oldState = [self state];
        [self setState:KMSSessioStateOpening];
        RACSignal *webSocketDidOpenSignal = [self websocketDidOpenSubject];
        RACSignal *webSocketDidFailWithErrorSignal = [self websocketDidFailWithErrorSubject];
        
        RACCompoundDisposable *openSignalDisposable = [RACCompoundDisposable compoundDisposable];
        
        RACDisposable *webSocketDidOpenSignalDisposable =
        [webSocketDidOpenSignal subscribeNext:^(RACTuple *args) {
            [self setState:KMSSessioStateOpen];
            [subscriber sendNext:nil];
            [subscriber sendCompleted];
        }];
        
        RACDisposable *webSocketDidFailWithErrorSignalDisposable =
        [webSocketDidFailWithErrorSignal subscribeNext:^(RACTuple *args) {
            [self setState:oldState];
            [subscriber sendError:[args second]];
        }];
        
        [openSignalDisposable addDisposable:webSocketDidOpenSignalDisposable];
        [openSignalDisposable addDisposable:webSocketDidFailWithErrorSignalDisposable];
        
        [[self createWebSocket] open];
        
        return openSignalDisposable;
    }];
}

#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(NSData *)message
{
    KMSMessage *messageModel = [self transformResponseMessage:message];
    [_websocketDidReceiveMessageSubject sendNext:RACTuplePack(webSocket, messageModel)];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    [_websocketDidOpenSubject sendNext:RACTuplePack(webSocket)];
}
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    [_websocketDidFailWithErrorSubject sendNext:RACTuplePack(webSocket, error)];
}
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [_websocketDidCloseSubject sendNext:RACTuplePack(webSocket, @(code), reason, @(wasClean))];
}
- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload
{
    
}

// Return YES to convert messages sent as Text to an NSString. Return NO to skip NSData -> NSString conversion for Text messages. Defaults to YES.
- (BOOL)webSocketShouldConvertTextFrameToString:(SRWebSocket *)webSocket
{
    return NO;
}


#pragma mark MessageTransformer

- (NSData *)transformRequestMessage:(KMSRequestMessage *)message{
    NSDictionary *jsonObject = [MTLJSONAdapter JSONDictionaryFromModel:message error:nil];
    KMSLog(KMSLogMessageLevelVerbose,@"Kurento API client will send message \n%@",jsonObject);
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:nil];
}

- (KMSMessage *)transformResponseMessage:(NSData *)message{
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:message options:0 error:nil];
    KMSLog(KMSLogMessageLevelVerbose,@"Kurento API client did receive message \n%@",jsonObject);
    return [MTLJSONAdapter modelOfClass:[KMSMessage class] fromJSONDictionary:jsonObject error:nil];
}




//+ (instancetype)sessionWithWebSocketClient:(RACSRWebSocket *)wsClient{
//    return [[self alloc] initWithWebSocketClient:wsClient];
//}
//
//- (instancetype)initWithWebSocketClient:(RACSRWebSocket *)wsClient{
//    if((self = [super init]) != nil){
//        _wsClient = wsClient;
//        _state = KMSSessionStateConnecting;
//        _subscriptionDisposables = [RACCompoundDisposable compoundDisposable];
//        @weakify(self);
//        [_subscriptionDisposables addDisposable:
//        [[wsClient webSocketDidCloseSignal] subscribeNext:^(id x) {
//            @strongify(self);
//            [self setState:KMSSessionStateClosed];
//        }]];
//        
//        [_subscriptionDisposables addDisposable:
//        [[wsClient webSocketDidOpenSignal] subscribeNext:^(id x) {
//            @strongify(self);
//            [self setState:KMSSessionStateOpen];
//        }]];
//        
//        _eventSignal =
//        [[[wsClient webSocketDidReceiveMessageSignal] filter:^BOOL(RACTuple *args) {
//            KMSMessage *message = [args second];
//            return [message identifier] == nil;
//        }] map:^id(RACTuple *args) {
//            KMSRequestMessageEvent *message = [args second];
//            return [[message params] value];
//        }];
//        
//        [wsClient setMessageTransformer:self];
//    }
//    return self;
//}
//
//
//- (RACSignal *)sendMessage:(KMSRequestMessage *)requestMessage{
//    @weakify(self);
//    RACSignal *sendMessageSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
//        @strongify(self);
//        RACSignal *wsMessageSignal =
//        [[[self wsClient] webSocketDidReceiveMessageSignal] filter:^BOOL(RACTuple *args) {
//            KMSMessage *message = [args second];
//            NSString *messageId = [message identifier];
//            return (messageId != nil && [messageId isEqualToString:[requestMessage identifier]]);
//        }];
//        
//        RACSignal *wsErrorSignal = [[self wsClient] webSocketDidFailSignal];
//        
//        RACDisposable *wsMessageSignalDisposable =
//        [wsMessageSignal subscribeNext:^(RACTuple *args) {
//            KMSResponseMessage *responseMessage = [args second];
//            NSError *responseError = [responseMessage error];
//            if(responseError == nil){
//                KMSResponseMessageResult *responseMessageResult = [responseMessage result];
//                [self setSessionId:[responseMessageResult sessionId]];
//                [subscriber sendNext:[responseMessageResult value]];
//                [subscriber sendCompleted];
//            } else{
//                [subscriber sendError:responseError];
//            }
//        }];
//        
//        RACDisposable *wsErrorSignalDisposable =
//        [wsErrorSignal subscribeNext:^(RACTuple *args) {
//            [subscriber sendError:[args second]];
//         }];
//    
//        [[[self wsClient] sendDataCommand] execute:requestMessage];
//        
//        return [RACCompoundDisposable compoundDisposableWithDisposables:@[wsMessageSignalDisposable,wsErrorSignalDisposable]];
//    }];
//    
//    return sendMessageSignal;
//    
//}
//
//- (RACSignal *)close{
//    return [[self wsClient] closeConnectionSignal];
//}
//
//- (void)dealloc{
//    [[self subscriptionDisposables] dispose];
//}
//
//#pragma mark RACSRWebSocketMessageTransformer
//
//- (id)websocket:(RACSRWebSocket *)websocket transformRequestMessage:(KMSRequestMessage *)message{
//    NSDictionary *jsonObject = [MTLJSONAdapter JSONDictionaryFromModel:message error:nil];
//    KMSLog(KMSLogMessageLevelVerbose,@"Kurento API client will send message \n%@",jsonObject);
//    return [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:nil];
//}
//
//- (id)websocket:(RACSRWebSocket *)websocket transformResponseMessage:(NSString *)message{
//    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
//    KMSLog(KMSLogMessageLevelVerbose,@"Kurento API client did receive message \n%@",jsonObject);
//    return [MTLJSONAdapter modelOfClass:[KMSMessage class] fromJSONDictionary:jsonObject error:nil];
//}



@end
