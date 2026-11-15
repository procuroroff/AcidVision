#import "AcidCameraProcessor.h"

#import "AcidConfig.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>

static NSString *const kAcidMarker = @"AcidVision:processed:v1";
static const void *kAcidPhotoCacheKey = &kAcidPhotoCacheKey;

// The AVCapturePhoto hook and the PHAssetCreationRequest safety net run at
// different points and may hand us different NSData objects. Remember both the
// input and the output digests of a processed capture so the exact same bytes
// are never warped twice, even if ImageIO drops the EXIF marker.
static NSMutableOrderedSet<NSData *> *AcidProcessedDigests(void) {
    static NSMutableOrderedSet *digests;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        digests = [NSMutableOrderedSet orderedSet];
    });
    return digests;
}

static NSData *AcidDigestForData(NSData *data) {
    if (data.length == 0) {
        return nil;
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    return [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}

// Core Image Kernel Language (not MSL): a general kernel is needed because a
// colour kernel cannot sample neighbouring pixels. If the runtime refuses to
// compile this (very old/new OS), the rest of the photo chain still runs.
static NSString *const kAcidRGBSplitKernel =
    @"kernel vec4 acidRGBSplit(sampler src, float amount, vec2 extent) {\n"
     "    vec2 p = destCoord();\n"
     "    vec2 rp = clamp(p + vec2(amount, 0.0), vec2(0.0), extent);\n"
     "    vec2 bp = clamp(p - vec2(amount, 0.0), vec2(0.0), extent);\n"
     "    vec4 r = sample(src, samplerTransform(src, rp));\n"
     "    vec4 g = sample(src, samplerTransform(src, p));\n"
     "    vec4 b = sample(src, samplerTransform(src, bp));\n"
     "    return vec4(r.r, g.g, b.b, g.a);\n"
     "}\n";

@implementation AcidCameraProcessor

+ (instancetype)sharedProcessor {
    static AcidCameraProcessor *processor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        processor = [AcidCameraProcessor new];
    });
    return processor;
}

