#import "AcidMetalView.h"

#import "AcidConfig.h"
#import "AcidRenderer.h"

#import <UIKit/UIKit.h>

@implementation AcidMetalView {
    AcidRenderer *_renderer;
}

- (instancetype)initWithFrame:(CGRect)frame
                       config:(AcidConfig *)config
                    intensity:(float)intensity {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    self = [super initWithFrame:frame device:device];
    if (!self) {
        return nil;
    }

    _intensity = intensity;

    self.delegate = self;
    self.opaque = NO;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
    self.multipleTouchEnabled = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.framebufferOnly = YES;
    self.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    self.enableSetNeedsDisplay = NO;
    self.paused = NO;
    self.preferredFramesPerSecond = 60;
    self.layer.opaque = NO;

    _renderer = [[AcidRenderer alloc] initWithView:self config:config intensity:intensity];
    if (!_renderer) {
        self.paused = YES;
        self.hidden = YES;
    }

    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil;
}

- (void)drawInMTKView:(MTKView *)view {
    [_renderer drawInView:view];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // MTKView handles the drawable resize; uniforms read drawableSize each frame.
}

@end
