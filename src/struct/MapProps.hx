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
	var tileSizeX:Int;
	var tileSizeY:Int;
	var bgColor:Int;
	var gridColor:Int;
	var projectFilePath:cpp.ConstCharStar;
	var projectName:cpp.ConstCharStar;
}