- (NSData *)processedDataForPhoto:(AVCapturePhoto *)photo originalData:(NSData *)data {
    if (!photo || data.length == 0) {
        return data;
    }
    if (![AcidConfig shared].photoWarpEnabled) {
        return data;
    }

    @synchronized(photo) {
        NSData *cached = objc_getAssociatedObject(photo, kAcidPhotoCacheKey);
        if (cached) {
            return cached;
        }

        NSData *processed = [self processedDataForData:data metadata:photo.metadata];
        if (processed && processed.length > 0) {
            objc_setAssociatedObject(photo, kAcidPhotoCacheKey, processed,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return processed ?: data;
    }
}

- (NSData *)processedDataForData:(NSData *)data metadata:(NSDictionary *)metadata {
    if (data.length == 0 || ![AcidConfig shared].photoWarpEnabled) {
        return data;
    }

    @autoreleasepool {
        NSData *inputDigest = AcidDigestForData(data);
        if (inputDigest) {
            @synchronized(AcidProcessedDigests()) {
                if ([AcidProcessedDigests() containsObject:inputDigest]) {
                    return data;
                }
            }
        }

        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if (!source) {
            return data;
        }

        NSData *result = data;
        BOOL remember = NO;
        CGImageDestinationRef destination = NULL;

        do {
            NSString *type = (__bridge NSString *)CGImageSourceGetType(source);
            if (type.length == 0) {
                type = @"public.jpeg";
            }

            NSString *lowerType = type.lowercaseString;
            if ([lowerType containsString:@"raw"] || [lowerType containsString:@"dng"]) {
                break;
            }

            NSDictionary *sourceProperties =
                CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
            NSDictionary *sourceExif =
                sourceProperties[(__bridge NSString *)kCGImagePropertyExifDictionary];
            NSString *comment =
                sourceExif[(__bridge NSString *)kCGImagePropertyExifUserComment];
            NSDictionary *sourceTiff =
                sourceProperties[(__bridge NSString *)kCGImagePropertyTIFFDictionary];
            NSString *description =
                sourceTiff[(__bridge NSString *)kCGImagePropertyTIFFImageDescription];
            if (([comment isKindOfClass:NSString.class] && [comment hasPrefix:kAcidMarker]) ||
                ([description isKindOfClass:NSString.class] && [description hasPrefix:kAcidMarker])) {
                remember = YES;
                break;
            }

            CIImage *image = [CIImage imageWithData:data];
            if (!image) {
                break;
            }

            // Bake EXIF orientation into pixels. The output is always written
            // with orientation 1, otherwise the warp would be rotated twice.
            NSDictionary *properties = image.properties ?: @{};
            NSNumber *orientation = properties[(__bridge NSString *)kCGImagePropertyOrientation];
            if (!orientation) {
                orientation = metadata[(__bridge NSString *)kCGImagePropertyOrientation];
            }
            int orientationValue = orientation.intValue;
            if (orientationValue > 1 && orientationValue <= 8) {
                image = [image imageByApplyingOrientation:orientationValue];
            }

            CGRect extent = image.extent;
            if (CGRectIsEmpty(extent)) {
                break;
            }
            if (extent.origin.x != 0.0 || extent.origin.y != 0.0) {
                image = [image imageByApplyingTransform:
                         CGAffineTransformMakeTranslation(-extent.origin.x, -extent.origin.y)];
                extent = image.extent;
            }

            AcidConfig *config = [AcidConfig shared];
            CGFloat minDimension = MIN(extent.size.width, extent.size.height);
            if (minDimension < 1.0) {
                break;
            }

            // 1. Large, slow twirl: the "melted reality" component.
            CIFilter *twirl = [CIFilter filterWithName:@"CITwirlDistortion"];
            [twirl setValue:image forKey:kCIInputImageKey];
            [twirl setValue:[CIVector vectorWithX:CGRectGetMidX(extent)
                                                Y:CGRectGetMidY(extent)]
                     forKey:kCIInputCenterKey];
            [twirl setValue:@(minDimension * 0.62) forKey:kCIInputRadiusKey];
            [twirl setValue:@(config.photoTwirl) forKey:kCIInputAngleKey];
            if (twirl.outputImage) {
                image = twirl.outputImage;
            }

            // 2. Off-centre bump: a lens-like bulge that catches highlights.
            CIFilter *bump = [CIFilter filterWithName:@"CIBumpDistortion"];
            [bump setValue:image forKey:kCIInputImageKey];
            [bump setValue:[CIVector vectorWithX:CGRectGetWidth(extent) * 0.38
                                                Y:CGRectGetHeight(extent) * 0.62]
                     forKey:kCIInputCenterKey];
            [bump setValue:@(minDimension * 0.48) forKey:kCIInputRadiusKey];
            [bump setValue:@(config.photoBump) forKey:kCIInputScaleKey];
            if (bump.outputImage) {
                image = bump.outputImage;
            }

            // 3. Colour: hue rotation + saturation punch.
            CIFilter *hue = [CIFilter filterWithName:@"CIHueAdjust"];
            [hue setValue:image forKey:kCIInputImageKey];
            [hue setValue:@(config.photoHue) forKey:kCIInputAngleKey];
            if (hue.outputImage) {
                image = hue.outputImage;
            }

            CIFilter *controls = [CIFilter filterWithName:@"CIColorControls"];
            [controls setValue:image forKey:kCIInputImageKey];
            [controls setValue:@(config.photoSaturation) forKey:kCIInputSaturationKey];
            [controls setValue:@(1.03) forKey:kCIInputContrastKey];
            if (controls.outputImage) {
                image = controls.outputImage;
            }

            // 4. Glitchcore: chunky pixels + posterised colour bands.
            CGFloat pixelScale = config.photoPixelate * (minDimension / 1000.0);
            if (pixelScale > 0.5) {
                CIFilter *pixellate = [CIFilter filterWithName:@"CIPixellate"];
                [pixellate setValue:image forKey:kCIInputImageKey];
                [pixellate setValue:@(pixelScale) forKey:kCIInputScaleKey];
                [pixellate setValue:[CIVector vectorWithX:CGRectGetMidX(extent)
                                                        Y:CGRectGetMidY(extent)]
                             forKey:kCIInputCenterKey];
                if (pixellate.outputImage) {
                    image = pixellate.outputImage;
                }
            }

            if (config.photoPosterize >= 2.0) {
                CIFilter *posterize = [CIFilter filterWithName:@"CIColorPosterize"];
                [posterize setValue:image forKey:kCIInputImageKey];
                [posterize setValue:@(config.photoPosterize) forKey:@"inputLevels"];
                if (posterize.outputImage) {
                    image = posterize.outputImage;
                }
            }

            // 5. Chromatic aberration (custom CIKernel, optional).
            CGFloat splitPixels = config.photoChroma * (minDimension / 1000.0);
            if (splitPixels > 0.5) {
                CIImage *split = [self rgbSplitImage:image amount:splitPixels];
                if (split) {
                    image = split;
                }
            }

            image = [[image imageByClampingToExtent] imageByCroppingToRect:extent];
            CGImageRef cgImage = [[self context] createCGImage:image fromRect:extent];
            if (!cgImage) {
                break;
            }

            NSMutableData *encoded = [NSMutableData data];
            destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)encoded,
                                                           (__bridge CFStringRef)type, 1, NULL);
            if (!destination) {
                // Do not silently change the container (Camera has already
                // chosen the file extension/UTI). Leave the photo untouched.
                CGImageRelease(cgImage);
                break;
            }

            NSMutableDictionary *outputProperties = nil;
            NSDictionary *baseProperties = (metadata.count > 0) ? metadata : sourceProperties;
            if (baseProperties) {
                outputProperties = [baseProperties mutableCopy];
            } else {
                outputProperties = [NSMutableDictionary dictionary];
            }
            // The pixels were rotated and cropped; stale dimensions would make
            // some viewers and Photos importers misread the file.
            [outputProperties removeObjectForKey:(__bridge NSString *)kCGImagePropertyPixelWidth];
            [outputProperties removeObjectForKey:(__bridge NSString *)kCGImagePropertyPixelHeight];
            outputProperties[(__bridge NSString *)kCGImagePropertyOrientation] = @1;
            outputProperties[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality] = @0.95;

            NSMutableDictionary *exif =
                [outputProperties[(__bridge NSString *)kCGImagePropertyExifDictionary] mutableCopy]
                    ?: [NSMutableDictionary dictionary];
            exif[(__bridge NSString *)kCGImagePropertyExifUserComment] = kAcidMarker;
            outputProperties[(__bridge NSString *)kCGImagePropertyExifDictionary] = exif;

            NSMutableDictionary *tiff =
                [outputProperties[(__bridge NSString *)kCGImagePropertyTIFFDictionary] mutableCopy]
                    ?: [NSMutableDictionary dictionary];
            tiff[(__bridge NSString *)kCGImagePropertyTIFFOrientation] = @1;
            tiff[(__bridge NSString *)kCGImagePropertyTIFFImageDescription] = kAcidMarker;
            outputProperties[(__bridge NSString *)kCGImagePropertyTIFFDictionary] = tiff;

            CGImageDestinationAddImage(destination, cgImage,
                                       (__bridge CFDictionaryRef)outputProperties);
            BOOL ok = CGImageDestinationFinalize(destination);
            CGImageRelease(cgImage);
            CFRelease(destination);
            destination = NULL;

            if (ok && encoded.length > 0) {
                result = encoded;
                remember = YES;
                NSLog(@"[AcidVision] warped photo %@ (%lu bytes -> %lu bytes)",
                      type, (unsigned long)data.length, (unsigned long)encoded.length);
            }
        } while (0);

        if (destination) {
            CFRelease(destination);
        }
        if (remember && inputDigest) {
            NSMutableOrderedSet *digests = AcidProcessedDigests();
            @synchronized(digests) {
                [digests addObject:inputDigest];
                if (result != data) {
                    NSData *outputDigest = AcidDigestForData(result);
                    if (outputDigest) {
                        [digests addObject:outputDigest];
                    }
                }
                while (digests.count > 64) {
                    [digests removeObjectAtIndex:0];
                }
            }
        }
        CFRelease(source);
        return result;
    }
}

