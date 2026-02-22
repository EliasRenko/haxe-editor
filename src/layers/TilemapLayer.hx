package layers;

import display.ManagedTileBatch;
import Tileset;

class TilemapLayer extends Layer implements ITilesLayer {

    public var tileset:Tileset;
    public var managedTileBatch:ManagedTileBatch;
    public var selectedTileRegion:Int = 0;
    
    // Grid-based tile storage index (faster lookups than iterating ManagedTileBatch)
    // Key format: "gridX_gridY" -> tileId in ManagedTileBatch
    public var tileGrid:Map<String, Int>;
    
    public function new(name:String, tileset:Tileset, managedTileBatch:ManagedTileBatch) {
        super(name);

        this.tileset = tileset;
        this.managedTileBatch = managedTileBatch;
        this.tileGrid = new Map<String, Int>();
    }
    
    override public function getType():String {
        return "tilemap";
    }
    
    override public function render(renderer:Renderer, viewProjectionMatrix:Dynamic):Void {
        if (visible && managedTileBatch != null && managedTileBatch.visible) {
            
            managedTileBatch.uniforms.set("silhouette", false);
            renderer.renderDisplayObject(managedTileBatch, viewProjectionMatrix); // automatically calls updateBuffers() and render()

            if (silhouette) {
                managedTileBatch.uniforms.set("silhouette", silhouette);
                managedTileBatch.uniforms.set("silhouetteColor", [silhouetteColor.r, silhouetteColor.g, silhouetteColor.b, 0.4]); 

                renderer.renderDisplayObject(managedTileBatch, viewProjectionMatrix); // automatically calls updateBuffers() and render()
            }
            
            if (missingTileset) {
                // Render a red overlay to indicate missing tileset
                managedTileBatch.uniforms.set("silhouette", true);
                managedTileBatch.uniforms.set("silhouetteColor", [1, 0, 0, 0.5]); // Red with 50% opacity

                renderer.renderDisplayObject(managedTileBatch, viewProjectionMatrix); // automatically calls updateBuffers() and render()
            }
        }
    }
    
    override public function cleanup(renderer:Dynamic):Void {
        if (managedTileBatch != null) {
            managedTileBatch.clear();
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

    public function redefineRegions(tileset:Tileset):Void {
        managedTileBatch.clearRegions();
        for (row in 0...tileset.tilesPerCol) {
            for (col in 0...tileset.tilesPerRow) {
                managedTileBatch.defineRegion(
                    col * tileset.tileSize,  // atlasX
                    row * tileset.tileSize,  // atlasY
                    tileset.tileSize,        // width
                    tileset.tileSize         // height
                );
            }
        }
    }
}
