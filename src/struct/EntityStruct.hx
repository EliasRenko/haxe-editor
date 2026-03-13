package struct;

@:native("EntityStruct")
@:struct
@:structAccess
extern class EntityStruct {
    var uid:cpp.ConstCharStar;
    var name:cpp.ConstCharStar;
    var width:Int;
    var height:Int;
    var x:Int;
    var y:Int;
}
