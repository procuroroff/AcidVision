//
//  Shaders.metal
//  AcidVision
//
//  Runtime-compiled Metal Shading Language. The tweak embeds this file as a
//  C string via scripts/embed_shader.py (generated header: ShadersSource.h),
//  so nothing has to compile .metal at package-build time. This keeps the
//  Theos package buildable with the Linux cross-toolchain.
//
//  Pipeline: one full-screen triangle, no vertex buffer, one fragment shader.
//  The fragment shader generates a liquid colour field, warps its own domain,
//  splits R/G/B and composites the result with premultiplied alpha.
//

#include <metal_stdlib>
using namespace metal;

struct AcidUniforms {
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
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut acid_vertex(uint vertexID [[vertex_id]]) {
    // Oversized triangle that covers the whole clip space.
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    float2 p = positions[vertexID];

    VertexOut out;
    out.position = float4(p, 0.0, 1.0);
    out.uv = p * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y; // Metal NDC -> UIKit top-left origin
    return out;
}

static float acid_hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float3 acid_hsv2rgb(float3 c) {
    float3 p = abs(fract(c.xxx + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, float3(0.0), float3(1.0)), float3(c.y));
}

// A smooth, moving rainbow in polar coordinates. `hueOffset` is used to shift
// the three colour channels independently -> chromatic aberration.
static float3 acid_palette(float2 p, float t, float hueOffset) {
    float r = length(p);
    float a = atan2(p.y, p.x);

    float hue = fract(0.58 + a / 6.28318530718 + r * 0.55 + t * 0.045 + hueOffset);
    float sat = clamp(0.78 + 0.18 * sin(r * 9.0 - t * 1.7), 0.0, 1.0);
    return acid_hsv2rgb(float3(hue, sat, 0.95));
}

fragment float4 acid_fragment(VertexOut in [[stage_in]],
                              constant AcidUniforms &u [[buffer(0)]]) {
    float2 resolution = float2(max(u.width, 1.0), max(u.height, 1.0));
    float aspect = resolution.x / resolution.y;

    float2 uv = in.uv;
    float2 p = (uv - 0.5) * float2(aspect, 1.0);

    float t = u.time * max(u.speed, 0.0);
    float strength = clamp(u.intensity, 0.0, 1.0);

    // --- 1. Domain warp: three interfering sine/cosine fields. -------------
    float w1 = sin(p.x * 5.3 + t * 0.90) * cos(p.y * 4.1 - t * 0.70);
    float w2 = sin((p.x + p.y) * 7.7 - t * 1.30);
    float w3 = cos(p.y * 9.1 + t * 0.50) * sin(p.x * 3.7 - t * 0.40);
    float2 warp = float2(w1 + 0.45 * w2, w3 + 0.35 * w2);

    // --- 2. Travelling ripple ring. ----------------------------------------
    float2 rippleCenter = float2(0.42 * cos(t * 0.21), 0.38 * sin(t * 0.27));
    float2 delta = p - rippleCenter;
    float dist = length(delta) + 1e-4;
    float ring = sin(dist * 16.0 - t * 2.6) * exp(-dist * 2.2);
    warp += (delta / dist) * ring * u.ripple;

    // Optional second ripple at a touch point (reserved for future input).
    if (u.touchActive > 0.5) {
        float2 touch = (float2(u.touchX, u.touchY) - 0.5) * float2(aspect, 1.0);
        float2 td = p - touch;
        float tdist = length(td) + 1e-4;
        warp += (td / tdist) * sin(tdist * 24.0 - t * 5.0) * exp(-tdist * 4.0) * u.ripple;
    }

    float2 warped = p + warp * 0.075 * strength;

    // --- 3. Chromatic aberration: three palettes, three offsets. -----------
    float ca = u.chroma * 0.012 * strength;
    float3 colR = acid_palette(warped + float2(ca, 0.0), t, 0.0);
    float3 colG = acid_palette(warped, t, 0.0);
    float3 colB = acid_palette(warped - float2(ca, 0.0), t, 0.0);
    float3 col = float3(colR.r, colG.g, colB.b);

    // --- 4. Wet specular highlight along the wave crests. ------------------
    float spec = pow(max(0.0, 1.0 - abs(warp.x + warp.y) * 0.85), 12.0);
    col += spec * float3(0.35, 0.55, 0.85) * strength;

    // --- 5. Hue drift. -----------------------------------------------------
    float hue = u.hueShift + t * u.hueSpeed;
    float3 hueColor = acid_hsv2rgb(float3(fract(hue), 0.85, 1.0));
    col = mix(col, col * hueColor * 1.60, float3(0.16 * strength));

    // --- 6. Scanlines + grain. --------------------------------------------
    float scan = 0.5 + 0.5 * sin((uv.y * resolution.y + t * 60.0) * 3.14159265);
    col *= 1.0 - u.scanline * 0.25 * scan;

    float grain = acid_hash21(uv * resolution + fract(t) * 91.7);
    col += (grain - 0.5) * u.grain;

    // --- 7. Vignette. ------------------------------------------------------
    float vig = 1.0 - smoothstep(0.25, 1.15, length(p));
    col *= mix(1.0, vig, u.vignette);

    // --- 8. Alpha. Keep enough transparency that the UI stays readable. ----
    float energy = clamp(length(warp) * 0.55 + abs(ring) * 0.65, 0.0, 1.0);
    float alpha = clamp((0.14 + 0.42 * energy) * strength, 0.0, 0.72);
    alpha *= mix(0.55, 1.0, vig);

    col = clamp(col, 0.0, 1.0);
    return float4(col * alpha, alpha); // premultiplied
}
