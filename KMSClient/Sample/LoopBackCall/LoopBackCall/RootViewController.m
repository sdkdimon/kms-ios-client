// RootViewController.m
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

#import "RootViewController.h"
#import "CallViewController.h"

#import <WebRTC/RTCEAGLVideoView.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCPeerConnection.h>
#import <WebRTC/RTCMediaStream.h>
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCSessionDescription.h>
#import <WebRTC/RTCIceCandidate.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCAVFoundationVideoSource.h>
#import <WebRTC/RTCICEServer.h>
#import <WebRTC/RTCConfiguration.h>
#import <WebRTC/RTCDispatcher.h>

#import <KMSClient/KMSSession.h>
#import <KMSClient/KMSMediaPipeline.h>
#import <KMSClient/KMSWebRTCEndpoint.h>

#import <KMSClient/KMSMessageFactoryMediaPipeline.h>
#import <KMSClient/KMSMessageFactoryWebRTCEndpoint.h>
#import <KMSClient/KMSICECandidate.h>
#import <KMSClient/KMSEvent.h>
#import <RACObjC_UI/RACObjC_UI.h>

#import <KMSClient/KMSLog.h>


@interface KurentoLogger : NSObject <KMSLogger>

@end

@implementation KurentoLogger

-(void)logMessage:(NSString *)message level:(KMSLogMessageLevel)level{
    NSLog(@"%@",message);
}

@end

static NSString * const WS_PREFIX = @"ws";
static NSString * const WS_USER_DEFAULTS_KEY = @"wsURL";

enum{
    URLComponentInputNone = 0,
    URLCompontntInputHost,
    URLCompontntInputPort,
    URLCompontntInputPath
};

@interface RootViewController () <UITextFieldDelegate,CallViewControllerDelegate,RTCPeerConnectionDelegate>

@property(strong,nonatomic,readwrite) RTCPeerConnectionFactory *peerConnectionFactory;
@property(strong,nonatomic,readwrite) RTCPeerConnection *peerConnection;

@property(strong,nonatomic,readwrite) KMSWebRTCEndpoint *webRTCEndpoint;
@property(strong,nonatomic,readwrite) KMSMediaPipeline *mediaPipeline;
@property(strong,nonatomic,readwrite) KMSSession *kurentoSession;

@property (weak, nonatomic) IBOutlet UITextField *wsHostTextField;
@property (weak, nonatomic) IBOutlet UITextField *wsPortTextField;
@property (weak, nonatomic) IBOutlet UITextField *wsPathTextField;
@property (weak, nonatomic) IBOutlet UILabel *wsPreviewLabel;

@property (weak, nonatomic) IBOutlet UIButton *makeCallButton;

@property(strong,nonatomic,readwrite) NSURLComponents *wsServerURLComponents;


@property(strong,nonatomic,readwrite) NSUserDefaults *userDefaults;

@property(weak,nonatomic,readwrite) CallViewController *callViewController;


@end

@implementation RootViewController

#pragma mark Initialization

-(instancetype)init{
    if((self = [super init]) != nil){
       // [self initialize];
    }
    return self;
}

