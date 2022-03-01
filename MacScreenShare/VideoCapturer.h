//
//  VideoCapturer.h
//  CH26xEncoderDemo
//
//  Created by chaichengxun on 2022/2/11.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "CH26xEncoder.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VideoCapturerStatus) {
    VideoCapturerStatus_NoError = 0,
    VideoCapturerStatus_NoPresssion,
    VideoCapturerStatus_SetupError,
    VideoCapturerStatus_SystemInterrupt,
    VideoCapturerStatus_SystemError
};

@class VideoCapturer;
@protocol VideoCapturerDelegate <NSObject>

- (void)videoCapturer:(VideoCapturer *)capturer didStartWithStatus:(int)status;
- (void)videoCapturer:(VideoCapturer *)capturer didReceivePixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)videoCapturer:(VideoCapturer *)capturer didStopWithStatus:(int)status;
- (void)videoCapturer:(VideoCapturer *)capturer didReceiveSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end


@interface VideoCapturer : NSObject<CH26xEncoderDelegate>
@property (nonatomic, strong, readonly) AVCaptureSession *session;
- (instancetype)initWithDelegate:(id<VideoCapturerDelegate>)delegate;

@property (nonatomic, weak) id<VideoCapturerDelegate>delegate;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
