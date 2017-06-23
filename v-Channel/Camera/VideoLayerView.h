//
//  VideoLayerView.h
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface VideoLayerView : UIImageView

- (void)drawBuffer:(CMSampleBufferRef)videoBuffer;
- (void)clear;
- (CGRect)centerRect;

@end
