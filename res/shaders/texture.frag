#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform bool silhouette;         
uniform vec4 silhouetteColor;

void main() {
    if (silhouette) {
        float cx = floor(TexCoord.x * 8);
        float cy = floor(TexCoord.y * 8);
        bool isEven = mod(cx + cy, 2.0) < 1.0;
        vec4 darkColor = silhouetteColor * vec4(0.2, 0.2, 0.2, 1.0); // 20% brightness
        FragColor = isEven ? silhouetteColor : darkColor;
    } else {
        FragColor = texture(uTexture, TexCoord);
    }
}