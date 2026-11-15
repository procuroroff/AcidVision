#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>

@class AcidConfig;

NS_ASSUME_NONNULL_BEGIN

/// Owns the Metal device, pipeline and per-frame uniforms. One renderer per
/// MTKView (SpringBoard overlay and Camera preview each get their own).
@interface AcidRenderer : NSObject

- (nullable instancetype)initWithView:(MTKView *)view
                               config:(AcidConfig *)config
                            intensity:(float)intensity NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly, nullable) NSString *failureReason;

- (void)drawInView:(MTKView *)view;

@end

NS_ASSUME_NONNULL_END
