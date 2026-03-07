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
    /** Default normalized pivot X for this entity type (0 = left, 0.5 = center, 1 = right). */
    var pivotX:Float;
    /** Default normalized pivot Y for this entity type (0 = top, 0.5 = center, 1 = bottom). */
    var pivotY:Float;
}