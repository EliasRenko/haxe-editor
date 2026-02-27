package struct;

@:native("EntityDataStruct")
@:struct
@:structAccess
extern class EntityDataStruct {
    var name:cpp.ConstCharStar;
    var width:Int;
    var height:Int;
    var tilesetName:cpp.ConstCharStar;
    var regionX:Int;
    var regionY:Int;
    var regionWidth:Int;
    var regionHeight:Int;
}