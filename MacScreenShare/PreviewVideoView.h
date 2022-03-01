//
//  PreviewVideoView.h
//  CH26xEncoderDemo
//
//  Created by chaichengxun on 2022/2/11.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreviewVideoView : NSView
- (void)setSession:(AVCaptureSession *)session;
@end

NS_ASSUME_NONNULL_END
