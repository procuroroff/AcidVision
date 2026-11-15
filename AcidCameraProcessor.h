#import <Foundation/Foundation.h>

@class AVCapturePhoto;

NS_ASSUME_NONNULL_BEGIN

/// Core Image pipeline for still photos. It is idempotent: processed output is
/// tagged in EXIF UserComment, so the AVCapturePhoto hook and the
/// PHAssetCreationRequest safety-net hook cannot warp the same photo twice.
@interface AcidCameraProcessor : NSObject

+ (instancetype)sharedProcessor;

/// Called from -[AVCapturePhoto fileDataRepresentation]. Caches per photo.
- (nullable NSData *)processedDataForPhoto:(AVCapturePhoto *)photo
                              originalData:(NSData *)data;

/// Processes arbitrary image data (HEIC/JPEG). Returns the input unchanged if
/// it is already tagged, is RAW, or if anything goes wrong.
- (nullable NSData *)processedDataForData:(NSData *)data
                                 metadata:(nullable NSDictionary *)metadata;

@end

NS_ASSUME_NONNULL_END
