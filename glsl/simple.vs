varying vec2 varying_texcoord;
void main(void)
{
    varying_texcoord = gl_MultiTexCoord0.xy;
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}