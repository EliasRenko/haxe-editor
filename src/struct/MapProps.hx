package struct;

@:native("MapProps")
@:struct
@:structAccess
extern class MapProps {
	var idd:cpp.ConstCharStar;
	var name:cpp.ConstCharStar;
	var worldx:Int;
	var worldy:Int;
	var width:Int;
	var height:Int;
	var tileSize:Int;
	var bgColor:Int;
	var gridColor:Int;
}
