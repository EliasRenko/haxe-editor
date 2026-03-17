#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec4 uColor = vec4(1.0, 1.0, 1.0, 1.0);

void main() {
    vec4 texSample = texture(uTexture, TexCoord);
    // gohufont.tga: glyph pixels have A=255, background pixels have A=0
    FragColor = vec4(uColor.rgb, uColor.a * texSample.a);
}