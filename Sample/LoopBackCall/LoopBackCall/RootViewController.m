// RootViewController.m
// Copyright (c) 2015 Dmitry Lizin (sdkdimon@gmail.com)
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

#import <libjingle_peerconnection/RTCEAGLVideoView.h>
#import <libjingle_peerconnection/RTCPeerConnectionFactory.h>
#import <libjingle_peerconnection/RTCPeerConnection.h>
#import <libjingle_peerconnection/RTCPeerConnectionInterface.h>
#import <libjingle_peerconnection/RTCMediaStream.h>
#import <libjingle_peerconnection/RTCVideoCapturer.h>
#import <libjingle_peerconnection/RTCMediaConstraints.h>
#import <libjingle_peerconnection/RTCPair.h>
#import <libjingle_peerconnection/RTCSessionDescription.h>
#import <libjingle_peerconnection/RTCSessionDescriptionDelegate.h>
#import <libjingle_peerconnection/RTCICECandidate.h>
#import <libjingle_peerconnection/RTCVideoTrack.h>
#import <libjingle_peerconnection/RTCAVFoundationVideoSource.h>
#import <libjingle_peerconnection/RTCICEServer.h>

#import "RACSRWebSocket.h"
#import "KMSAPIService.h"

#import "KMSMediaPipeline.h"
#import "KMSWebRTCEndpoint.h"

#import "KMSMessageFactoryMediaPipeline.h"
#import "KMSMessageFactoryWebRTCEndpoint.h"
#import "KMSICECandidate.h"
#import "KMSEvent.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

#import "KMSLog.h"


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

@interface RootViewController () <UITextFieldDelegate,CallViewControllerDelegate,RTCPeerConnectionDelegate,RTCSessionDescriptionDelegate>

@property(strong,nonatomic,readwrite) RTCPeerConnectionFactory *peerConnectionFactory;
@property(strong,nonatomic,readwrite) RTCPeerConnection *peerConnection;

@property(strong,nonatomic,readwrite) KMSWebRTCEndpoint *webRTCEndpoint;
@property(strong,nonatomic,readwrite) KMSMediaPipeline *mediaPipeline;

@property (weak, nonatomic) IBOutlet UITextField *wsHostTextField;
@property (weak, nonatomic) IBOutlet UITextField *wsPortTextField;
@property (weak, nonatomic) IBOutlet UITextField *wsPathTextField;
@property (weak, nonatomic) IBOutlet UILabel *wsPreviewLabel;

@property (weak, nonatomic) IBOutlet UIButton *makeCallButton;

@property(strong,nonatomic,readwrite) NSURLComponents *wsServerURLComponents;
@property(strong,nonatomic,readwrite) KMSRequestMessageFactory *kmsRequestMessageFactory;

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
    _kmsRequestMessageFactory = [[KMSRequestMessageFactory alloc] init];
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
    RTCMediaStream* localStream = [_peerConnectionFactory mediaStreamWithLabel:@"ARDAMS"];
    RTCVideoTrack* localVideoTrack = [self createLocalVideoTrack];
    if (localVideoTrack) {
        [localStream addVideoTrack:localVideoTrack];
    }
    [localStream addAudioTrack:[_peerConnectionFactory audioTrackWithID:@"ARDAMSa0"]];
    return localStream;
}

- (RTCVideoTrack *)createLocalVideoTrack {
    RTCVideoTrack* localVideoTrack = nil;
    RTCMediaConstraints *mediaConstraints = [self defaultMediaStreamConstraints];
    RTCAVFoundationVideoSource *source =
    [[RTCAVFoundationVideoSource alloc] initWithFactory:_peerConnectionFactory
                                            constraints:mediaConstraints];
    localVideoTrack =
    [[RTCVideoTrack alloc] initWithFactory:_peerConnectionFactory
                                    source:source
                                   trackId:@"ARDAMSv0"];
    
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
    [_peerConnection createOfferWithDelegate:self constraints:[self defaultOfferConstraints]];

}


