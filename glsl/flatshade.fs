#version 300 es
precision highp float;   // world coords reach a few thousand; highp keeps the derivatives clean

in vec3 vWorldPos;
in vec4 vColor;
out vec4 fragColor;

uniform vec3 uLightDir;   // direction the light travels, world space
uniform vec4 uBaseColor;  // global tint over the per-vertex color

void main() {
    // Face normal straight from the geometry: the screen-space derivatives of the world
    // position span the triangle's plane, so their cross product is its normal. No
    // per-vertex normals or normal matrix needed, and non-uniform scale can't distort it
    // -- it's rebuilt from the actually-transformed surface. (Swap dFdx/dFdy if inverted.)
    vec3 normal = normalize(cross(dFdx(vWorldPos), dFdy(vWorldPos)));

    // Invert light direction because the dot product expects a vector pointing away from the surface.
    vec3 invLightDir = -normalize(uLightDir);
    float diffuse = max(0.0, dot(normal, invLightDir));

    // Smooth Lambert over a flat ambient floor (so faces away from the light aren't pure black).
    float light = 0.2 + 0.8 * diffuse;

    vec3 rgb = vColor.rgb * uBaseColor.rgb * light;
    fragColor = vec4(rgb, vColor.a * uBaseColor.a);
}
