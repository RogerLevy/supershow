#version 300 es

// Allegro binds these standard attributes by name when al_draw_prim runs.
in vec4 al_pos;
in vec4 al_color;

uniform mat4 al_projview_matrix;   // proj * view * model, maintained by Allegro
uniform mat4 uModel;               // object -> world, set per model (3d pack's modelmat)

out vec3 vWorldPos;                // world position; the FS derives the face normal from it
out vec4 vColor;                   // per-vertex (per-face) color

void main() {
    vWorldPos = (uModel * al_pos).xyz;
    vColor = al_color;
    gl_Position = al_projview_matrix * al_pos;
}
