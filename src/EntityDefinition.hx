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
    public var pivotX:Float = 0.0;     /** Default normalised pivot X (0 = left, 0.5 = centre, 1 = right). Applied when placing without an explicit override. */
    public var pivotY:Float = 0.0;     /** Default normalised pivot Y (0 = top, 0.5 = centre, 1 = bottom). Applied when placing without an explicit override. */
}
