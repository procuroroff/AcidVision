#import "AcidCameraPreviewManager.h"

#import "AcidConfig.h"
#import "AcidMetalView.h"

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kAcidPreviewLayerKey = &kAcidPreviewLayerKey;
static const void *kAcidPreviewHostKey = &kAcidPreviewHostKey;

@implementation AcidCameraPreviewManager {
    BOOL _observing;
}

+ (instancetype)sharedManager {
    static AcidCameraPreviewManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [AcidCameraPreviewManager new];
    });
    return manager;
}

- (void)start {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self start];
        });
        return;
    }

    if (![AcidConfig shared].cameraPreviewEnabled) {
        return;
    }

    if (!_observing) {
        _observing = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }

    // Camera constructs its preview shortly after launch, and again when the
    // app returns from the background. Try a few times in case the preview
    // layer is created before its host view has a non-zero layout.
    for (NSNumber *delay in @[@0.6, @2.0, @4.5]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self scan];
        });
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self scan];
    });
}

- (void)scan {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scan];
        });
        return;
    }

    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        [self scanView:window];
    }
}

- (void)scanView:(UIView *)view {
    if (!view) {
        return;
    }

    [self scanLayer:view.layer];

    // Copy: attaching an overlay mutates the host's subview list.
    for (UIView *subview in [view.subviews copy]) {
        [self scanView:subview];
    }
}

- (void)scanLayer:(CALayer *)layer {
    if (!layer) {
        return;
    }

    if ([layer isKindOfClass:AVCaptureVideoPreviewLayer.class]) {
        [self attachToPreviewLayer:(AVCaptureVideoPreviewLayer *)layer];
    }

    // Copy: attaching an overlay adds a sublayer to the host, which may be the
    // layer we are currently iterating.
    for (CALayer *sublayer in [layer.sublayers copy]) {
        [self scanLayer:sublayer];
    }
}

- (void)attachToPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    if (!previewLayer) {
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self attachToPreviewLayer:previewLayer];
        });
        return;
    }

    AcidConfig *config = [AcidConfig shared];
    if (!config.cameraPreviewEnabled || config.cameraIntensity <= 0.01f) {
        return;
    }

    if (objc_getAssociatedObject(previewLayer, kAcidPreviewLayerKey)) {
        return;
    }

    UIView *host = [self hostViewForLayer:previewLayer];
    if (!host) {
        return;
    }
    if (CGRectIsEmpty(host.bounds) || host.window == nil) {
        return; // layout has not happened yet; the next scan will retry
    }
    if (objc_getAssociatedObject(host, kAcidPreviewHostKey)) {
        objc_setAssociatedObject(previewLayer, kAcidPreviewLayerKey, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    AcidMetalView *overlay = [[AcidMetalView alloc] initWithFrame:host.bounds
                                                          config:config
                                                       intensity:config.cameraIntensity];
    if (!overlay) {
        return;
    }
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.userInteractionEnabled = NO;
    [host addSubview:overlay];

    objc_setAssociatedObject(previewLayer, kAcidPreviewLayerKey, overlay,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(host, kAcidPreviewHostKey, overlay,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSLog(@"[AcidVision] live preview overlay attached to %@", NSStringFromClass(host.class));
}

- (UIView *)hostViewForLayer:(CALayer *)layer {
    CALayer *cursor = layer;
    while (cursor) {
        id delegate = cursor.delegate;
        if ([delegate isKindOfClass:UIView.class]) {
            return (UIView *)delegate;
        }
        cursor = cursor.superlayer;
    }
    return nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
