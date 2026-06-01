uniform sampler2DArray tex_array;
varying vec4 varying_color;
varying vec3 v_uvlayer;
void main() {
    gl_FragColor = varying_color * texture2DArray(tex_array, v_uvlayer);
}
