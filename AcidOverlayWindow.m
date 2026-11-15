#import "AcidOverlayWindow.h"

@implementation AcidOverlayWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil;
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)canBecomeFocused {
    return NO;
}

@end
