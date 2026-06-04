attribute vec4 al_pos;
attribute vec4 al_color;
attribute vec4 al_user_attr_0;
uniform mat4 al_projview_matrix;
varying vec4 varying_color;
varying vec3 v_uvlayer;
void main() {
    gl_Position = al_projview_matrix * al_pos;
    varying_color = al_color;
    v_uvlayer = vec3(al_user_attr_0.xy / 256.0, al_user_attr_0.z);
}
