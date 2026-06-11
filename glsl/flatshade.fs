#version 300 es
precision mediump float;   // no world-space derivative anymore -> mediump is plenty everywhere

flat in vec3 vNormal;      // world-space face normal, supplied per face by the vertex shader
in vec4 vColor;
in vec4 vClip;
out vec4 fragColor;

uniform vec3 uLightDir;       // UNIT direction TOWARD the light (pre-normalized on the CPU)
uniform mat4 uView;           // world -> view, to project the in-plane light dir onto the screen
uniform vec4 uLightColor;     // the light's color -- what fully-lit surfaces tend toward
uniform vec4 uAmbientColor;   // the unlit color surfaces tend toward (instead of black)
uniform float uGradStrength;  // how much the far-from-light edge of an oblique face darkens
uniform float uGradBright;    // how much the toward-light edge brightens ABOVE the lit color (0 = none)
uniform float uFogStart;      // eye-space depth (vClip.w) where fog begins
uniform float uFogEnd;        // eye-space depth where fog reaches full strength
uniform vec4  uFogColor;      // fog / haze color (rgb; a unused)
uniform float uFogAmount;     // max fog strength: 0 = off, 1 = distant surfaces fully fogged

void main() {
    // Per-face normal straight from the geometry (no derivatives), and the world directional light.
    vec3 N = normalize(vNormal);                     // renormalize: soak up mat3(uModel) scale slack
    vec3 L = uLightDir;                              // already unit, already toward the light
    float lambert = 0.2 + 0.8 * max(0.0, dot(N, L)); // the directional light, world space, as before

    // Artistic screen-space gradient. The part of L lying IN the face plane points "uphill"
    // toward the light along the surface; its length is the face's obliqueness to the light
    // (0 when the face faces the light -> no gradient, growing as it turns away). Project that
    // onto the screen and ramp brightness across the fragment's display position: the side of
    // an oblique face farther from the light darkens. Depends only on the normal, the light
    // direction, and screen position -- never on world coordinates.
    vec3 Lplane = L - dot(L, N) * N;                 // light direction within the face plane
    vec2 dir = (mat3(uView) * Lplane).xy;            // ...projected to the screen -> ramp direction
    float dlen = length(dir);
    // Strength rises monotonically with how far the face is turned from the light: 0 facing the
    // light, up to 1 facing fully away. (Using |Lplane| = sin(angle) here was the bipolar version
    // -- it peaked edge-on and fell back to 0 on away-facing polys, leaving them on plain Lambert.)
    float turn = clamp((1.0 - dot(N, L)) * 0.5, 0.0, 1.0);
    float factor = 1.0;
    if (dlen > 1e-4) {
        vec2 ndc = vClip.xy / vClip.w;               // fragment screen position, [-1, 1]
        float awayness = clamp(0.5 - 0.5 * dot(dir / dlen, ndc), 0.0, 1.0);  // 0 toward light, 1 away
        // Ramp from brighter-than-lit (toward the light) to darker (away). >1 pushes past target.
        float ramp = mix(1.0 + uGradBright, 1.0 - uGradStrength, awayness);
        factor = mix(1.0, ramp, turn);
    }
    float shade = lambert * factor;

    // shade is the lit amount: 0 -> ambient color, 1 -> light color, >1 over-bright (extrapolates
    // past the light color). Floored at 0 so the darkest a surface gets is the ambient color, not
    // black. The per-vertex (surface) color tints the result.
    vec3 incident = mix(uAmbientColor.rgb, uLightColor.rgb, max(shade, 0.0));
    vec3 rgb = vColor.rgb * incident;

    // Depth fog: linear ramp on eye-space depth (vClip.w = view-axis distance), blending the
    // shaded color toward uFogColor. uFogAmount caps the blend so distance can stay partly visible.
    float fog = clamp((vClip.w - uFogStart) / (uFogEnd - uFogStart), 0.0, 1.0) * uFogAmount;
    rgb = mix(rgb, uFogColor.rgb, fog);

    fragColor = vec4(rgb, vColor.a * uLightColor.a);
}
