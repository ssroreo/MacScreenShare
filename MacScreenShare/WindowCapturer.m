//
//  WindowCapturer.m
//  MacScreenShare
//
//  Created by chaichengxun on 2022/3/1.
//

#import "WindowCapturer.h"
#import <Appkit/AppKit.h>
#import "CH26xEncoder.h"
#import "libyuv.h"

#define kFrameRate 30

@interface WindowCapturer ()
{
    CH26xEncoder* encoder;
    NSFileHandle *fileHandle;
    NSString *file;
}

@property (nonatomic) dispatch_source_t timer;
@property (nonatomic) dispatch_queue_t taskQueue;

@end

@implementation WindowCapturer

- (void)dealloc
{
    [self stop];
}

- (instancetype)initWithDelegate:(id<WindowCapturerDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _taskQueue = dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL);
        
        file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"windowcap.mov"];
        
        encoder = [CH26xEncoder alloc];
        VideoFormat *vf = [[VideoFormat alloc] init];
        vf.width = 800;
        vf.height = 600;
        vf.frameRate = kFrameRate;
        vf.codecType = kCMVideoCodecType_H264;
        vf.frameInterval = 3000;
        vf.bitRate = 800 * 600 * 3 * 4 * 8;
        [encoder initEncoder:vf];
        encoder.delegate = self;
    }
    return self;
}

- (void)setWindowID:(CGWindowID)windowID {
    _windowID = windowID;
}

- (void)start
{
//    [self stop];
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
    [encoder initVideoToolBox];
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.taskQueue);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 / kFrameRate * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        [self captureWindowImageFrame];
    });
    dispatch_resume(timer);
    _timer = timer;
}

- (void)stop
{
    if (_timer) {
        dispatch_source_cancel(_timer);
    }
    _timer = NULL;
//    [encoder stop];
    [fileHandle synchronizeFile];
    [[NSWorkspace sharedWorkspace] selectFile:file inFileViewerRootedAtPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]];
}

- (void)captureWindowImageFrame
{
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, self.windowID);
    CFIndex count = CFArrayGetCount(windowList);
    if (count == 0) {
        CFRelease(windowList);
        return;
    }
    
    CFDictionaryRef windowInfo = CFArrayGetValueAtIndex(windowList, 0);
    CFDictionaryRef boundsInfo = CFDictionaryGetValue(windowInfo, kCGWindowBounds);
    
    CGRect rect = CGRectNull;
    bool ret = CGRectMakeWithDictionaryRepresentation(boundsInfo, &rect);
    CFRelease(windowList);
    if (!ret) {
        return;
    }
    //取得窗口快照
    CGImageRef windowImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, self.windowID, kCGWindowImageBoundsIgnoreFraming);
    if (!windowImage) {
        NSLog(@"window image is null");
        return;
    }

    //转化为 buffer 并展示
    CVPixelBufferRef buffer = [self pixelBufferFromCGImage:windowImage];
    [encoder encode:buffer];
    if ([self.delegate respondsToSelector:@selector(windowCapturer:)]) {
        [self.delegate windowCapturer:buffer];
    }
    CVPixelBufferRelease(buffer);
    CFRelease(windowImage);
}

- (CVPixelBufferRef)pixelBufferFromCGImage: (CGImageRef) image
{
    NSCParameterAssert(NULL != image);
    size_t originalWidth = CGImageGetWidth(image);
    size_t originalHeight = CGImageGetHeight(image);
    
    if (originalWidth == 0 || originalHeight == 0) {
        return NULL;
    }

    size_t bytePerRow = CGImageGetBytesPerRow(image);
    CFDataRef data  = CGDataProviderCopyData(CGImageGetDataProvider(image));
    const UInt8 *ptr =  CFDataGetBytePtr(data);
    
    //create rgb buffer
    NSDictionary *att = @{(NSString *)kCVPixelBufferIOSurfacePropertiesKey : @{} };
    
    CVPixelBufferRef buffer;
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                 originalWidth,
                                 originalHeight,
                                 kCVPixelFormatType_32BGRA,
                                 (void *)ptr,
                                 bytePerRow,
                                 _CVPixelBufferReleaseBytesCallback,
                                 (void *)data,
                                 (__bridge CFDictionaryRef _Nullable)att,
                                 &buffer);
    
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    int width = CVPixelBufferGetWidth(buffer);
    int height = CVPixelBufferGetHeight(buffer);
        
    //防止出现绿边
    height = height - height%2;

    CVPixelBufferRef i420Buffer;
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8Planar, (__bridge CFDictionaryRef _Nullable)att,&i420Buffer);
    CVPixelBufferLockBaseAddress(i420Buffer, 0);
    
    void *y_frame = CVPixelBufferGetBaseAddressOfPlane(i420Buffer, 0);
    void *u_frame = CVPixelBufferGetBaseAddressOfPlane(i420Buffer, 1);
    void *v_frame = CVPixelBufferGetBaseAddressOfPlane(i420Buffer, 2);
    
    int stride_y = CVPixelBufferGetBytesPerRowOfPlane(i420Buffer, 0);
    int stride_u = CVPixelBufferGetBytesPerRowOfPlane(i420Buffer, 1);
    int stride_v = CVPixelBufferGetBytesPerRowOfPlane(i420Buffer, 2);
    
    void *rgb = CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
    void *rgb_stride = CVPixelBufferGetBytesPerRow(buffer);
    
    ARGBToI420(rgb, rgb_stride,
               y_frame, stride_y,
               u_frame, stride_u,
               v_frame, stride_v,
               width, height);
    
    CVPixelBufferUnlockBaseAddress(i420Buffer, 0);
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    CVPixelBufferRelease(buffer);
    
    return  i420Buffer;
}

void _CVPixelBufferReleaseBytesCallback(void *releaseRefCon, const void *baseAddress) {
    
    CFDataRef data = releaseRefCon;
    CFRelease(data);
    
}

- (void)getEncodedData:(NSMutableData*)data isKeyFrame:(BOOL)isKeyFrame
{
    if (fileHandle != NULL)
    {
        [fileHandle writeData:data];
    }
}

@end