- (IBAction)makeCall:(UIButton *)sender {
    [self saveURLS];
    RACSRWebSocket *wsClient = [[RACSRWebSocket alloc] initWithURL:[_wsServerURLComponents URL]];
    KMSAPIService *apiService = [KMSAPIService serviceWithWebSocketClient:wsClient];
    KMSMessageFactoryMediaPipeline *mediaPipelineMessageFactory = [[KMSMessageFactoryMediaPipeline alloc] init];
    _mediaPipeline = [KMSMediaPipeline pipelineWithAPIService:apiService messageFactory:mediaPipelineMessageFactory];
    [mediaPipelineMessageFactory setDataSource:_mediaPipeline];
    KMSMessageFactoryWebRTCEndpoint *webRTCEndpointMessageFactory = [[KMSMessageFactoryWebRTCEndpoint alloc] init];
    _webRTCEndpoint = [KMSWebRTCEndpoint endpointWithAPIService:apiService messageFactory:webRTCEndpointMessageFactory];
    [webRTCEndpointMessageFactory setDataSource:_webRTCEndpoint];
    _peerConnection = [self initializePeerConnectionWithFactory:_peerConnectionFactory];
    
    @weakify(self);
    RACSignal *createAndConnectWebRTCEndpointSignal =
    [[[[[[_mediaPipeline create] flattenMap:^RACStream *(NSString *mediaPipelineId) {
        @strongify(self);
        return [[self webRTCEndpoint] createWithMediaPipelineId:mediaPipelineId];
    }] flattenMap:^RACStream *(id value) {
        @strongify(self);
        return [[self webRTCEndpoint] subscribe:KMSEventTypeOnICECandidate];
    }]  flattenMap:^RACStream *(id value) {
        @strongify(self);
        return [[self webRTCEndpoint] subscribe:KMSEventTypeMediaElementDisconnected];
    }] flattenMap:^RACStream *(id value) {
         @strongify(self);
        return [[self webRTCEndpoint] subscribe:KMSEventTypeMediaElementConnected];
    }]flattenMap:^RACStream *(id value) {
        @strongify(self);
        return [[self webRTCEndpoint] connect:[[self webRTCEndpoint] identifier]];
    }];
    
    
    [createAndConnectWebRTCEndpointSignal subscribeError:^(NSError *error) {
        NSLog(@"error %@",error);
    } completed:^{
        @strongify(self);
        //do RTCPeerConnection stuff
        
        [[[self webRTCEndpoint] getSourceConnections] subscribeNext:^(id x) {
            [self createOffer];
        } completed:^{
            
        }];
        
        
        
    }];
    
    [[[self webRTCEndpoint] eventSignalForEvent:KMSEventTypeOnICECandidate] subscribeNext:^(KMSEventDataICECandidate *eventData) {
        KMSICECandidate *kmsICECandidate = [eventData candidate];
        RTCICECandidate *peerICECandidate = [[RTCICECandidate alloc] initWithMid:[kmsICECandidate sdpMid] index:[kmsICECandidate sdpMLineIndex] sdp:[kmsICECandidate candidate]];
        [[self peerConnection] addICECandidate:peerICECandidate];

        NSLog(@"");
    }];
    
    
    [[[self webRTCEndpoint] eventSignalForEvent:KMSEventTypeMediaElementConnected] subscribeNext:^(id x) {
        NSLog(@"");
    }];
    
    [[[self webRTCEndpoint] eventSignalForEvent:KMSEventTypeMediaElementDisconnected] subscribeNext:^(id x) {
        NSLog(@"");
    }];
    
//    [[_webRTCEndpoint onICECandidateSignal] subscribeNext:^(KMSICECandidate *kmsICECandidate) {
//        @strongify(self);
//        RTCICECandidate *peerICECandidate = [[RTCICECandidate alloc] initWithMid:[kmsICECandidate sdpMid] index:[kmsICECandidate sdpMLineIndex] sdp:[kmsICECandidate candidate]];
//        [[self peerConnection] addICECandidate:peerICECandidate];
//    } completed:^{
//        NSLog(@"");
//    }] ;
    
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
    
//    RACSignal *completeCall =
//    [[[[self webRTCEndpoint] disconnect:[[self webRTCEndpoint] identifier]] flattenMap:^RACStream *(id value) {
//        @strongify(self);
//        return [[self webRTCEndpoint] dispose];
//    }] flattenMap:^RACStream *(id value) {
//        @strongify(self);
//        return [[[self webRTCEndpoint] mediaPipeline] dispose];
//    }];
    
    [_peerConnection close];
    
    RACSignal *completeCall =
    [[[[self webRTCEndpoint] disconnect:[[self webRTCEndpoint] identifier]] flattenMap:^RACStream *(id value) {
        @strongify(self);
        return [[self webRTCEndpoint] dispose];
    }] flattenMap:^RACStream *(id value) {
        @strongify(self);
        return [[self mediaPipeline] dispose];
    }];

    
    [completeCall subscribeError:^(NSError *error) {
        NSLog(@"");
    } completed:^{
        @strongify(self);
        CallViewController *callViewController = [self callViewController];
        [[self peerConnection] removeStream:[callViewController localMediaStream]];
        [[self peerConnection] removeStream:[callViewController remoteMediaStream]];
        [self removeCallViewController];
        NSLog(@"");
    }];
    
//    [[[self webRTCEndpoint] getSourceConnections] subscribeNext:^(id x) {
//        NSLog(@"");
//        @strongify(self);
//        [[[self webRTCEndpoint] disconnect:[[self webRTCEndpoint] identifier]] subscribeNext:^(id x) {
//            
//            [[[self webRTCEndpoint] getSourceConnections] subscribeNext:^(id x) {
//                NSLog(@"");
//                [[[self webRTCEndpoint] getSinkConnections] subscribeNext:^(id x) {
//                    NSLog(@"");
//                }];
//            }];
//            
//            
//            NSLog(@"");
//        } error:^(NSError *error) {
//            NSLog(@"");
//        } completed:^{
//            NSLog(@"");
//        }];
//
//    }];
    
    
    
//    RACSignal *disposeWebRTCEndpoit =
//    [[_webRTCEndpoint dispose] flattenMap:^RACStream *(id value) {
//        @strongify(self);
//        return [[[self webRTCEndpoint] mediaPipeline] dispose];
//    }];
//    
//    [disposeWebRTCEndpoit subscribeCompleted:^{
//        @strongify(self);
//        [self setWebRTCEndpoint:nil];
//        
//        CallViewController *callViewController = [self callViewController];
//        [[self peerConnection] removeStream:[callViewController localMediaStream]];
//        [[self peerConnection] removeStream:[callViewController remoteMediaStream]];
//        [self removeCallViewController];
//        [[self peerConnection] close];
//        [self setWebRTCEndpoint:nil];
//        [self setPeerConnection:nil];
//        
//    }];
}

