//
//  Tweak.x
//  AcidVision
//
//  Two injection targets (see AcidVision.plist):
//    com.apple.springboard -> Metal overlay above the UI + icon drift
//    com.apple.camera     -> live viewfinder overlay + permanently warped photos
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

#import "AcidCameraPreviewManager.h"
#import "AcidCameraProcessor.h"
#import "AcidConfig.h"
#import "AcidDriftAnimator.h"
#import "AcidOverlayManager.h"

static BOOL AcidIsCameraProcess(void) {
    static BOOL isCamera;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        isCamera = [[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.camera"];
    });
    return isCamera;
}

#pragma mark - SpringBoard

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    // Give SpringBoard a moment to attach its window scene, then install the
    // overlay. AcidOverlayManager also retries if the scene is not ready yet.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[AcidOverlayManager sharedManager] start];
    });
}

%end

#pragma mark - Home Screen icon drift

%hook UIView

- (void)didMoveToWindow {
    %orig;
    [AcidDriftAnimator attachToViewIfNeeded:self];
}

%end

#pragma mark - Camera: live preview

%hook AVCaptureVideoPreviewLayer

- (void)setSession:(AVCaptureSession *)session {
    %orig;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[AcidCameraPreviewManager sharedManager] attachToPreviewLayer:self];
    });
}

- (void)layoutSublayers {
    %orig;

    // The layer is often created (and gets its session) before it is added to
    // a laid-out host. Once layout happens, the host has real bounds.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[AcidCameraPreviewManager sharedManager] attachToPreviewLayer:self];
    });
}

%end

#pragma mark - Camera: still photos

%hook AVCapturePhoto

- (NSData *)fileDataRepresentation {
    NSData *data = %orig;
    return [[AcidCameraProcessor sharedProcessor] processedDataForPhoto:self
                                                            originalData:data];
}

- (NSData *)fileDataRepresentationWithCustomizer:
    (id<AVCapturePhotoFileDataRepresentationCustomizer>)customizer {
    NSData *data = %orig;
    return [[AcidCameraProcessor sharedProcessor] processedDataForPhoto:self
                                                            originalData:data];
}

%end

// Safety net for Camera builds that hand the original file directly to Photos
// instead of asking AVCapturePhoto for its representation. The EXIF marker
// written by AcidCameraProcessor makes this a no-op for already-warped data.
%hook PHAssetCreationRequest

- (void)addResourceWithType:(PHAssetResourceType)type
                       data:(NSData *)data
                    options:(PHAssetResourceCreationOptions *)options {
    // SpringBoard also creates PHAssetCreationRequest objects (screenshots).
    // Only Camera captures should be warped.
    if (AcidIsCameraProcess() && type == PHAssetResourceTypePhoto && data.length > 0) {
        NSData *processed = [[AcidCameraProcessor sharedProcessor] processedDataForData:data
                                                                              metadata:nil];
        if (processed.length > 0) {
            data = processed;
        }
    }
    %orig(type, data, options);
}

%end

#pragma mark - Entry point

%ctor {
    @autoreleasepool {
        [[AcidConfig shared] reload];

        NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier ?: @"";
        NSString *processName = [NSProcessInfo processInfo].processName ?: @"";

        NSLog(@"[AcidVision] injected into %@ (%@)", processName, bundleIdentifier);

        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [[AcidOverlayManager sharedManager] start];
            });
        } else if ([bundleIdentifier isEqualToString:@"com.apple.camera"]) {
            [[AcidCameraPreviewManager sharedManager] start];
        }
    }
}