-(instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    if((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) != nil){
       // [self initialize];
    }
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder{
    if((self = [super initWithCoder:aDecoder]) != nil){
        //[self initialize];
        
    }
    return self;
}


-(void)initialize{
    [[KMSLog sharedInstance] setLogger:[[KurentoLogger alloc] init]];
    _peerConnectionFactory = [[RTCPeerConnectionFactory alloc] init];
    _userDefaults = [NSUserDefaults standardUserDefaults];
    [self loadViewURLS];
}

-(RTCPeerConnection *)initializePeerConnectionWithFactory:(RTCPeerConnectionFactory *)factory{
    RTCConfiguration *peerConnectionconf = [[RTCConfiguration alloc] init];
    return [_peerConnectionFactory peerConnectionWithConfiguration:peerConnectionconf constraints:[self defaultPeerConnectionConstraints] delegate:self];
}

-(void)saveURLS{
    NSString *wsURL = [[_wsServerURLComponents URL] absoluteString];
    [_userDefaults setObject:wsURL forKey:WS_USER_DEFAULTS_KEY];
    [_userDefaults synchronize];
}

-(void)loadViewURLS{
    NSString *wsURL = [_userDefaults objectForKey:WS_USER_DEFAULTS_KEY];
    _wsServerURLComponents = (wsURL == nil) ? [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%@://sample:0/endpoint",WS_PREFIX]] : [NSURLComponents componentsWithString:wsURL];
}



-(void)configureViews{
    [_wsHostTextField setTag:URLCompontntInputHost];
    [_wsPortTextField setTag:URLCompontntInputPort];
    [_wsPathTextField setTag:URLCompontntInputPath];
    [_wsPortTextField setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
    [_wsPathTextField setDelegate:self];
    [_wsHostTextField setDelegate:self];
    [_wsPortTextField setDelegate:self];
}


-(void)setupBindings{
    [_wsHostTextField setText:[_wsServerURLComponents host]];
    [_wsPathTextField setText:[_wsServerURLComponents path]];
    [_wsPortTextField setText:[[_wsServerURLComponents port] stringValue]];
    [_wsPreviewLabel setText:[[_wsServerURLComponents URL] absoluteString]];
  
    @weakify(self);
    RACSignal *wsHostChangeSignal = [[_wsHostTextField rac_textSignal] skip:1];
    
    [wsHostChangeSignal subscribeNext:^(NSString *text) {
        @strongify(self);
        [[self wsServerURLComponents] setHost:text];
    }];
    
    RACSignal *wsPortChangedSignal = [[_wsPortTextField rac_textSignal] skip:1];
    [wsPortChangedSignal subscribeNext:^(NSString *text) {
        @strongify(self);
        [[self wsServerURLComponents] setPort:@([text integerValue])];
    }];
    
    RACSignal *wsPathChangedSignal = [[_wsPathTextField rac_textSignal] skip:1];
    
    [[wsPathChangedSignal filter:^BOOL(NSString *text) {
        return ![text hasPrefix:@"/"] && [text length]>0;
    }] subscribeNext:^(NSString *text) {
        @strongify(self);
        [[self wsPathTextField] setText:[NSString stringWithFormat:@"/%@",text]];
    }];
    
    [wsPathChangedSignal subscribeNext:^(NSString *text) {
        @strongify(self);
        [[self wsServerURLComponents] setPath:text];
    }];
    
    RACSignal *wsURLChanged = [RACSignal merge:@[wsHostChangeSignal,wsPortChangedSignal,wsPathChangedSignal]];
    
    [wsURLChanged subscribeNext:^(id x) {
        @strongify(self);
        [[self wsPreviewLabel] setText:[[[self wsServerURLComponents] URL] absoluteString]];
    }];
    
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [self initialize];
    [self configureViews];
    [self setupBindings];
}


- (RTCMediaStream *)createLocalMediaStream {
    
    
    RTCMediaStream* localStream = [_peerConnectionFactory mediaStreamWithStreamId:@"ARDAMS"];
    RTCVideoTrack* localVideoTrack = [self createLocalVideoTrack];
    if (localVideoTrack) {
        [localStream addVideoTrack:localVideoTrack];
    }
    [localStream addAudioTrack:[_peerConnectionFactory audioTrackWithTrackId:@"ARDAMSa0"]];
    return localStream;
}

- (RTCVideoTrack *)createLocalVideoTrack {
    RTCVideoTrack* localVideoTrack = nil;
    RTCMediaConstraints *mediaConstraints = [self defaultMediaStreamConstraints];
    RTCAVFoundationVideoSource *source = [_peerConnectionFactory avFoundationVideoSourceWithConstraints:mediaConstraints];
  
    localVideoTrack = [_peerConnectionFactory videoTrackWithSource:source trackId:@"ARDAMSv0"];
    
    return localVideoTrack;
}

-(void)createOffer{
    
    RTCMediaStream *localMediaStream = [self createLocalMediaStream];
    
    CallViewController *callViewController = [[CallViewController alloc] init];
    [callViewController setDelegate:self];
    [callViewController setLocalMediaStream:localMediaStream];
    
    [self showCallViewController:callViewController];
    [self setCallViewController:callViewController];
    
    
    
    [_peerConnection addStream:localMediaStream];
    @weakify(self);
    [_peerConnection offerForConstraints:[self defaultOfferConstraints] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        NSLog(@"is main thread %@", [NSThread isMainThread] ? @"YES": @"NO");
       [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeMain block:^{
            NSLog(@"is main thread %@", [NSThread isMainThread] ? @"YES": @"NO");
           @strongify(self);
            [[self peerConnection] setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
               [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeMain block:^{
                    KMSWebRTCEndpoint *webRTCSession = [self webRTCEndpoint];
                    RACSignal *processSDPOfferAndGatherICECandidates =
                    [[[webRTCSession processOffer:[sdp sdp]]
                     flattenMap:^RACSignal *(NSString *remoteSDP) {
                         @strongify(self);
                         return  [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
                             RTCSessionDescription *remoteDesc = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:remoteSDP];
                             [[self peerConnection] setRemoteDescription:remoteDesc completionHandler:^(NSError * _Nullable error) {
                                [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeMain block:^{
                                     if (error == nil){
                                         [subscriber sendNext:nil];
                                         [subscriber sendCompleted];
                                     } else{
                                         [subscriber sendError:error];
                                     }
                                      NSLog(@"setRemoteDescription completion error %@",error);
                                 }];
                                 
                             }];
                             return nil;
                         }];
                     }] flattenMap:^RACSignal *(id value) {
                         return [webRTCSession gatherICECandidates];
                     }];
                    
                    [processSDPOfferAndGatherICECandidates subscribeError:^(NSError *error) {
                        NSLog(@"error process sdp offer %@",error);
                    }completed:^{
                        NSLog(@"complete processs offer. Started gathering ICE candidates....");
                    }];
                }];

            }];
        }];

    }];


}


