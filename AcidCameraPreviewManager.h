#import <Foundation/Foundation.h>

@class AVCaptureVideoPreviewLayer;

NS_ASSUME_NONNULL_BEGIN

/// Finds Camera.app's AVCaptureVideoPreviewLayer and puts a transparent Metal
/// view on top of it. The preview remains live; the shader adds the moving
/// liquid/colour field in real time.
@interface AcidCameraPreviewManager : NSObject

+ (instancetype)sharedManager;

- (void)start;
- (void)attachToPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer;
- (void)detachFromPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer;

@end

NS_ASSUME_NONNULL_END
