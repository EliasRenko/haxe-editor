#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec4 uColor = vec4(1.0, 1.0, 1.0, 1.0);

void main() {
    // Sample the texture (RGBA format with white RGB + alpha)
    vec4 texSample = texture(uTexture, TexCoord);
    
    // Use the alpha channel as the glyph mask
    // Output: colored glyph with proper transparency
    FragColor = vec4(uColor.rgb, uColor.a * texSample.a);
}