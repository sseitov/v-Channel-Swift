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
#import "CallMessage.h"


@interface VideoController () <AVCaptureVideoDataOutputSampleBufferDelegate, VTEncoderDelegate, VTDecoderDelegate> {
    
    dispatch_queue_t _captureQueue;
    dispatch_queue_t _decodeQueue;
}

@property (weak, nonatomic) IBOutlet DragView *selfView;

@property (strong, nonatomic) VTEncoder* encoder;
@property (strong, nonatomic) VTDecoder* decoder;
@property (strong, nonatomic) UIImage* avatar;
@property (nonatomic) UIDeviceOrientation orientation;

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
    switch (message.messageType) {
        case messageFrame:
        {
            CallVideoFrameMessage* frameMessage = (CallVideoFrameMessage*)message;
            if (!_decoder.isOpened) {
                [_decoder openForWidth:frameMessage.width
                                height:frameMessage.height
                                   sps:frameMessage.sps
                                   pps:frameMessage.pps];
                _peerView.image = nil;
            }
            else {
                [_decoder decodeData:frameMessage.frame];
            }
            break;
        }
        case messageStop:
            if (_decoder.isOpened) {
                [_decoder close];
                [_peerView clear];
                _peerView.image = _avatar;
            }
            break;
        default:
            break;
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
    NSDictionary *params = @{@"messageType" : [NSNumber numberWithInt:messageFrame],
                             @"sps" : _encoder.sps,
                             @"pps" : _encoder.pps,
                             @"width" : [NSNumber numberWithInt:_encoder.width],
                             @"height" : [NSNumber numberWithInt:_encoder.height],
                             @"frame" : data};
    CallMessage *message = [[CallVideoFrameMessage alloc] initWithDictionary:params];
//    [self.delegate sendVideoMessage:message];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self receiveVideoMessage:message];
    });
}

#pragma mark - VTDeccoder delegare

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
    [_peerView drawBuffer:buffer];
    CFRelease(buffer);
}

@end
