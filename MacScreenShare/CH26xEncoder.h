//
//  CH26xEncoder.h
//  CH26xEncoder
//
//  Created by chaichengxun on 2022/2/11.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoFormat : NSObject<NSCopying>
@property (nonatomic,assign) int width;
@property (nonatomic,assign) int height;
@property (nonatomic,assign) int frameRate;
@property (nonatomic,assign) int bitRate;
@property (nonatomic,assign) int frameInterval;
@property (nonatomic,assign) CMVideoCodecType codecType;
@end

@protocol CH26xEncoderDelegate<NSObject>
- (void)getEncodedData:(NSMutableData*)data isKeyFrame:(BOOL)isKeyFrame;
@end

@interface CH26xEncoder : NSObject
@property(weak, nonatomic)id<CH26xEncoderDelegate>delegate;
- (void)initEncoder:(VideoFormat*)format;
- (void)initVideoToolBox;
- (void)encode:(CVImageBufferRef)imageBuffer;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
