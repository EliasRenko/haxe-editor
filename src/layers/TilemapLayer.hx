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
    
    override public function render(renderer:Renderer, viewProjectionMatrix:Dynamic):Void {
        if (visible && tileBatch != null && tileBatch.visible) {
            
            tileBatch.uniforms.set("silhouette", false);
            renderer.renderDisplayObject(tileBatch, viewProjectionMatrix); // automatically calls updateBuffers() and render()

            if (silhouette) {
                tileBatch.uniforms.set("silhouette", silhouette);
                tileBatch.uniforms.set("silhouetteColor", [silhouetteColor.r, silhouetteColor.g, silhouetteColor.b, 0.4]); 

                renderer.renderDisplayObject(tileBatch, viewProjectionMatrix); // automatically calls updateBuffers() and render()
            }
            
            if (missingTileset) {
                // Render a red overlay to indicate missing tileset
                tileBatch.uniforms.set("silhouette", true);
                tileBatch.uniforms.set("silhouetteColor", [1, 0, 0, 0.5]); // Red with 50% opacity

                renderer.renderDisplayObject(tileBatch, viewProjectionMatrix); // automatically calls updateBuffers() and render()
            }
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
