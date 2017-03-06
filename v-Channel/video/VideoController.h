//
//  VideoController.h
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CallMessage;

@protocol VideoControllerDelegate <NSObject>

- (void)sendVideoMessage:(CallMessage*)message;

@end

@interface VideoController : UIViewController

@property (weak, nonatomic) id<VideoControllerDelegate> delegate;

- (void)start;
- (void)receiveVideoMessage:(CallMessage*)message;
- (void)shutdown;

@end
