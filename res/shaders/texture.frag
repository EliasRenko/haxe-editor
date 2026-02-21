#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform bool silhouette;         
uniform vec4 silhouetteColor;
const float checkerSize = 16.0; // Checker size in screen pixels

void main() {
    // Check if texture coordinates are out of bounds (negative or >1)
    bool outOfBounds = TexCoord.x < 0.0 || TexCoord.x > 1.0 || TexCoord.y < 0.0 || TexCoord.y > 1.0;
    
    if (outOfBounds) {
        // Render red checkerboard for out-of-bounds coordinates
        float cx = floor(gl_FragCoord.x / checkerSize);
        float cy = floor(gl_FragCoord.y / checkerSize);
        bool isEven = mod(cx + cy, 2.0) < 1.0;
        vec4 redColor = vec4(1.0, 0.0, 0.0, 1.0);
        vec4 darkRed = redColor * vec4(0.2, 0.2, 0.2, 1.0);
        FragColor = isEven ? redColor : darkRed;
    } else if (silhouette) {
        float cx = floor(gl_FragCoord.x / checkerSize);
        float cy = floor(gl_FragCoord.y / checkerSize);
        bool isEven = mod(cx + cy, 2.0) < 1.0;
        vec4 darkColor = silhouetteColor * vec4(0.2, 0.2, 0.2, 1.0); // 20% brightness
        FragColor = isEven ? silhouetteColor : darkColor;
    } else {
        FragColor = texture(uTexture, TexCoord);
    }
}