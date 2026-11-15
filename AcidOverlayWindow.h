#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A window that is visible above every normal system window but is completely
/// transparent to touches. Both -pointInside:withEvent: and -hitTest:withEvent:
/// are neutralised: returning NO/nil from the top window makes UIKit continue
/// hit-testing the windows below it.
@interface AcidOverlayWindow : UIWindow
@end

NS_ASSUME_NONNULL_END
