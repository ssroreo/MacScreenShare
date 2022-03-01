//
//  AppDelegate.h
//  MacScreenShare
//
//  Created by chaichengxun on 2022/3/1.
//

#import <Cocoa/Cocoa.h>
#import "VideoCapturer.h"
#import "WindowCapturer.h"

@interface AppDelegate : NSObject <NSApplicationDelegate,VideoCapturerDelegate,WindowCapturerDelegate>

@property (nonatomic, retain) VideoCapturer* capture;
@property (nonatomic, retain) WindowCapturer* wcapture;

@end

