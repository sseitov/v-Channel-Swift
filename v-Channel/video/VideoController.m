//
//  VideoController.m
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VideoController.h"
#import "DragView.h"
#import "Camera.h"
#import "VTEncoder.h"
#import "VTDecoder.h"


@interface VideoController () <AVCaptureVideoDataOutputSampleBufferDelegate, VTEncoderDelegate, VTDecoderDelegate> {
    
    dispatch_queue_t _captureQueue;
    dispatch_queue_t _decodeQueue;
}

@property (weak, nonatomic) IBOutlet DragView *selfView;

@property (strong, nonatomic) VTEncoder* encoder;
@property (strong, nonatomic) VTDecoder* decoder;
@property (strong, nonatomic) UIImage* avatar;
@property (nonatomic) UIDeviceOrientation orientation;

@property (atomic) bool videoAccepted;

@end

@implementation VideoController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _captureQueue = dispatch_queue_create("com.vchannel.VideoCall.Capture", DISPATCH_QUEUE_SERIAL);
    _decodeQueue = dispatch_queue_create("com.vchannel.VideoCall.Decoder", DISPATCH_QUEUE_SERIAL);
    
    _encoder = [[VTEncoder alloc] init];
    _encoder.delegate = self;
    
    _decoder = [[VTDecoder alloc] init];
    _decoder.delegate = self;
    
    _selfView.layer.borderColor = [UIColor redColor].CGColor;
    _selfView.layer.borderWidth = 2;
    _selfView.layer.cornerRadius = 10;
    _selfView.clipsToBounds = true;
}

- (void)start {
    [[Camera shared] startup];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name: UIDeviceOrientationDidChangeNotification
                                               object:nil];
    _orientation = [[UIDevice currentDevice] orientation];
    _avatar = _peerView.image;
    self.videoAccepted = false;
    [self startCapture];
}

- (void)shutdown
{
    [self stopCapture];
    [_decoder close];
    [_peerView clear];
    
    [[Camera shared] shutdown];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)startCapture
{
    [[Camera shared].output setSampleBufferDelegate:self queue:_captureQueue];
}

- (void)stopCapture
{
    [self.delegate sendVideoMessage:[[CallVideoStopMessage alloc] init]];
    [[Camera shared].output setSampleBufferDelegate:nil queue:_captureQueue];
    [_encoder close];
    [_selfView clear];
}

- (void)receiveVideoMessage:(CallMessage*)message
{
    if ([message isKindOfClass:[CallVideoStartMessage class]]) {
        CallVideoStartMessage* startMessage = (CallVideoStartMessage*)message;
        if (!_decoder.isOpened) {
            [_decoder openForWidth:startMessage.width
                            height:startMessage.height
                               sps:startMessage.sps
                               pps:startMessage.pps];
        }
        if (_decoder.isOpened) {
            CallVideoAcceptMessage *message = [[CallVideoAcceptMessage alloc] init];
            [self.delegate sendVideoMessage:message];
        }
    } else if ([message isKindOfClass:[CallVideoFrameMessage class]]) {
        CallVideoFrameMessage* frameMessage = (CallVideoFrameMessage*)message;
        [_decoder decodeData:frameMessage.frame];
    } else if ([message isKindOfClass:[CallVideoAcceptMessage class]]) {
        self.videoAccepted = true;
    } else if ([message isKindOfClass:[CallVideoStopMessage class]]) {
        if (_decoder.isOpened) {
            [_decoder close];
            [_peerView clear];
            _peerView.image = _avatar;
        }
    }
}

- (void)deviceOrientationDidChange:(NSNotification*)notify
{
    [self stopCapture];
    _orientation = [[UIDevice currentDevice] orientation];
    [self startCapture];
}

#pragma mark - AVCaptureVideoDataOutput delegate

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (connection.supportsVideoOrientation && connection.videoOrientation != (AVCaptureVideoOrientation)_orientation) {
        [connection setVideoOrientation:(AVCaptureVideoOrientation)_orientation];
    }

    CVImageBufferRef pixelBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!_encoder.isOpened) {
        CGSize sz = CVImageBufferGetDisplaySize(pixelBuffer);
        if (UIInterfaceOrientationIsLandscape((UIInterfaceOrientation)_orientation)) {
            [_encoder openForWidth:sz.width height:sz.height];
        } else {
            [_encoder openForWidth:sz.height height:sz.width];
        }
    }

    if (_encoder.isOpened) {
        [_encoder encodeBuffer:pixelBuffer];
    }
 
    [_selfView drawBuffer:sampleBuffer];
}

#pragma mark - VTEncoder delegare

- (void)encoder:(VTEncoder*)encoder encodedData:(NSData*)data
{
    if (self.videoAccepted) {
        CallVideoFrameMessage* message = [[CallVideoFrameMessage alloc] init];
        message.frame = data;
        [self.delegate sendVideoMessage:message];
    } else {
        CallVideoStartMessage* message = [[CallVideoStartMessage alloc] init];
        message.sps = _encoder.sps;
        message.pps = _encoder.pps;
        message.width = _encoder.width;
        message.height = _encoder.height;
        [self.delegate sendVideoMessage:message];
    }
}

#pragma mark - VTDeccoder delegare

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
    if (_peerView.image != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _peerView.image = nil;
        });
    }
    [_peerView drawBuffer:buffer];
    CFRelease(buffer);
}

@end
