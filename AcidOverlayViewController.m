#import "AcidOverlayViewController.h"

#import "AcidConfig.h"
#import "AcidMetalView.h"

@implementation AcidOverlayViewController

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    view.backgroundColor = UIColor.clearColor;
    view.opaque = NO;
    view.userInteractionEnabled = NO;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    AcidConfig *config = [AcidConfig shared];
    if (!config.enabled) {
        return;
    }

    AcidMetalView *metalView = [[AcidMetalView alloc] initWithFrame:self.view.bounds
                                                            config:config
                                                         intensity:config.intensity];
    [self.view addSubview:metalView];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end
