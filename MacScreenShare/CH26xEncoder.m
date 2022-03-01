//
//  CH26xEncoder.m
//  CH26xEncoder
//
//  Created by chaichengxun on 2022/2/11.
//

#import "CH26xEncoder.h"

const static Byte headerBytes[] = {0x00, 0x00, 0x00, 0x01};

@implementation VideoFormat
- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    VideoFormat *obj = [[[self class] allocWithZone:zone] init];
    obj.width = self.width;
    obj.height = self.height;
    obj.frameRate = self.frameRate;
    obj.bitRate = self.bitRate;
    obj.codecType = self.codecType;
    obj.frameInterval = self.frameInterval;
    return obj;
}
@end

@implementation CH26xEncoder
{
    VideoFormat* videoFormat;
    VTCompressionSessionRef encodingSession;
    dispatch_queue_t encodeQueue;
    int frameID;
    NSData * vps;
    NSData * sps;
    NSData * pps;
}

- (void)initEncoder: (VideoFormat*)format {
    videoFormat = [format copy];
    encodingSession = nil;
    encodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    frameID = 0;
    vps = nil;
    sps = nil;
    pps = nil;
}

- (void)dealloc{
    [self stop];
}

- (void)stop {
    dispatch_sync(encodeQueue, ^{
        if(encodingSession){
            VTCompressionSessionCompleteFrames(encodingSession, kCMTimeInvalid);
            VTCompressionSessionInvalidate(encodingSession);
            CFRelease(encodingSession);
            encodingSession = nil;
        }
    });
}

- (void)initVideoToolBox {
    dispatch_sync(encodeQueue, ^{
        OSStatus status = VTCompressionSessionCreate(NULL,
                                                     videoFormat.width,
                                                     videoFormat.height,
                                                     videoFormat.codecType,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     outputCallback,
                                                     (__bridge void *)(self),
                                                     &encodingSession
                                                     );
        
        if (status != noErr)
        {
            return ;
        }
        
        // 设置实时编码输出（避免延迟）
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        // h264 profile, 直播一般使用baseline，可减少由于b帧带来的延时
        if(videoFormat.codecType == kCMVideoCodecType_HEVC) {
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_HEVC_Main_AutoLevel);
        } else {
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        }
        
        // 设置关键帧（GOPsize)间隔
        int frameInterval = videoFormat.frameInterval;
        CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
        
        // 设置期望帧率
        int fps = videoFormat.frameRate;
        CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        
        // 设置编码码率(比特率)，如果不设置，默认将会以很低的码率编码，导致编码出来的视频很模糊
        // 设置码率，上限，单位是bps
        int bitRate = videoFormat.bitRate;
        CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
        // 设置码率，均值，单位是byte
        int bitRateLimit = videoFormat.bitRate / 8;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        if (@available(macOS 11.0, *)) {
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_HDRMetadataInsertionMode, kVTHDRMetadataInsertionMode_Auto);
        }
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(encodingSession);
    });
}

void outputCallback(void *outputCallbackRefCon,
                    void *sourceFrameRefCon,
                    OSStatus status,
                    VTEncodeInfoFlags infoFlags,
                    CMSampleBufferRef sampleBuffer) {
    
    if (status != 0) {
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    CH26xEncoder * encoder = (__bridge CH26xEncoder *)outputCallbackRefCon;
    NSMutableData* videoData = [[NSMutableData alloc] init];
    
    BOOL keyframe = [encoder isKeyFrame:sampleBuffer];
    if (keyframe) {
        [encoder getParamaterSetWithBufferRef:sampleBuffer];
        if (encoder->vps!=nil) {
            [videoData appendBytes:headerBytes length:4];
            [videoData appendData:encoder->vps];
        }
        [videoData appendBytes:headerBytes length:4];
        [videoData appendData:encoder->sps];
        [videoData appendBytes:headerBytes length:4];
        [videoData appendData:encoder->pps];
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [videoData appendBytes:headerBytes length:4];
            [videoData appendData:data];
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
    if (encoder-> _delegate) {
        [encoder->_delegate getEncodedData:videoData isKeyFrame:keyframe];
    }
}

- (void)encode:(CVImageBufferRef)imageBuffer {
    dispatch_sync(encodeQueue, ^{
        // Get the CV Image buffer
//        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Create properties
        CMTime presentationTimeStamp = CMTimeMake(self->frameID++, 1000);
        VTEncodeInfoFlags flags;
        
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(self->encodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL, NULL, &flags);
        // Check for error
        if (statusCode != noErr) {
            // End the session
            VTCompressionSessionInvalidate(self->encodingSession);
            CFRelease(self->encodingSession);
            self->encodingSession = NULL;
            return;
        }
    });
}

- (BOOL)isKeyFrame:(CMSampleBufferRef)sampleBufferRef{
    BOOL isKeyFrame = NO;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBufferRef, 0);
    if (attachments != nil && CFArrayGetCount(attachments)) {
        CFDictionaryRef attachment = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        isKeyFrame = !CFDictionaryContainsKey(attachment, kCMSampleAttachmentKey_NotSync);
    }
    return isKeyFrame;
}

- (void)getParamaterSetWithBufferRef:(CMSampleBufferRef)sampleBuffer {
    CMFormatDescriptionRef description = CMSampleBufferGetFormatDescription(sampleBuffer);
    const uint8_t *bytes = nil;
    size_t size = 0;
    size_t vpsCount,spsCount,ppsCount;
    OSStatus statusCode;
    if(kCMVideoCodecType_HEVC == videoFormat.codecType) {
        /// VPS
        statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(description, 0, &bytes, &size, &vpsCount, nil);
        if(statusCode == noErr){
            vps = [NSData dataWithBytes:bytes length:size];
        }
        
        /// SPS
        statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(description, 1, &bytes, &size, &spsCount, nil);
        if(statusCode == noErr){
            sps = [NSData dataWithBytes:bytes length:size];
        }
        
        /// PPS
        statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(description, 2, &bytes, &size, &ppsCount, nil);
        if(statusCode == noErr){
            pps = [NSData dataWithBytes:bytes length:size];
        }
    } else{
        /// VPS，h264没有VPS
        vps = nil;
        
        /// SPS
        statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, 0, &bytes, &size, &spsCount, nil);
        if(statusCode == noErr){
            sps = [NSData dataWithBytes:bytes length:size];
        }
        
        /// PPS
        statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, 1, &bytes, &size, &ppsCount, nil);
        if(statusCode == noErr){
            pps = [NSData dataWithBytes:bytes length:size];
        }
    }
}

@end
