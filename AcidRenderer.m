#import "AcidRenderer.h"

#import "AcidConfig.h"
#import "AcidShaderTypes.h"
#import "ShadersSource.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <TargetConditionals.h>

@implementation AcidRenderer {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipeline;
    AcidConfig *_config;
    float _intensity;
    CFTimeInterval _startTime;
    CGSize _drawableSize;
}

- (instancetype)initWithView:(MTKView *)view
                      config:(AcidConfig *)config
                   intensity:(float)intensity {
    self = [super init];
    if (!self) {
        return nil;
    }

    _config = config;
    _intensity = intensity;
    _startTime = CACurrentMediaTime();

    _device = view.device ?: MTLCreateSystemDefaultDevice();
    if (!_device) {
        _failureReason = @"MTLCreateSystemDefaultDevice() returned nil";
        return nil;
    }

    view.device = _device;
    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    view.framebufferOnly = YES;
    view.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    view.opaque = NO;
    view.backgroundColor = UIColor.clearColor;
    view.layer.opaque = NO;

    _commandQueue = [_device newCommandQueue];
    if (!_commandQueue) {
        _failureReason = @"Could not create an MTLCommandQueue";
        return nil;
    }

    // Compile MSL off the main thread: SpringBoard startup should not stall
    // while the Metal compiler works. Frames drawn before the pipeline is
    // ready are simply skipped.
    MTLPixelFormat pixelFormat = MTLPixelFormatBGRA8Unorm;
    view.colorPixelFormat = pixelFormat;

    __weak AcidRenderer *weakSelf = self;
    id<MTLDevice> device = _device;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        AcidRenderer *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        NSError *error = nil;
        id<MTLLibrary> library = [device newLibraryWithSource:kAcidShaderSource
                                                       options:nil
                                                         error:&error];
        if (!library) {
            @synchronized(strongSelf) {
                strongSelf->_failureReason =
                    [NSString stringWithFormat:@"Metal shader compilation failed: %@",
                     error.localizedDescription ?: @"unknown error"];
                NSLog(@"[AcidVision] %@", strongSelf->_failureReason);
            }
            return;
        }

        id<MTLFunction> vertexFunction = [library newFunctionWithName:@"acid_vertex"];
        id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"acid_fragment"];
        if (!vertexFunction || !fragmentFunction) {
            @synchronized(strongSelf) {
                strongSelf->_failureReason = @"Metal shader entry points are missing";
                NSLog(@"[AcidVision] %@", strongSelf->_failureReason);
            }
            return;
        }

        MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
        descriptor.label = @"AcidVision";
        descriptor.vertexFunction = vertexFunction;
        descriptor.fragmentFunction = fragmentFunction;
        descriptor.colorAttachments[0].pixelFormat = pixelFormat;

        // Premultiplied alpha, standard source-over compositing.
        MTLRenderPipelineColorAttachmentDescriptor *attachment = descriptor.colorAttachments[0];
        attachment.blendingEnabled = YES;
        attachment.sourceRGBBlendFactor = MTLBlendFactorOne;
        attachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        attachment.sourceAlphaBlendFactor = MTLBlendFactorOne;
        attachment.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

        id<MTLRenderPipelineState> pipeline =
            [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
        @synchronized(strongSelf) {
            if (pipeline) {
                strongSelf->_pipeline = pipeline;
                NSLog(@"[AcidVision] Metal pipeline ready");
            } else {
                strongSelf->_failureReason =
                    [NSString stringWithFormat:@"Could not create render pipeline: %@",
                     error.localizedDescription ?: @"unknown error"];
                NSLog(@"[AcidVision] %@", strongSelf->_failureReason);
            }
        }
    });

    return self;
}

- (void)drawInView:(MTKView *)view {
    id<MTLRenderPipelineState> pipeline = nil;
    @synchronized(self) {
        pipeline = _pipeline;
    }
    if (!pipeline || !_commandQueue || !_device) {
        return;
    }

    CGSize size = view.drawableSize;
    if (size.width < 1.0 || size.height < 1.0) {
        return;
    }
    _drawableSize = size;

    MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (!pass || !drawable) {
        return;
    }

    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;

    AcidUniforms uniforms = {0};
    uniforms.time = (float)(CACurrentMediaTime() - _startTime);
    uniforms.intensity = _intensity;
    uniforms.speed = _config.speed;
    uniforms.chroma = _config.chroma;
    uniforms.ripple = _config.ripple;
    uniforms.hueSpeed = _config.hueSpeed;
    uniforms.grain = _config.grain;
    uniforms.vignette = _config.vignette;
    uniforms.width = (float)size.width;
    uniforms.height = (float)size.height;
    uniforms.touchX = 0.5f;
    uniforms.touchY = 0.5f;
    uniforms.touchActive = 0.0f;
    uniforms.hueShift = 0.0f;
    uniforms.scanline = _config.scanline;

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"AcidVision frame";

    id<MTLRenderCommandEncoder> encoder =
        [commandBuffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:pipeline];
    [encoder setFragmentBytes:&uniforms length:sizeof(uniforms) atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

@end
