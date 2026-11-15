#ifndef AcidShaderTypes_h
#define AcidShaderTypes_h

#include <stdint.h>

// Must stay byte-for-byte compatible with `struct AcidUniforms` in Shaders.metal.
// 16 x float = 64 bytes, no padding surprises.
typedef struct {
    float time;
    float intensity;
    float speed;
    float chroma;
    float ripple;
    float hueSpeed;
    float grain;
    float vignette;
    float width;
    float height;
    float touchX;
    float touchY;
    float touchActive;
    float hueShift;
    float scanline;
    float padding;
} AcidUniforms;

#endif /* AcidShaderTypes_h */
