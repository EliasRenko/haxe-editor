/**
 * Tileset structure containing texture and tile information
 * This is pure metadata - each layer creates its own batch instance
 */
typedef Tileset = {
    var name:String;              // Tileset name (e.g., "devTiles")
    var texturePath:String;       // Resource path (e.g., "textures/devTiles.tga")
    var textureId:Dynamic;        // OpenGL texture object from renderer.uploadTexture()
    var tileSize:Int;             // Size of each tile in pixels
    var tilesPerRow:Int;          // Number of tiles per row in atlas
    var tilesPerCol:Int;          // Number of tiles per column in atlas
}
