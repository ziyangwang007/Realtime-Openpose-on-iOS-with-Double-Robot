

#import "CameraHelper.h"

@implementation CameraHelper

-(void) configureQuality:(DRCameraKit *) camera {
    [camera setCameraSettingsWithArray:(cameraSetting *)kCameraSettings1280x960_30FPS];
};

-(void) start: (DRCameraKit *) camera {
    [camera startVideo];
};

-(void) stop: (DRCameraKit *) camera {
    [camera stopVideo];
};

@end
