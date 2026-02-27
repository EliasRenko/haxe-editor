package struct;

@:native("TilesetInfoStruct")
@:struct
@:structAccess
extern class TilesetInfoStruct {
    var name:cpp.ConstCharStar;
    var texturePath:cpp.ConstCharStar;
    var tileSize:Int;
    var tilesPerRow:Int;
    var tilesPerCol:Int;
    var regionCount:Int;
}