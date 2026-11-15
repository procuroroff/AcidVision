#import <MetalKit/MetalKit.h>

@class AcidConfig;

NS_ASSUME_NONNULL_BEGIN

/// Transparent, non-interactive MTKView that runs the AcidVision shader.
/// Used both for the SpringBoard overlay and for the Camera viewfinder.
@interface AcidMetalView : MTKView <MTKViewDelegate>

- (instancetype)initWithFrame:(CGRect)frame
                       config:(AcidConfig *)config
                    intensity:(float)intensity;

@property (nonatomic, readonly) float intensity;

@end

NS_ASSUME_NONNULL_END
