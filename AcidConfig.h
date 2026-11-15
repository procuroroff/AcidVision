//
//  AcidConfig.h
//  AcidVision
//
//  Every user-tunable knob lives here. Values are read once at injection time
//  from the rootless preferences domain com.procuroroff.acidvision and can be
//  overridden without rebuilding the tweak:
//
//    defaults write com.procuroroff.acidvision intensity -float 0.75
//    defaults write com.procuroroff.acidvision speed     -float 1.40
//    killall -9 SpringBoard Camera
//
//  (Run the defaults command as the mobile user, e.g. over SSH.)
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface AcidConfig : NSObject

@property (nonatomic, class, readonly) AcidConfig *shared;

/// Master switch for the SpringBoard overlay.
@property (nonatomic, readonly) BOOL enabled;
/// Master switch for the live viewfinder overlay inside Camera.app.
@property (nonatomic, readonly) BOOL cameraPreviewEnabled;
/// Master switch for the Core Image pass over captured photos.
@property (nonatomic, readonly) BOOL photoWarpEnabled;
/// Slow drift/rotation of Home Screen icons (SBIconView).
@property (nonatomic, readonly) BOOL driftEnabled;

/// 0...1. Overall opacity/strength of the SpringBoard shader.
@property (nonatomic, readonly) float intensity;
/// 0...1. Overall opacity/strength of the Camera viewfinder shader.
@property (nonatomic, readonly) float cameraIntensity;
/// 0...3. Animation speed multiplier (1 = author's default).
@property (nonatomic, readonly) float speed;
/// 0...1. RGB channel separation of the shader.
@property (nonatomic, readonly) float chroma;
/// 0...2. Strength of travelling ripple rings.
@property (nonatomic, readonly) float ripple;
/// 0...2. Hue-cycling speed.
@property (nonatomic, readonly) float hueSpeed;
/// 0...1. Film grain.
@property (nonatomic, readonly) float grain;
/// 0...1. Vignette.
@property (nonatomic, readonly) float vignette;
/// 0...1. Scanline intensity.
@property (nonatomic, readonly) float scanline;
/// 0...1. Glitchcore: block tears, RGB stutter, inverted blocks, VHS bars.
@property (nonatomic, readonly) float glitch;
/// 0...2. Icon drift amount (0 disables visible movement).
@property (nonatomic, readonly) float drift;

/// Photo pipeline, in pixels / radians.
@property (nonatomic, readonly) float photoTwirl;       // CITwirlDistortion angle, radians
@property (nonatomic, readonly) float photoBump;        // CIBumpDistortion scale
@property (nonatomic, readonly) float photoHue;         // CIHueAdjust angle, radians
@property (nonatomic, readonly) float photoSaturation;  // CIColorControls saturation
@property (nonatomic, readonly) float photoChroma;      // RGB split at 1000 px reference
@property (nonatomic, readonly) float photoPixelate;    // CIPixellate scale at 1000 px reference
@property (nonatomic, readonly) float photoPosterize;   // CIColorPosterize levels (0 = off)

- (void)reload;

@end

NS_ASSUME_NONNULL_END
