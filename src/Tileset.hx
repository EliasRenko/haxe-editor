import display.ManagedTileBatch;
import entity.DisplayEntity;

/**
 * Tileset structure containing texture and tile information
 */
typedef Tileset = {
    var name:String;              // Tileset name (e.g., "devTiles")
    var texturePath:String;       // Resource path (e.g., "textures/devTiles.tga")
    var textureId:Dynamic;        // OpenGL texture object from renderer.uploadTexture()
    var tileSize:Int;             // Size of each tile in pixels
    var tilesPerRow:Int;          // Number of tiles per row in atlas
    var tilesPerCol:Int;          // Number of tiles per column in atlas
    var tileRegions:Array<Int>;   // Array of region IDs in the tile batch
    var tileBatch:ManagedTileBatch; // Batch for rendering tiles from this tileset
    var entity:DisplayEntity;     // Entity for automatic rendering
}
