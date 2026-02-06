package display;

import cpp.Float32;
import cpp.UInt32;
import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import Texture;
import math.Matrix;
import data.Vertices;
import data.Indices;
import display.Tile;

/**
 * ManagedTileBatch - Extends TileBatch with tile management
 * 
 * Provides the full TileBatch API for adding, removing, and updating tiles,
 * while using the primitive TileBatch for efficient rendering.
 */
class ManagedTileBatch extends TileBatch {
    
    public static inline var MAX_TILES:Int = 1000; // Maximum tiles supported

    // Tile storage (restored API)
    private var tiles:Map<Int, Tile> = new Map(); // tileId -> TileInstance
    private var __nextTileId:Int = 1; // Auto-incrementing tile ID
    
    /**
     * Create a new ManagedTileBatch
     * @param programInfo Shader program for rendering
     * @param texture Atlas texture for all tiles
     */
    public function new(programInfo:ProgramInfo, texture:Texture) {
        super(programInfo, texture);
    }
    
    /**
     * Add a tile to the batch using a predefined atlas region
     * @param x World X position
     * @param y World Y position
     * @param width Tile width in world units
     * @param height Tile height in world units
     * @param regionId Atlas region ID (from defineRegion)
     * @return Tile ID for future reference
     */
    public function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
        if (!atlasRegions.exists(regionId)) {
            trace("ManagedTileBatch: Error - Region ID " + regionId + " does not exist!");
            return -1;
        }
        
        var tileId = __nextTileId++;
        
        var tile = new Tile(this);
        tile.x = x;
        tile.y = y;
        tile.width = width;
        tile.height = height;
        tile.regionId = regionId;
        
        tiles.set(tileId, tile);
        
        return tileId;
    }

    /**
     * Add existing Tile instance
     */
    public function addTileInstance(tile:Tile):Void {
        if (tile == null) return;
        var tileId = __nextTileId++;
        tiles.set(tileId, tile);
    }
    
    /**
     * Remove a tile from the batch
     * @param tileId Tile ID to remove
     * @return True if tile was found and removed
     */
    public function removeTile(tileId:Int):Bool {
        return tiles.remove(tileId);
    }
    
    /**
     * Remove tile instance
     */
    public function removeTileInstance(tile:Tile):Bool {
        for (tileId in tiles.keys()) {
            if (tiles.get(tileId) == tile) {
                tiles.remove(tileId);
                return true;
            }
        }
        return false;
    }
    
    /**
     * Update a tile's position
     * @param tileId Tile ID to update
     * @param x New world X position
     * @param y New world Y position
     * @return True if tile was found and updated
     */
    public function updateTilePosition(tileId:Int, x:Float, y:Float):Bool {
        if (tiles.exists(tileId)) {
            var tile = tiles.get(tileId);
            tile.x = x;
            tile.y = y;
            return true;
        }
        return false;
    }
    
    /**
     * Clear all tiles from the batch
     */
    public function clear():Void {
        tiles.clear();
    }
    
    /**
     * Get the number of tiles in the batch
     */
    public function getTileCount():Int {
        var count = 0;
        for (key in tiles.keys()) count++;
        return count;
    }
    
    /**
     * Check if a tile exists
     */
    public function hasTile(tileId:Int):Bool {
        return tiles.exists(tileId);
    }
    
    /**
     * Get tile instance (for reading properties)
     */
    public function getTile(tileId:Int):Tile {
        return tiles.get(tileId);
    }
    
    /**
     * Update buffers - build tile data from stored tiles and pass to base class
     */
    override public function updateBuffers(renderer:Renderer):Void {

        for (tile in tiles) {
            buildTile(tile);
        }
        
        // Call base class updateBuffers (which will use the set tile data)
        super.updateBuffers(renderer);
    }
}