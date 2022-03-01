//
//  PreviewVideoView.m
//  CH26xEncoderDemo
//
//  Created by chaichengxun on 2022/2/11.
//

#import "PreviewVideoView.h"

@interface PreviewVideoView ()
@property (nonatomic, strong) AVSampleBufferDisplayLayer *displayLayer;
@end

@implementation PreviewVideoView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame:frameRect]) {
        [self setup];
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.wantsLayer = YES;
    self.layer = [[AVCaptureVideoPreviewLayer alloc] init];
}

- (void)setSession:(AVCaptureSession *)session
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *)self.layer;
        layer.session = session;
    });
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

@end
