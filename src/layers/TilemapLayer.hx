package layers;

import display.ManagedTileBatch;
import entity.DisplayEntity;
import Tileset;

/**
 * Tilemap layer that holds tiles using a specific tileset
 */
class TilemapLayer extends Layer {
    public var tilesetName:String;
    public var tileset:Tileset;
    public var tileBatch:ManagedTileBatch;
    public var entity:DisplayEntity;
    
    // Grid-based tile storage index (faster lookups than iterating ManagedTileBatch)
    // Key format: "gridX_gridY" -> tileId in ManagedTileBatch
    public var tileGrid:Map<String, Int>;
    
    public function new(name:String, tileset:Tileset, tileBatch:ManagedTileBatch, entity:DisplayEntity) {
        super(name);
        this.tilesetName = tileset.name;
        this.tileset = tileset;
        this.tileBatch = tileBatch;
        this.entity = entity;
        this.tileGrid = new Map<String, Int>();
    }
    
    override public function getType():String {
        return "tilemap";
    }
    
    override public function render(cameraMatrix:Dynamic, renderer:Dynamic):Void {
        if (visible && tileBatch != null && tileBatch.visible) {
            // Update buffers if needed
            if (tileBatch.needsBufferUpdate) {
                tileBatch.updateBuffers(renderer);
            }
            tileBatch.render(cameraMatrix);
        }
    }
    
    override public function release():Void {
        if (tileBatch != null) {
            tileBatch.clear();
        }
        if (tileGrid != null) {
            tileGrid.clear();
        }
    }
    
    /**
     * Get the number of tiles in this layer
     */
    public function getTileCount():Int {
        var count = 0;
        for (key in tileGrid.keys()) {
            count++;
        }
        return count;
    }
    
    /**
     * Clear all tiles from this layer
     */
    public function clear():Void {
        if (tileBatch != null) {
            tileBatch.clear();
        }
        if (tileGrid != null) {
            tileGrid.clear();
        }
    }
}