- (CIImage *)rgbSplitImage:(CIImage *)image amount:(CGFloat)amount {
    static CIKernel *kernel;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            kernel = [CIKernel kernelWithString:kAcidRGBSplitKernel];
        } @catch (NSException *exception) {
            NSLog(@"[AcidVision] RGB split kernel unavailable: %@", exception.reason);
            kernel = nil;
        }
    });

    if (!kernel) {
        return nil;
    }

    CGRect extent = image.extent;
    CGFloat inset = amount + 2.0;

    @try {
        return [kernel applyWithExtent:extent
                          roiCallback:^CGRect(int index, CGRect rect) {
                              return CGRectInset(rect, -inset, -inset);
                          }
                            arguments:@[
                                image,
                                @(amount),
                                [CIVector vectorWithX:extent.size.width
                                                    Y:extent.size.height]
                            ]];
    } @catch (NSException *exception) {
        NSLog(@"[AcidVision] RGB split failed: %@", exception.reason);
        return nil;
    }
}

- (CIContext *)context {
    static CIContext *context;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        NSDictionary *options = srgb
            ? @{kCIContextWorkingColorSpace: (__bridge id)srgb}
            : @{};
        context = [CIContext contextWithOptions:options];
        if (srgb) {
            CGColorSpaceRelease(srgb);
        }
    });
    return context;
}

@end
