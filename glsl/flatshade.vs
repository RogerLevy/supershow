#version 300 es

// Allegro binds these standard attributes by name when al_draw_prim runs.
in vec4 al_pos;
in vec4 al_color;
in vec4 al_user_attr_0;             // object-space face normal (filled by gen-normals)

uniform mat4 al_projview_matrix;   // proj * view * model, maintained by Allegro
uniform mat4 uModel;               // object -> world, set per model (3d pack's modelmtx)

flat out vec3 vNormal;             // world-space face normal -- flat: constant across the face
out vec4 vColor;                   // per-vertex (per-face) color
out vec4 vClip;                    // clip position; the FS uses xy/w as the screen (NDC) position
flat out vec2 vCenter;             // the object's screen-space center (NDC): the gradient's anchor
flat out float vCenterDepth;       // the object center's view-space depth (clip w): closeness to camera

void main() {
    // mat3(uModel) (no inverse-transpose) is exact for the meshes in use: uniform scale,
    // or axis-aligned normals under axial scale. General skewed non-uniform scale would
    // need the inverse-transpose.
    vNormal = normalize(mat3(uModel) * al_user_attr_0.xyz);
    vColor = al_color;
    gl_Position = al_projview_matrix * al_pos;
    vClip = gl_Position;
    // The object origin (object space 0,0,0) projected to clip then NDC: the rendered object's
    // screen-space center. Independent of al_pos, so it's the same for every vertex (flat).
    vec4 centerClip = al_projview_matrix * vec4(0.0, 0.0, 0.0, 1.0);
    vCenter = centerClip.xy / centerClip.w;
    vCenterDepth = centerClip.w;
}
