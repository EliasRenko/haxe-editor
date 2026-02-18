/**
 * EntityDefinition structure containing entity metadata
 * Defines reusable entity templates with their visual properties
 */
typedef EntityDefinition = {
    var name:String;              // Entity name (e.g., "player", "enemy")
    var width:Int;                // Entity width in pixels
    var height:Int;               // Entity height in pixels
    var tilesetName:String;       // Tileset used for this entity
    var regionX:Int;              // Atlas region X position
    var regionY:Int;              // Atlas region Y position
    var regionWidth:Int;          // Atlas region width
    var regionHeight:Int;         // Atlas region height
}