- (IBAction)makeCall:(UIButton *)sender {
    [self saveURLS];
    _kurentoSession = [[KMSSession alloc] initWithURL:[_wsServerURLComponents URL]];
    _mediaPipeline = [KMSMediaPipeline pipelineWithKurentoSession:_kurentoSession];
    
    RACSignal *createMediaPipelineSignal = [_mediaPipeline create];
    
    @weakify(self);
    [createMediaPipelineSignal subscribeNext:^(NSString *mediaPipelineId) {
        @strongify(self);
        [self initializeWebRTCEndpoint:mediaPipelineId];
        
    }];
}


-(void)initializeWebRTCEndpoint:(NSString *)mediaPipelineId{
    
    _webRTCEndpoint = [KMSWebRTCEndpoint endpointWithKurentoSession:_kurentoSession mediaPipelineId:mediaPipelineId];
    _peerConnection = [self initializePeerConnectionWithFactory:_peerConnectionFactory];
    
    @weakify(self);
    RACSignal *createAndConnectWebRTCEndpointSignal =
    [[[[[[[_mediaPipeline create] flattenMap:^RACSignal *(NSString *mediaPipelineId) {
        @strongify(self);
        return [[self webRTCEndpoint] create];
    }] flattenMap:^RACSignal *(id value) {
        @strongify(self);
        return [[self webRTCEndpoint] subscribe:KMSEventTypeOnICECandidate];
    }]  flattenMap:^RACSignal *(id value) {
        @strongify(self);
        return [[self webRTCEndpoint] subscribe:KMSEventTypeMediaElementDisconnected];
    }] flattenMap:^RACSignal *(id value) {
        @strongify(self);
        return [[self webRTCEndpoint] subscribe:KMSEventTypeMediaElementConnected];
    }] flattenMap:^RACSignal *(id value) {
        @strongify(self);
        return [[self webRTCEndpoint] subscribe:KMSEventTypeMediaStateChanged];
    }] flattenMap:^RACSignal *(id value) {
        @strongify(self);
        return [[self webRTCEndpoint] connect:[[self webRTCEndpoint] identifier]];
    }];
    
    [createAndConnectWebRTCEndpointSignal subscribeError:^(NSError *error) {
        NSLog(@"error %@",error);
    } completed:^{
        @strongify(self);
        [[[self webRTCEndpoint] getSourceConnections] subscribeNext:^(id x) {
            [self createOffer];
        } completed:^{
            
        }];
        
        
        
    }];
    
    [[[self webRTCEndpoint] eventSignalForEvent:KMSEventTypeOnICECandidate] subscribeNext:^(KMSEventDataICECandidate *eventData) {
        @strongify(self);
        KMSICECandidate *kmsICECandidate = [eventData candidate];
        
        RTCIceCandidate *peerICECandidate = [[RTCIceCandidate alloc] initWithSdp:[kmsICECandidate candidate] sdpMLineIndex:(int)[kmsICECandidate sdpMLineIndex] sdpMid:[kmsICECandidate sdpMid]];
        [[self peerConnection] addIceCandidate:peerICECandidate];
        
        NSLog(@"");
    }];
    
    
//    [[[self webRTCEndpoint] eventSignalForEvent:KMSEventTypeMediaElementConnected] subscribeNext:^(id x) {
//        NSLog(@"");
//    }];
//    
//    [[[self webRTCEndpoint] eventSignalForEvent:KMSEventTypeMediaElementDisconnected] subscribeNext:^(id x) {
//        NSLog(@"");
//    }];
//    
//    [[[self webRTCEndpoint] eventSignalForEvent:KMSEventTypeMediaStateChanged] subscribeNext:^(id x) {
//        NSLog(@"");
//    }];
    
}

