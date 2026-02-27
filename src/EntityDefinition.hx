@:structInit
class EntityDefinition {
    public var name:String;              // Entity name (e.g., "player", "enemy")
    public var width:Int;                // Entity width in pixels
    public var height:Int;               // Entity height in pixels
    public var tilesetName:String;       // Tileset used for this entity
    public var regionX:Int;              // Atlas region X position
    public var regionY:Int;              // Atlas region Y position
    public var regionWidth:Int;          // Atlas region width
    public var regionHeight:Int;         // Atlas region height
    public var definedRegionId: Int; // Atlas region ID for placeholder graphic (used when actual region is not yet created)
}
