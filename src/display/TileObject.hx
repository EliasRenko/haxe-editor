package display;

import GL;
import ProgramInfo;
import Renderer;
import Texture;
import data.Vertices;
import data.Indices;

/**
 * TileObject - A single tile display object
 * Used for entities that reference a region in a tileset
 * Much more efficient than creating a batch per entity
 */
class TileObject extends Transform {
    
    // Tile properties
    public var tileWidth:Float;
    public var tileHeight:Float;
    
    // Atlas region (in pixels)
    public var atlasX:Int;
    public var atlasY:Int;
    public var atlasWidth:Int;
    public var atlasHeight:Int;
    
    // Texture dimensions (for UV calculation)
    private var textureWidth:Int = 0;
    private var textureHeight:Int = 0;
    
    public function new(programInfo:ProgramInfo, texture:Texture, textureWidth:Int, textureHeight:Int) {
        // Create initial quad vertices (will be updated in render())
        var vertices:Vertices = [
            0.0, 0.0, 0.0, 0.0, 0.0,
            1.0, 0.0, 0.0, 1.0, 0.0,
            1.0, 1.0, 0.0, 1.0, 1.0,
            0.0, 1.0, 0.0, 0.0, 1.0
        ];
        
        var indices:Indices = [0, 1, 2, 2, 3, 0];
        
        super(programInfo, vertices, indices);
        
        setTexture(texture);
        this.textureWidth = textureWidth;
        this.textureHeight = textureHeight;
        this.depthTest = false;
        
        mode = GL.TRIANGLES;
        __verticesToRender = 4;
        __indicesToRender = 6;
    }
    
    /**
     * Set the atlas region for this tile
     */
    public function setRegion(atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Void {
        this.atlasX = atlasX;
        this.atlasY = atlasY;
        this.atlasWidth = atlasWidth;
        this.atlasHeight = atlasHeight;
        needsBufferUpdate = true;
    }
    
    /**
     * Set the size of this tile in world space
     */
    public function setSize(width:Float, height:Float):Void {
        this.tileWidth = width;
        this.tileHeight = height;
        needsBufferUpdate = true;
    }
    
    /**
     * Initialize OpenGL buffers
     */
    override public function init(renderer:Renderer):Void {
        super.init(renderer);
    }
    
    /**
     * Update vertex buffer with current position and atlas region
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!needsBufferUpdate) return;
        
        // Calculate UV coordinates
        var u0 = atlasX / textureWidth;
        var v0 = atlasY / textureHeight;
        var u1 = (atlasX + atlasWidth) / textureWidth;
        var v1 = (atlasY + atlasHeight) / textureHeight;
        
        // Create quad vertices (position + UV)
        // Format: x, y, z, u, v
        vertices = [
            // Top-left
            0.0, 0.0, 0.0, u0, v0,
            // Top-right
            tileWidth, 0.0, 0.0, u1, v0,
            // Bottom-right
            tileWidth, tileHeight, 0.0, u1, v1,
            // Bottom-left
            0.0, tileHeight, 0.0, u0, v1
        ];
        
        super.updateBuffers(renderer);
        needsBufferUpdate = false;
    }
    
    /**
     * Render this tile
     */
    override public function render(cameraMatrix:Dynamic):Void {
        if (!visible) return;
        
        // Update transform matrix
        updateTransform();
        
        // Let base class handle the rendering
        super.render(cameraMatrix);
    }
}
