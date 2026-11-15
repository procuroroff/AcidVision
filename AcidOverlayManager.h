#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Creates and owns the SpringBoard overlay window. Safe to call repeatedly.
@interface AcidOverlayManager : NSObject

+ (instancetype)sharedManager;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
