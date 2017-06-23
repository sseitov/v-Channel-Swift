//
//  VideoLayerView.m
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VideoLayerView.h"

@interface VideoLayerView ()

@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoLayer;
@property (strong, nonatomic) CAShapeLayer* targetLayer;

@end

@implementation VideoLayerView

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!_videoLayer) {
        _videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
        _videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        _videoLayer.backgroundColor = [[UIColor clearColor] CGColor];

        _targetLayer = [[CAShapeLayer alloc] init];
        _targetLayer.fillColor = nil;
        _targetLayer.opacity = 1;
        _targetLayer.strokeColor = [UIColor yellowColor].CGColor;
        _targetLayer.lineWidth = 1;
        _targetLayer.lineJoin = kCALineJoinRound;
        _targetLayer.lineDashPattern = [NSArray arrayWithObjects:[NSNumber numberWithInt:10],[NSNumber numberWithInt:5], nil];

        [_videoLayer addSublayer:_targetLayer];
        
        [self.layer addSublayer:_videoLayer];
    }
    _videoLayer.bounds = self.bounds;
    _videoLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    
    UIBezierPath* rectPath = [UIBezierPath bezierPathWithRect:self.centerRect];
    _targetLayer.path = rectPath.CGPath;
}

- (CGRect)centerRect
{
    float size = MIN(self.bounds.size.width, self.bounds.size.height) - 40;
    return CGRectMake((self.bounds.size.width - size)/2, (self.bounds.size.height - size)/2, size, size);
}

- (void)drawBuffer:(CMSampleBufferRef)videoBuffer
{
    [_videoLayer enqueueSampleBuffer:videoBuffer];
}

- (void)clear
{
    [_videoLayer flushAndRemoveImage];
}

@end
