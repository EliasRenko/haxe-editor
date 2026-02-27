package manager;
import Tileset;

class TilesetManager {

    public var tilesets:Map<String, Tileset>;
    public var currentTilesetName:String = "devTiles"; // Currently active tileset
    private var tileSize:Int = 32; // Size of each tile in pixels
    
    public function new() {
        this.tilesets = new Map<String, Tileset>();
    }

    // public function setActiveTileRegion(regionId:Int):Void {
    //     // C# sends 0-based indices, but Haxe region IDs start from 1
    //     selectedTileRegion = regionId + 1;
    //     trace("Selected tile region: " + selectedTileRegion + " (from C# index: " + regionId + ")");
    // }

    public function exists(tilesetName:String):Bool {
        return tilesets.exists(tilesetName);
    }

    public function getTilesetInfo(tilesetName:String):Tileset {
        var tileset:Tileset = tilesets.get(tilesetName);
        if (tileset == null) {
            return null;
        }
        
        return tileset;
    }

    public function getTilesetInfoAt(index:Int):Tileset {
        var tilesetName = getTilesetNameAt(index);
        if (tilesetName == "") {
            return null;
        }
        return getTilesetInfo(tilesetName);
    }

    /**
     * Get the count of loaded tilesets
     * @return Number of tilesets
     */
    public function getTilesetCount():Int {
        var count = 0;
        for (_ in tilesets.keys()) {
            count++;
        }
        return count;
    }
    
    /**
     * Get tileset name at specific index
     * @param index Index of the tileset (0-based)
     * @return Tileset name or empty string if index out of bounds
     */
    public function getTilesetNameAt(index:Int):String {
        if (index < 0) return "";
        
        var i = 0;
        for (name in tilesets.keys()) {
            if (i == index) {
                return name;
            }
            i++;
        }
        return ""; // Index out of bounds
    }

    /**
     * Set the current active tileset for drawing context
     * This updates the tile regions and tile size used for drawing operations
     * Note: This is called automatically when setting an active TilemapLayer
     * @param tilesetName Name of the tileset to make active
     * @return True if tileset was found and set, false otherwise
     */
    public function setActiveTileset(tilesetName:String):Bool {
        var tileset = tilesets.get(tilesetName);
        if (tileset == null) {
            trace("Tileset not found: " + tilesetName);
            return false;
        }
        
        // Update current tileset drawing context
        currentTilesetName = tilesetName;
        tileSize = tileset.tileSize;
        
        //app.logDebug(LogCategory.APP,"Active tileset context set to: " + tilesetName);
        return true;
    }

    public function deleteTileset(tilesetName:String):Bool {
        var tileset = tilesets.get(tilesetName);
        if (tileset == null) {
            //app.logDebug(LogCategory.APP,"Tileset not found: " + tilesetName);
            return false;
        }
        
        // Remove from tilesets collection
        tilesets.remove(tilesetName);
        
        // If this was the current tileset, clear the references
        if (tilesetName == currentTilesetName) {
            currentTilesetName = "";
            trace("Warning: Deleted the current active tileset. You may need to set a new active tileset.");
        }
        
        trace("Deleted tileset: " + tilesetName);
        return true;
    }
    
    public function setTileset(tileTexture:Texture, tilesetName:String, texturePath:String, tileSize:Int):Void {
        
        
        // Calculate atlas dimensions
        var tilesPerRow = Std.int(tileTexture.width / tileSize);
        var tilesPerCol = Std.int(tileTexture.height / tileSize);
        
        // Create tileset metadata structure (no batch - layers create their own)
        var tileset:Tileset = {
            name: tilesetName,
            texturePath: texturePath,
            textureId: tileTexture,
            tileSize: tileSize,
            tilesPerRow: tilesPerRow,
            tilesPerCol: tilesPerCol
        };
        
        // Store in collection
        tilesets.set(tilesetName, tileset);
        
        // Update current tileset references (for backward compatibility)
        if (tilesetName == currentTilesetName) {
            currentTilesetName = tilesetName;
            this.tileSize = tileSize;
        }
        
        trace("Loaded tileset: " + tilesetName + " (" + tilesPerRow + "x" + tilesPerCol + " tiles)");
    }
}