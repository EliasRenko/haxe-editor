package;

@:structInit 
class Tileset {
    public var name:String;              // Tileset name (e.g., "devTiles")
    public var texturePath:String;       // Resource path (e.g., "textures/devTiles.tga")
    public var textureId:Texture;        // OpenGL texture object from renderer.uploadTexture()
    public var tileSize:Int;             // Size of each tile in pixels
    public var tilesPerRow:Int;          // Number of tiles per row in atlas
    public var tilesPerCol:Int;          // Number of tiles per column in atlas
}
