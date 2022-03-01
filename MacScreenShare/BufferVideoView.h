//
//  BufferVideoView.h
//  ScreenShareDemo
//
//  Created by chaichengxun on 2022/3/1.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BufferVideoView : NSView
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)displaySampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END
