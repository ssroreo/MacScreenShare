//
//  AppDelegate.m
//  MacScreenShare
//
//  Created by chaichengxun on 2022/3/1.
//

#import "AppDelegate.h"
#import "PreviewVideoView.h"
#import "BufferVideoView.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (weak) IBOutlet PreviewVideoView *videoView;
@property (weak) IBOutlet NSButton *btn;
@property (assign) BOOL isPlaying;

@property (weak) IBOutlet BufferVideoView *windowVideoView;
@property (weak) IBOutlet NSTextField *windowIDInput;


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _capture = [[VideoCapturer alloc] initWithDelegate:self];
    _wcapture = [[WindowCapturer alloc] initWithDelegate:self];
    _isPlaying = false;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - ScreenShare delegate
- (void)videoCapturer:(VideoCapturer *)capturer didStartWithStatus:(int)status {
    
}
- (void)videoCapturer:(VideoCapturer *)capturer didReceivePixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self.videoView setSession:self.capture.session];
}
- (void)videoCapturer:(VideoCapturer *)capturer didStopWithStatus:(int)status {
    
}
- (void)videoCapturer:(VideoCapturer *)capturer didReceiveSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
}

#pragma mark - WindowShare delegate
- (void)windowCapturer:(CVPixelBufferRef)pixelBuffer {
    [self.windowVideoView displayPixelBuffer:pixelBuffer];
}

- (IBAction)onClick:(id)sender {
    _isPlaying = !_isPlaying;
    NSString *wid = _windowIDInput.stringValue;
    
    if (!wid.length) {
        if ([_videoView isHidden]) {
            [_videoView setHidden:NO];
        }
        if (![_windowVideoView isHidden]) {
            [_windowVideoView setHidden:YES];
        }
        
        if (_isPlaying) {
            [_capture start];
            [_btn setTitle:@"Stop"];
        } else {
            [_capture stop];
            [_btn setTitle:@"Start"];
        }
    } else {
        if ([_windowVideoView isHidden]) {
            [_windowVideoView setHidden:NO];
        }
        if (![_videoView isHidden]) {
            [_videoView setHidden:YES];
        }
        CGWindowID windowId = [wid integerValue];
        if (_isPlaying) {
            [_wcapture setWindowID:windowId];
            [_wcapture start];
            [_btn setTitle:@"Stop"];
        } else {
            [_wcapture stop];
            [_btn setTitle:@"Start"];
        }
    }
}

@end
