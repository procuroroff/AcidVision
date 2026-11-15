#import "AcidDriftAnimator.h"

#import "AcidConfig.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static const void *kAcidDriftKey = &kAcidDriftKey;

@implementation AcidDriftAnimator

+ (void)attachToViewIfNeeded:(UIView *)view {
    if (!view || !view.window) {
        return;
    }

    AcidConfig *config = [AcidConfig shared];
    if (!config.driftEnabled || config.drift <= 0.01f) {
        return;
    }

    Class iconClass = NSClassFromString(@"SBIconView");
    if (!iconClass || ![view isKindOfClass:iconClass]) {
        return;
    }

    if (objc_getAssociatedObject(view, kAcidDriftKey)) {
        return;
    }
    objc_setAssociatedObject(view, kAcidDriftKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGFloat amplitude = 4.0 * config.drift;
    NSTimeInterval duration = 7.5 + (arc4random_uniform(450) / 100.0);

    CAKeyframeAnimation *drift =
        [CAKeyframeAnimation animationWithKeyPath:@"transform.translation"];
    drift.values = @[
        [NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(amplitude, -amplitude * 0.6)],
        [NSValue valueWithCGPoint:CGPointMake(0.0, amplitude)],
        [NSValue valueWithCGPoint:CGPointMake(-amplitude, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)],
    ];
    drift.duration = duration;
    drift.repeatCount = HUGE_VALF;
    drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    drift.additive = YES;
    drift.removedOnCompletion = NO;
    [view.layer addAnimation:drift forKey:@"acid.drift.translation"];

    CABasicAnimation *rotation =
        [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotation.fromValue = @(-0.030);
    rotation.toValue = @(0.030);
    rotation.duration = duration * 0.7;
    rotation.autoreverses = YES;
    rotation.repeatCount = HUGE_VALF;
    rotation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    rotation.additive = YES;
    rotation.removedOnCompletion = NO;
    [view.layer addAnimation:rotation forKey:@"acid.drift.rotation"];
}

@end
