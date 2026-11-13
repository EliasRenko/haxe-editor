package display;

import shaders.GridShader;
import data.Shader;
import utils.Color;
import data.Indices;
import data.Vertices;
import GL;
import Renderer;
import math.Matrix;

/**
 * Grid - An infinite grid display object rendered using GLSL shaders (FIXED VERSION)
 *
 * FIX: Removed UV coordinates - grid shader only needs position (x,y,z)
 * The shader calculates grid pattern from world position, not texture coords
 */
class Grid extends DisplayObject {
    public var gridSizeX:Float = 100.0;
    public var gridSizeY:Float = 100.0;
    public var subGridSizeX:Float = 25.0;
    public var subGridSizeY:Float = 25.0;
    //public var gridColor:Array<Float> = [0.3, 0.3, 0.3]; // RGB
    //public var backgroundColor:Array<Float> = [0.0, 0.0, 0.0]; // RGB
    public var fadeDistance:Float = 2000.0;
    public var gridColor:Color = new Color(0xFF1F7EDD);
    public var backgroundColor:Color = new Color(0x0D0D1AFF);
    
    // Bounds clipping (optional)
    public var enableBounds:Bool = false;
    public var boundsMinX:Float = 0.0;
    public var boundsMinY:Float = 0.0;
    public var boundsMaxX:Float = 1000.0;
    public var boundsMaxY:Float = 1000.0;

    /**
     * Create a new Grid display object
     * @param programInfo Shader program (should use grid.vert and grid.frag)
     * @param size Size of the grid quad (should be large enough to cover visible area)
     */
    public function new(renderer:Renderer, size:Float = 10000.0) {
        var halfSize = size / 2.0;

        // Create a large quad to render the grid on
        // Format: x, y, z (3 floats per vertex - NO UV COORDS)
        var vertices:Vertices = [
            // Top-left
            -halfSize, -halfSize, 0.0,
            // Top-right
            halfSize,  -halfSize, 0.0,
            // Bottom-right
            halfSize,  halfSize,  0.0,
            // Bottom-left
            -halfSize, halfSize,  0.0
        ];

        var indices:Indices = [0, 1, 2, 0, 2, 3]; // Two triangles to make a quad

        super(renderer, vertices, indices);

        // Set OpenGL properties
        mode = GL.TRIANGLES;

        // Grid typically renders behind other objects
        //depthTest = true;
        //depthWrite = false; // Don't write to depth buffer so other objects render on top

        // ---
    }

    /**
     * Update grid uniforms before rendering
     */
    public function render(renderer:Renderer):Void {
        if (!visible) return;

        // Set uniforms for the grid shader
        shader.setUniform("uGridSize", [gridSizeX, gridSizeY]);
        shader.setUniform("uSubGridSize", [subGridSizeX, subGridSizeY]);
        shader.setUniform("uGridColor", [gridColor.r, gridColor.g, gridColor.b]); // Color stores normalized RGB, shader expects vec3
        shader.setUniform("uBackgroundColor", [backgroundColor.r, backgroundColor.g, backgroundColor.b]); // Color stores normalized RGB, shader expects vec3
        shader.setUniform("uFadeDistance", fadeDistance);
        
        // Set bounds uniforms
        shader.setUniform("uEnableBounds", enableBounds ? 1 : 0);
        shader.setUniform("uBoundsMin", [boundsMinX, boundsMinY]);
        shader.setUniform("uBoundsMax", [boundsMaxX, boundsMaxY]);

        
        
        //renderElements(renderer);
    }
    
    /**
     * Set the bounds for grid clipping
     * @param minX Minimum X coordinate
     * @param minY Minimum Y coordinate
     * @param maxX Maximum X coordinate
     * @param maxY Maximum Y coordinate
     */
    public function setBounds(minX:Float, minY:Float, maxX:Float, maxY:Float):Void {
        boundsMinX = minX;
        boundsMinY = minY;
        boundsMaxX = maxX;
        boundsMaxY = maxY;
        enableBounds = true;
    }
    
    /**
     * Disable bounds clipping (grid will be infinite again)
     */
    public function clearBounds():Void {
        enableBounds = false;
    }

    private function assignShader():Shader {
        
        return new GridShader();
    }
}
