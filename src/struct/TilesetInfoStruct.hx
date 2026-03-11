package struct;

@:native("TilesetInfoStruct")
@:struct
@:structAccess
extern class TilesetInfoStruct {
    var name:cpp.ConstCharStar;
    var texturePath:cpp.ConstCharStar;
}