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

    // Install observers before the scene lookup: if SpringBoard is still
    // booting, the retry loop may run out, but the next scene activation or
    // app-active notification must be able to restart it.
    [self installObservers];

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

    AcidOverlayWindow *window = [[AcidOverlayWindow alloc] initWithWindowScene:scene];
    window.frame = UIScreen.mainScreen.bounds;
    window.windowLevel = UIWindowLevelAlert + 100.0;
    window.backgroundColor = UIColor.clearColor;
    window.opaque = NO;
    window.userInteractionEnabled = NO;
    window.layer.allowsHitTesting = NO;
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

    // SpringBoard sometimes exposes the main scene only through an existing
    // window before -connectedScenes settles.
    if (!fallback) {
        for (UIWindow *window in application.windows) {
            if (window.windowScene) {
                return window.windowScene;
            }
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sceneDidActivate:)
                                                 name:UISceneDidActivateNotification
                                               object:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    _retryCount = 0;
    if (_window) {
        _window.hidden = NO;
    } else {
        [self start];
    }
}

- (void)sceneDidActivate:(NSNotification *)notification {
    _retryCount = 0;
    if (!_window) {
        [self start];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
