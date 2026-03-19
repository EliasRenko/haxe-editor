package;

@:structInit 
class EditorTexture {
    public var name:String;              // Tileset name (e.g., "devTiles")
    public var texturePath:String;       // Resource path (e.g., "textures/devTiles.tga")
    public var textureId:Texture;        // OpenGL texture object from renderer.uploadTexture()
}