-(void)removeCallViewController{
    [_callViewController willMoveToParentViewController:nil];
    [[_callViewController view] removeFromSuperview];
    [_callViewController removeFromParentViewController];
}

-(void)showCallViewController:(CallViewController *)callViewController{
    [self addChildViewController:callViewController];
    UIView *selfView = [self view];
    UIView *callViewControllerView = [callViewController view];
    [callViewControllerView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [selfView addSubview:callViewControllerView];
    
    NSLayoutConstraint *topCallViewConstraint = [NSLayoutConstraint constraintWithItem:callViewControllerView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:selfView attribute:NSLayoutAttributeTop multiplier:1.0f constant:0];
    NSLayoutConstraint *leadingCallViewConstraint = [NSLayoutConstraint constraintWithItem:callViewControllerView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:selfView attribute:NSLayoutAttributeLeading multiplier:1.0f constant:0];
    NSLayoutConstraint *trailingCallViewConstraint = [NSLayoutConstraint constraintWithItem:callViewControllerView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:selfView attribute:NSLayoutAttributeTrailing multiplier:1.0f constant:0];
    NSLayoutConstraint *bottomCallViewConstraint = [NSLayoutConstraint constraintWithItem:callViewControllerView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:selfView attribute:NSLayoutAttributeBottom multiplier:1.0f constant:0];
    [selfView addConstraints:@[topCallViewConstraint,leadingCallViewConstraint,trailingCallViewConstraint,bottomCallViewConstraint]];
    
    
    [callViewController didMoveToParentViewController:self];
}


-(void)callViewControllerDidHangup:(CallViewController *)callViewController{
    @weakify(self);
    RACSignal *completeCall = [[self webRTCEndpoint] dispose];
    [completeCall subscribeError:^(NSError *error) {
        NSLog(@"");
    } completed:^{
        @strongify(self);
        [self removeCallViewController];
        [[self peerConnection] close];
    }];
}


-(void)peerConnectionDidClose{
    
    RACSignal *wsClient = [[[self webRTCEndpoint] kurentoSession] closeSignal];
    
    NSArray *closeKurentoSessionSignals = @[[[self mediaPipeline] dispose],wsClient];
    
    RACSignal *close = [RACSignal concat:closeKurentoSessionSignals];
    
    [close subscribeError:^(NSError *error) {
        NSLog(@"");
    } completed:^{
        NSLog(@"");
    }];
}

#pragma mark Defaults

- (RTCMediaConstraints *)defaultMediaStreamConstraints {
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}


- (RTCMediaConstraints *)defaultOfferConstraints {
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:@{@"OfferToReceiveAudio" : @"true",
                                    @"OfferToReceiveVideo" : @"true"}
     optionalConstraints:nil];
    return constraints;
}


- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    return [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
             optionalConstraints: @{@"DtlsSrtpKeyAgreement" : @"true"}];

}

#pragma mark UITextFieldDelegate


-(BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark RTCPeerConnectionDelegate

/** Called when the SignalingState changed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged{
   [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeMain block:^{
        NSLog(@"%@",@(stateChanged));
        if (stateChanged == RTCSignalingStateClosed) {
            [self peerConnectionDidClose];
        }
        
    }];
}

/** Called when media is received on a new stream from remote peer. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
          didAddStream:(RTCMediaStream *)stream{
   [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeMain block:^{
        NSLog(@"ADDED STREAM!!! with source %@", [[[stream videoTracks] firstObject] source]);
        [self->_callViewController setRemoteMediaStream:stream];
    }];
    
}

/** Called when a remote peer closes a stream. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didRemoveStream:(RTCMediaStream *)stream{
    NSLog(@"");
}

/** Called when negotiation is needed, for example ICE has restarted. */
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection{
    NSLog(@"peerConnectionShouldNegotiate");
}

/** Called any time the IceConnectionState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceConnectionState:(RTCIceConnectionState)newState{
    NSLog(@"didChangeIceConnectionState %@", [[self iceConnectionState] objectForKey:@(newState)]);
}

/** Called any time the IceGatheringState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceGatheringState:(RTCIceGatheringState)newState{
    NSLog(@"");
}

/** New ice candidate has been found. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didGenerateIceCandidate:(RTCIceCandidate *)candidate{
   [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeMain block:^{
        NSLog(@"peerConnection  gotICECandidate");
        KMSICECandidate *kmsICECandidate = [[KMSICECandidate alloc] init];
        [kmsICECandidate setSdpMid:[candidate sdpMid]];
        [kmsICECandidate setSdpMLineIndex:[candidate sdpMLineIndex]];
        [kmsICECandidate setCandidate:[candidate sdp]];
        
        [[[self webRTCEndpoint] addICECandidate:kmsICECandidate]
         subscribeError:^(NSError *error) {
             NSLog(@"error add ice candidate %@",error);
         }completed:^{
             NSLog(@"ice candidate added");
         }];
    }];
}

/** Called when a group of local Ice candidates have been removed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates{
    NSLog(@"");
}

/** New data channel has been opened. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel{
    
}

///** Represents the ice connection state of the peer connection. */
//typedef NS_ENUM(NSInteger, RTCIceConnectionState) {
//    RTCIceConnectionStateNew,
//    RTCIceConnectionStateChecking,
//    RTCIceConnectionStateConnected,
//    RTCIceConnectionStateCompleted,
//    RTCIceConnectionStateFailed,
//    RTCIceConnectionStateDisconnected,
//    RTCIceConnectionStateClosed,
//    RTCIceConnectionStateCount,
//};

- (NSDictionary *)iceConnectionState
{
    return @{@(RTCIceConnectionStateNew) : @"RTCIceConnectionStateNew",
             @(RTCIceConnectionStateChecking) : @"RTCIceConnectionStateChecking",
             @(RTCIceConnectionStateConnected) : @"RTCIceConnectionStateConnected",
             @(RTCIceConnectionStateCompleted) : @"RTCIceConnectionStateCompleted",
             @(RTCIceConnectionStateDisconnected) : @"RTCIceConnectionStateDisconnected",
             @(RTCIceConnectionStateClosed) : @"RTCIceConnectionStateClosed",
             @(RTCIceConnectionStateCount) : @"RTCIceConnectionStateCount"
             };
}

@end
