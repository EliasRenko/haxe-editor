package struct;

@:native("LayerStruct")
@:struct
@:structAccess
extern class LayerStruct {
    var name:cpp.ConstCharStar;
    var type:Int; // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
    var tilesetName:cpp.ConstCharStar;
    var tileSize:Int;            // For TilemapLayer only (0 for others)
    var visible:Int;             // 0 = hidden, 1 = visible
    var silhouette:Bool;          // 0 = no silhouette, 1 = silhouette enabled
    var silhouetteColor:Int;  // RGBA color
}