#import "AcidOverlayWindow.h"

@interface AcidOverlayWindow ()
// Private UIKit window-server hook: when it returns YES the window is skipped
// during hit-testing in other processes too, not only inside SpringBoard.
// This is what keeps app controls alive under a full-screen SpringBoard
// overlay (pointInside:/hitTest: alone only work inside the owning process).
- (BOOL)_ignoresHitTest;
- (BOOL)_usesWindowServerHitTesting;
@end

@implementation AcidOverlayWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil;
}

- (BOOL)_ignoresHitTest {
    return YES;
}

- (BOOL)_usesWindowServerHitTesting {
    return NO;
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)canBecomeFocused {
    return NO;
}

@end
