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
//#import "AppDelegate.h"

#include <queue>
#include <mutex>

#import "CallMessage.h"

class DataQueue {
    std::queue<NSData*>     _queue;
    std::mutex				_mutex;
    std::condition_variable _empty;
    bool					_stopped;
    
public:
    DataQueue() : _stopped(false) {}

    void start()
    {
        _stopped = false;
    }
    
    void stop()
    {
        std::unique_lock<std::mutex> lock(_mutex);
        _stopped = true;
        _empty.notify_one();
        while (!_queue.empty()) {
            _queue.pop();
        }
    }
    
    void push(NSData* data)
    {
        std::unique_lock<std::mutex> lock(_mutex);
        _queue.push(data);
        _empty.notify_one();
    }
    
    NSData* pop()
    {
        std::unique_lock<std::mutex> lock(_mutex);
        _empty.wait(lock, [this]() { return (!_queue.empty() || _stopped);});
        if (_stopped) {
            return nil;
        } else {
            NSData* data = _queue.front();
            _queue.pop();
            return data;
        }
    }
};

@interface VideoController () <AVCaptureVideoDataOutputSampleBufferDelegate, VTEncoderDelegate, VTDecoderDelegate> {
    
    dispatch_queue_t _captureQueue;
    dispatch_queue_t _decodeQueue;
    DataQueue _decodeStream;
}

@property (weak, nonatomic) IBOutlet DragView *selfView;
@property (weak, nonatomic) IBOutlet VideoLayerView *peerView;

- (IBAction)switchCamera:(id)sender;
- (IBAction)endCall:(UIBarButtonItem*)sender;

@property (strong, nonatomic) VTEncoder* encoder;
@property (strong, nonatomic) VTDecoder* decoder;
@property (atomic) BOOL decoderIsOpened;

@property (nonatomic) UIDeviceOrientation orientation;

@end

@implementation VideoController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[Camera shared] startup];
    _captureQueue = dispatch_queue_create("com.vchannel.VideoCall.Capture", DISPATCH_QUEUE_SERIAL);
    _decodeQueue = dispatch_queue_create("com.vchannel.VideoCall.Decoder", DISPATCH_QUEUE_SERIAL);

    _encoder = [[VTEncoder alloc] init];
    _encoder.delegate = self;
    
    _decoder = [[VTDecoder alloc] init];
    _decoder.delegate = self;

    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name: UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)shutdown
{
    _decodeStream.stop();
    [_decoder close];
    [[Camera shared] shutdown];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)receiveVideoMessage:(CallMessage*)message
{
    switch (message.messageType) {
        case messageStart:
            if (!_decoder.isOpened) {
                CallVideoStartMessage* startMessage = (CallVideoStartMessage*)message;
                [_decoder openForWidth:startMessage.width
                                height:startMessage.height
                                   sps:startMessage.sps
                                   pps:startMessage.pps];
                if (_decoder.isOpened) {
                    _decodeStream.start();
                    dispatch_async(_decodeQueue, ^() {
                        while (true) {
                            NSData* data = _decodeStream.pop();
                            if (data) {
                                [_decoder decodeData:data];
                            } else {
                                break;
                            }
                        }
                    });
                }
            }
            break;
        case messageFrame:
            if (_decoder.isOpened) {
                CallVideoFrameMessage* frameMessage = (CallVideoFrameMessage*)message;
                _decodeStream.push(frameMessage.frame);
            }
            break;
        case messageStop:
            if (_decoder.isOpened) {
                _decodeStream.stop();
                [_decoder close];
                [_peerView clear];
            }
            break;
        default:
            break;
    }

}

- (void)viewDidAppear:(BOOL)animated
{
    _orientation = [[UIDevice currentDevice] orientation];
    [self startCapture];
}

- (void)deviceOrientationDidChange:(NSNotification*)notify
{
    [self stopCapture];
    _orientation = [[UIDevice currentDevice] orientation];
    [self startCapture];
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
    self.decoderIsOpened = NO;
}

- (IBAction)switchCamera:(id)sender
{
    [self stopCapture];
    [[Camera shared] switchCamera];
    [self startCapture];
}

- (IBAction)endCall:(UIBarButtonItem*)sender
{
    [self shutdown];
    [self.delegate didFinish];
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
    CallMessage *message;
    if (!self.decoderIsOpened) {
        NSDictionary *params = @{@"messageType" : [NSNumber numberWithInt:messageStart],
                                 @"sps" : _encoder.sps,
                                 @"pps" : _encoder.pps,
                                 @"width" : [NSNumber numberWithInt:_encoder.width],
                                 @"height" : [NSNumber numberWithInt:_encoder.height]};
        message = [[CallVideoStartMessage alloc] initWithDictionary:params];
        self.decoderIsOpened = YES;
    } else {
        NSDictionary *params = @{@"messageType" : [NSNumber numberWithInt:messageFrame],
                                 @"frame" : data};
        message = [[CallVideoFrameMessage alloc] initWithDictionary:params];
    }
    [self.delegate sendVideoMessage:message];
}

#pragma mark - VTDeccoder delegare

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
    [_peerView drawBuffer:buffer];
    CFRelease(buffer);
}

@end
