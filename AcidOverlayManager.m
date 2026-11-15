#import "AcidOverlayManager.h"

#import "AcidConfig.h"
#import "AcidOverlayViewController.h"
#import "AcidOverlayWindow.h"

#import <UIKit/UIKit.h>

@implementation AcidOverlayManager {
    AcidOverlayWindow *_window;
    NSInteger _retryCount;
    BOOL _observing;
}

+ (instancetype)sharedManager {
    static AcidOverlayManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [AcidOverlayManager new];
    });
    return manager;
}

- (void)start {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self start];
        });
        return;
    }

    AcidConfig *config = [AcidConfig shared];
    if (!config.enabled) {
        NSLog(@"[AcidVision] disabled by preferences");
        return;
    }

    if (_window) {
        _window.hidden = NO;
        return;
    }

    UIWindowScene *scene = [self foregroundWindowScene];
    if (!scene) {
        // During early boot SpringBoard may not have connected its scene yet.
        if (_retryCount < 40) {
            _retryCount += 1;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self start];
            });
        }
        return;
    }

    [self installObservers];

    AcidOverlayWindow *window = [[AcidOverlayWindow alloc] initWithWindowScene:scene];
    window.frame = UIScreen.mainScreen.bounds;
    window.windowLevel = UIWindowLevelAlert + 100.0;
    window.backgroundColor = UIColor.clearColor;
    window.opaque = NO;
    window.rootViewController = [AcidOverlayViewController new];
    window.hidden = NO;

    _window = window;
    _retryCount = 0;

    NSLog(@"[AcidVision] overlay window installed at level %.0f", window.windowLevel);
}

- (void)stop {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stop];
        });
        return;
    }

    _window.hidden = YES;
    _window = nil;
}

- (UIWindowScene *)foregroundWindowScene {
    UIApplication *application = UIApplication.sharedApplication;
    UIWindowScene *fallback = nil;

    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState == UISceneActivationStateForegroundActive) {
            return windowScene;
        }
        if (!fallback && windowScene.activationState != UISceneActivationStateUnattached) {
            fallback = windowScene;
        }
    }
    return fallback;
}

- (void)installObservers {
    if (_observing) {
        return;
    }
    _observing = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (_window) {
        _window.hidden = NO;
    } else {
        [self start];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
