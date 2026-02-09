package display;

import data.Indices;
import data.Vertices;
import GL;
import ProgramInfo;
import Renderer;
import math.Matrix;

/**
 * Grid - An infinite grid display object rendered using GLSL shaders (FIXED VERSION)
 * 
 * FIX: Removed UV coordinates - grid shader only needs position (x,y,z)
 * The shader calculates grid pattern from world position, not texture coords
 */
class Grid extends Transform {

    // Grid properties
    public var gridSize:Float = 100.0;
    public var subGridSize:Float = 25.0;
    public var gridColor:Array<Float> = [0.3, 0.3, 0.3]; // RGB
    public var backgroundColor:Array<Float> = [0.0, 0.0, 0.0]; // RGB
    public var fadeDistance:Float = 2000.0;
    
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
    public function new(programInfo:ProgramInfo, size:Float = 10000.0) {
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

        super(programInfo, vertices, indices);

        // Set OpenGL properties
        mode = GL.TRIANGLES;
        __verticesToRender = 4;
        __indicesToRender = 6;

        // Grid typically renders behind other objects
        depthTest = true;
        depthWrite = false; // Don't write to depth buffer so other objects render on top
    }

    /**
     * Update grid uniforms before rendering
     */
    override public function render(cameraMatrix:Matrix):Void {
        if (!visible) return;

        // Set uniforms for the grid shader
        uniforms.set("uGridSize", gridSize);
        uniforms.set("uSubGridSize", subGridSize);
        uniforms.set("uGridColor", gridColor);
        uniforms.set("uBackgroundColor", backgroundColor);
        uniforms.set("uFadeDistance", fadeDistance);
        
        // Set bounds uniforms
        uniforms.set("uEnableBounds", enableBounds ? 1 : 0);
        uniforms.set("uBoundsMin", [boundsMinX, boundsMinY]);
        uniforms.set("uBoundsMax", [boundsMaxX, boundsMaxY]);

        // Call parent render - it will handle updateTransform and uMatrix
        super.render(cameraMatrix);
    }

    /**
     * Set the grid color
     * @param r Red component (0-1)
     * @param g Green component (0-1)
     * @param b Blue component (0-1)
     */
    public function setGridColor(r:Float, g:Float, b:Float):Void {
        gridColor = [r, g, b];
    }

    /**
     * Set the background color
     * @param r Red component (0-1)
     * @param g Green component (0-1)
     * @param b Blue component (0-1)
     */
    public function setBackgroundColor(r:Float, g:Float, b:Float):Void {
        backgroundColor = [r, g, b];
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
}
