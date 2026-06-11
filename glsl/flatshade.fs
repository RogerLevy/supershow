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
uniform float uGradCurve;     // ramp shaping: 1 = linear, <1 bends toward ambient (more dark), >1 toward lit
uniform float uFogStart;      // eye-space depth (vClip.w) where fog begins
uniform float uFogEnd;        // eye-space depth where fog reaches full strength
uniform vec4  uFogColor;      // fog / haze color (rgb; a unused)
uniform float uFogAmount;     // max fog strength: 0 = off, 1 = distant surfaces fully fogged

void main() {
    // Per-face normal straight from the geometry (no derivatives), and the world directional light.
    vec3 N = normalize(vNormal);                     // renormalize: soak up mat3(uModel) scale slack
    vec3 L = uLightDir;                              // already unit, already toward the light
    float lambert = 0.2 + 0.8 * max(0.0, dot(N, L)); // the directional light, world space, as before

    // Screen-space directional gradient, with AMOUNT and ANGLE deliberately separated:
    //   AMOUNT (how strongly it shows) = the face's obliqueness to the LIGHT alone, |Lplane| =
    //     sin(angle between N and L). Full when edge-on to the light (a top-lit building's walls),
    //     zero when the face points straight toward or away from it (roof, underside). No camera
    //     term, so the strength of the effect depends only on the light, never the viewpoint.
    //   ANGLE (which way it runs on screen) = the in-plane light direction projected to the screen,
    //     so it depends on the normal, the light AND the camera -- as intended.
    // The ramp is across screen position (ndc): one continuous screen-space gradient that each
    // polygon cuts out where it covers.
    vec3 Lplane = L - dot(L, N) * N;                 // light direction within the face plane
    float oblique = clamp(length(Lplane), 0.0, 1.0); // AMOUNT: sin(angle(N,L)); light-only, no camera
    vec2 dir = (mat3(uView) * Lplane).xy;            // ANGLE: in-plane light projected to the screen
    float dlen = length(dir);
    float factor = 1.0;
    if (dlen > 1e-4) {
        vec2 ndc = vClip.xy / vClip.w;               // fragment screen position, [-1, 1]
        float awayness = clamp(0.5 - 0.5 * dot(dir / dlen, ndc), 0.0, 1.0);  // 0 toward light, 1 away
        awayness = pow(awayness, uGradCurve);        // bend the ramp; endpoints (0,1) stay fixed
        // Ramp from brighter-than-lit (toward the light) to darker (away). Clamp the dark end at 0
        // (= ambient once multiplied through): a strength > 1 would otherwise drive the ramp
        // negative partway across the screen, and the max(shade,0) floor below flattens everything
        // past that point into a dead unlit band. Clamped, the ramp reaches its darkest exactly at
        // the away screen edge, so the gradient spans the whole screen.
        float ramp = mix(1.0 + uGradBright, max(0.0, 1.0 - uGradStrength), awayness);
        factor = mix(1.0, ramp, oblique);            // amount from light-obliqueness only
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
