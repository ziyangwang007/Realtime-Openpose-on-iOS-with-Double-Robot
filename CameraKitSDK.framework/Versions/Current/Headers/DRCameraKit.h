//
//  DRCameraKit.h
//  Camera Kit SDK
//
//  Created by David Cann on 11/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>

#define kCameraKitSDKVersion @"0.1"

@class DRCameraKit;

@protocol DRCameraKitConnectionDelegate <NSObject>
- (void)cameraKitConnectionStatusDidChange:(DRCameraKit *)theKit;
@end

@protocol DRCameraKitImageDelegate <NSObject>
- (void)cameraKit:(DRCameraKit *)theKit didReceiveImage:(UIImage *)theImage sizeInBytes:(NSInteger)length;
@end

@protocol DRCameraKitControlDelegate <NSObject>
- (void)cameraKitReceivedStatusUpdate:(DRCameraKit *)theKit;
@end

typedef struct {
	unsigned int reg;
	unsigned char value;
} cameraSetting;

@interface DRCameraKit : NSObject

extern NSString *const kCameraKitVideoProtocolString;
extern NSString *const kCameraKitControlProtocolString;

extern const cameraSetting kCameraSettingsFullRes_15FPS[];
extern const cameraSetting kCameraSettingsFullRes_15FPS_low[];
extern const cameraSetting kCameraSettings1280x960_30FPS[];
extern const cameraSetting kCameraSettings640x480_30FPS[];
extern const cameraSetting kCameraSettings640x480_30FPS_low[];
extern const cameraSetting kCameraSettings1280x960_15FPS_ISP[];
extern const cameraSetting kCameraSettings640x480_15FPS_ISP[];
extern const cameraSetting kCameraSettings640x480_15FPS_ISP_low[];

@property (nonatomic, weak) id <DRCameraKitConnectionDelegate> connectionDelegate;
@property (nonatomic, weak) id <DRCameraKitImageDelegate> imageDelegate;
@property (nonatomic, weak) id <DRCameraKitControlDelegate> controlDelegate;
@property (nonatomic, readonly) BOOL videoIsStreaming;
@property (nonatomic) NSInteger firmwareVersion;

#pragma mark - Singleton
+ (DRCameraKit *)sharedCameraKit;

#pragma mark - Setup
- (BOOL)isConnected;
- (void)disconnect;
- (void)connectToAccessory:(EAAccessory *)theAccessory;
- (void)startVideo;
- (void)stopVideo;
- (void)setCameraSettingsWithArray:(cameraSetting*)settings;
- (void)setCameraSetting:(unsigned int)reg value:(unsigned char)value;
- (void)startCharging;
- (void)stopCharging;
- (void)setLED:(UIColor*)color;
- (void)fadeLEDtoColor:(UIColor*)color overTime:(NSInteger)millis;
- (void)requestStatus;
- (NSString *)iAPFirmwareVersion;
- (NSString *)iAPSerialNumber;
- (NSString *)iAPHardwareRevision;
- (cameraSetting *)lastCameraSetting;
- (BOOL)needsOverscanCrop;
- (CGSize)sizeForCameraSetting:(cameraSetting *)theSetting;

@end
