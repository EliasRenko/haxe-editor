package layers;

import display.ManagedTileBatch;
import Tileset;

class TilemapLayer extends Layer {

    public var tileset:Tileset;
    public var tileBatch:ManagedTileBatch;
    public var selectedTileRegion:Int = 0;
    
    // Grid-based tile storage index (faster lookups than iterating ManagedTileBatch)
    // Key format: "gridX_gridY" -> tileId in ManagedTileBatch
    public var tileGrid:Map<String, Int>;
    
    public function new(name:String, tileset:Tileset, tileBatch:ManagedTileBatch) {
        super(name);

        this.tileset = tileset;
        this.tileBatch = tileBatch;
        this.tileGrid = new Map<String, Int>();
    }
    
    override public function getType():String {
        return "tilemap";
    }
    
    override public function render(renderer:Dynamic, viewProjectionMatrix:Dynamic):Void {
        if (visible && tileBatch != null && tileBatch.visible) {
            // renderer.renderDisplayObject() automatically calls updateBuffers() and render()
            renderer.renderDisplayObject(tileBatch, viewProjectionMatrix);
        }
    }
    
    override public function cleanup(renderer:Dynamic):Void {
        if (tileBatch != null) {
            tileBatch.clear();
        }
        
        if (tileGrid != null) {
            tileGrid.clear();
        }
        
        super.cleanup(renderer);
    }
    
    public function getTileCount():Int {
        var count = 0;
        for (key in tileGrid.keys()) {
            count++;
        }
        return count;
    }
}