#pragma mark RTCPeerConnectionDelegate

// Triggered when the SignalingState changed.
- (void)peerConnection:(RTCPeerConnection *)peerConnection signalingStateChanged:(RTCSignalingState)stateChanged{
    
}

// Triggered when media is received on a new stream from remote peer.
- (void)peerConnection:(RTCPeerConnection *)peerConnection addedStream:(RTCMediaStream *)stream{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"ADDED STREAM!!!");
        [_callViewController setRemoteMediaStream:stream];
    });
    
}

// Triggered when a remote peer close a stream.
- (void)peerConnection:(RTCPeerConnection *)peerConnection removedStream:(RTCMediaStream *)stream{
    
    
}

// Triggered when renegotiation is needed, for example the ICE has restarted.
- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection{

}

// Called any time the ICEConnectionState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection iceConnectionChanged:(RTCICEConnectionState)newState{
    
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection iceGatheringChanged:(RTCICEGatheringState)newState{
    
}

// New Ice candidate have been found.
- (void)peerConnection:(RTCPeerConnection *)peerConnection gotICECandidate:(RTCICECandidate *)candidate{
    dispatch_async(dispatch_get_main_queue(), ^{
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
    });
    
}

// New data channel has been opened.
- (void)peerConnection:(RTCPeerConnection*)peerConnection didOpenDataChannel:(RTCDataChannel*)dataChannel{
    
}



#pragma mark RTCSessionDescriptionDelegate

// Called when creating a session.
- (void)peerConnection:(RTCPeerConnection *)peerConnection didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error{
    
    NSLog(@"is main thread %@", [NSThread isMainThread] ? @"YES": @"NO");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"is main thread %@", [NSThread isMainThread] ? @"YES": @"NO");
       @weakify(self);
       NSString *sdpDescription = [sdp description];
       NSString *sdpFixDescription = [sdpDescription stringByReplacingOccurrencesOfString:@"UDP/TLS/RTP/SAVPF" withString:@"RTP/SAVPF"];
        RTCSessionDescription *fixedDescription = [[RTCSessionDescription alloc] initWithType:[sdp type] sdp:sdpFixDescription];
        [[self peerConnection] setLocalDescriptionWithDelegate:self sessionDescription:fixedDescription];
        KMSWebRTCEndpoint *webRTCSession = [self webRTCEndpoint];
        
            RACSignal *processSDPOfferAndGatherICECandidates =
                [[webRTCSession processOffer:sdpFixDescription]
                flattenMap:^RACStream *(NSString *remoteSDP) {
                    @strongify(self);
                    RTCSessionDescription *remoteDesc = [[RTCSessionDescription alloc] initWithType:@"answer" sdp:remoteSDP];
                    [[self peerConnection] setRemoteDescriptionWithDelegate:self sessionDescription:remoteDesc];
                    return [webRTCSession gatherICECandidates];
                }];
        
                [processSDPOfferAndGatherICECandidates subscribeError:^(NSError *error) {
                    NSLog(@"error process sdp offer %@",error);
                }completed:^{
                    NSLog(@"complete processs offer. Started gathering ICE candidates....");
                }];
    });
}

// Called when setting a local or remote description.
- (void)peerConnection:(RTCPeerConnection *)peerConnection didSetSessionDescriptionWithError:(NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
    
    });
    
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
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]
                                      ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}


- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    
    return  [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:
     @[
       [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement"
                              value:@"true"]
       ]];

}

#pragma mark UITextFieldDelegate


-(BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return YES;
}



@end
