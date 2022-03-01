//
//  WindowCapturer.h
//  MacScreenShare
//
//  Created by chaichengxun on 2022/3/1.
//

#import <Foundation/Foundation.h>
#import "CH26xEncoder.h"

NS_ASSUME_NONNULL_BEGIN

@protocol WindowCapturerDelegate <NSObject>

- (void)windowCapturer:(CVPixelBufferRef)pixelBuffer;
//- (void)windowCapturer:(CMSampleBufferRef)sampleBuffer;

@end

@interface WindowCapturer : NSObject<CH26xEncoderDelegate>

@property (nonatomic) CGWindowID windowID;
@property (nonatomic, weak) id<WindowCapturerDelegate>delegate;

- (instancetype)initWithDelegate:(id<WindowCapturerDelegate>)delegate;
- (void)setWindowID:(CGWindowID)windowID;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
