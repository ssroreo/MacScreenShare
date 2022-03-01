//
//  VideoCapturer.m
//  CH26xEncoderDemo
//
//  Created by chaichengxun on 2022/2/11.
//

#import "VideoCapturer.h"
#import <AppKit/AppKit.h>
#import "CH26xEncoder.h"

@interface VideoCapturer ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, assign) BOOL setupResult;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) dispatch_queue_t sampleBufferQueue;
@end


@implementation VideoCapturer
{
    CH26xEncoder* encoder;
    NSFileHandle *fileHandle;
    NSString *file;
}

- (instancetype)initWithDelegate:(id<VideoCapturerDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        
        _sessionQueue = dispatch_queue_create("com.quantastar.video.session.queue", DISPATCH_QUEUE_SERIAL);
        _sampleBufferQueue = dispatch_queue_create("com.quantastar.video.buffer.queue", DISPATCH_QUEUE_SERIAL);
        _session = [[AVCaptureSession alloc] init];
        
        file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"screencap.mov"];
        
        //init encoder
        encoder = [CH26xEncoder alloc];
        VideoFormat *vf = [[VideoFormat alloc] init];
        vf.width = 1920;
        vf.height = 1080;
        vf.frameRate = 30;
        vf.codecType = kCMVideoCodecType_HEVC;
        vf.frameInterval = 3000;
        vf.bitRate = 1920 * 1080 * 3 * 4 * 8;
        [encoder initEncoder:vf];
        encoder.delegate = self;
        
        dispatch_async(self.sessionQueue, ^{
            [self setupSession];
        });
        
    }
    return self;
}

- (void)setupSession {
    
    [self.session beginConfiguration];
    
    AVCaptureScreenInput *input = [[AVCaptureScreenInput alloc] initWithDisplayID:CGMainDisplayID()];
    //捕获鼠标点击
    input.capturesMouseClicks = NO;
    
    //坐标在左下角， 但是目标是从左上角开始裁剪，因此需要做一个转换
    CGRect sourceRect = CGRectZero;
    CGRect screenRect = NSScreen.mainScreen.frame;
    CGFloat y = CGRectGetMaxY(screenRect) - CGRectGetMaxY(sourceRect);
    
    CGRect targetRect = sourceRect;
    targetRect.origin.y = y;
    
    input.cropRect = CGRectZero;
    input.minFrameDuration = CMTimeMake(1, 30);
    if ([self.session canAddInput:input]) {
        [self.session addInput:input];
    } else {
        [self.session commitConfiguration];
        self.setupResult = NO;
        return;
    }
        
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey, nil];
    output.videoSettings = settings;
    [output setSampleBufferDelegate:self queue:self.sampleBufferQueue];
    if ([self.session canAddOutput:output]) {
        [self.session addOutput:output];
    } else {
        //add output failed
        [self.session commitConfiguration];
        self.setupResult = NO;
        return;
    }
    self.setupResult = YES;
    [self.session commitConfiguration];
    
}


- (void)start {
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
    [encoder initVideoToolBox];
    dispatch_async(self.sessionQueue, ^{
        if (!self.setupResult) {
            if ([self.delegate respondsToSelector:@selector(videoCapturer:didStartWithStatus:)]) {
                [self.delegate videoCapturer:self didStartWithStatus:VideoCapturerStatus_SetupError];
            }
            return;
        }
        
        if (@available(macOS 10.14, *)) {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    [self startSession];
                } else {
                    if ([self.delegate respondsToSelector:@selector(videoCapturer:didStartWithStatus:)]) {
                        [self.delegate videoCapturer:self didStartWithStatus:VideoCapturerStatus_NoPresssion];
                    }
                }
            }];
        } else {
            // Fallback on earlier versions
            [self startSession];
        }
    });
    
}

- (void)startSession
{
    [self.session startRunning];
    if ([self.delegate respondsToSelector:@selector(videoCapturer:didStartWithStatus:)]) {
        [self.delegate videoCapturer:self didStartWithStatus:VideoCapturerStatus_NoError];
    }
}



- (void)stop {
    dispatch_async(self.sessionQueue, ^{
        [self.session stopRunning];
        if ([self.delegate respondsToSelector:@selector(videoCapturer:didStopWithStatus:)]) {
            [self.delegate videoCapturer:self didStopWithStatus:VideoCapturerStatus_NoError];
        }
    });
    [encoder stop];
    [fileHandle synchronizeFile];
    [[NSWorkspace sharedWorkspace] selectFile:file inFileViewerRootedAtPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]];
}


#pragma mark - delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    [encoder encode:imageBuffer];
    
    if ([self.delegate respondsToSelector:@selector(videoCapturer:didReceiveSampleBuffer:)]) {
        [self.delegate videoCapturer:self didReceiveSampleBuffer:sampleBuffer];
    }
    
    //回调 pixBuffer
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(videoCapturer:didReceivePixelBuffer:)]) {
        [self.delegate videoCapturer:self didReceivePixelBuffer:pixelBuffer];
    }
}

#pragma mark - delegate
- (void)getEncodedData:(NSMutableData*)data isKeyFrame:(BOOL)isKeyFrame
{
    if (fileHandle != NULL)
    {
        [fileHandle writeData:data];
    }
}


@end
