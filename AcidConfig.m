#import "AcidConfig.h"

static NSString *const kAcidPrefsDomain = @"com.procuroroff.acidvision";

static BOOL AcidBool(NSUserDefaults *defaults, NSString *key, BOOL fallback) {
    NSNumber *value = [defaults objectForKey:key];
    return value ? value.boolValue : fallback;
}

static float AcidFloat(NSUserDefaults *defaults, NSString *key, float fallback, float lo, float hi) {
    NSNumber *value = [defaults objectForKey:key];
    float result = value ? value.floatValue : fallback;
    if (result < lo) result = lo;
    if (result > hi) result = hi;
    return result;
}

@implementation AcidConfig {
    NSUserDefaults *_defaults;
}

+ (AcidConfig *)shared {
    static AcidConfig *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [AcidConfig new];
        [shared reload];
    });
    return shared;
}

- (void)reload {
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:kAcidPrefsDomain];

    _enabled = AcidBool(_defaults, @"enabled", YES);
    _cameraPreviewEnabled = AcidBool(_defaults, @"cameraPreviewEnabled", YES);
    _photoWarpEnabled = AcidBool(_defaults, @"photoWarpEnabled", YES);
    _driftEnabled = AcidBool(_defaults, @"driftEnabled", YES);

    _intensity = AcidFloat(_defaults, @"intensity", 0.55f, 0.0f, 1.0f);
    _cameraIntensity = AcidFloat(_defaults, @"cameraIntensity", 0.34f, 0.0f, 1.0f);
    _speed = AcidFloat(_defaults, @"speed", 1.0f, 0.0f, 3.0f);
    _chroma = AcidFloat(_defaults, @"chroma", 0.38f, 0.0f, 1.0f);
    _ripple = AcidFloat(_defaults, @"ripple", 0.60f, 0.0f, 2.0f);
    _hueSpeed = AcidFloat(_defaults, @"hueSpeed", 0.24f, 0.0f, 2.0f);
    _grain = AcidFloat(_defaults, @"grain", 0.055f, 0.0f, 1.0f);
    _vignette = AcidFloat(_defaults, @"vignette", 0.36f, 0.0f, 1.0f);
    _scanline = AcidFloat(_defaults, @"scanline", 0.12f, 0.0f, 1.0f);
    _drift = AcidFloat(_defaults, @"drift", 0.60f, 0.0f, 2.0f);

    _photoTwirl = AcidFloat(_defaults, @"photoTwirl", 2.15f, -6.0f, 6.0f);
    _photoBump = AcidFloat(_defaults, @"photoBump", 0.34f, -1.0f, 1.0f);
    _photoHue = AcidFloat(_defaults, @"photoHue", 0.55f, -3.14159f, 3.14159f);
    _photoSaturation = AcidFloat(_defaults, @"photoSaturation", 1.45f, 0.0f, 3.0f);
    _photoChroma = AcidFloat(_defaults, @"photoChroma", 4.0f, 0.0f, 30.0f);
}

@end
