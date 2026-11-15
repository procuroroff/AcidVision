#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Gives Home Screen icons a slow, independent drift. This is what makes the
/// SpringBoard UI itself move instead of only receiving a colour overlay.
/// Called from a -[UIView didMoveToWindow] hook, so it must be cheap and
/// idempotent.
@interface AcidDriftAnimator : NSObject

+ (void)attachToViewIfNeeded:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
