#version 330 core

in vec2 fragPos;
out vec4 FragColor;

uniform float uGridSize;
uniform float uSubGridSize;
uniform vec3 uGridColor;
uniform vec3 uBackgroundColor;
uniform float uFadeDistance;

float grid(vec2 pos, float gridSize) {
    // Calculate grid lines
    vec2 grid = abs(fract(pos / gridSize - 0.5) - 0.5) / fwidth(pos / gridSize);
    float line = min(grid.x, grid.y);
    
    // Convert to line thickness
    return 1.0 - min(line, 1.0);
}

void main() {
    // Calculate main grid
    float mainGrid = grid(fragPos, uGridSize);
    
    // Calculate sub grid (smaller divisions)
    float subGrid = grid(fragPos, uSubGridSize) * 0.3;
    
    // Combine grids
    float gridValue = max(mainGrid, subGrid);
    
    // Calculate distance-based fade
    float dist = length(fragPos);
    float fade = 1.0 - smoothstep(uFadeDistance * 0.5, uFadeDistance, dist);
    
    // Apply fade to grid
    gridValue *= fade;
    
    // Mix grid color with background
    vec3 color = mix(uBackgroundColor, uGridColor, gridValue);
    
    // Output with full opacity
    FragColor = vec4(color, 1.0);
}
