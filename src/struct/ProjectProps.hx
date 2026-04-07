package struct;

@:native("ProjectProps")
@:struct
@:structAccess
extern class ProjectProps {
    var filePath:cpp.ConstCharStar;
    var projectId:cpp.ConstCharStar;
    var projectName:cpp.ConstCharStar;
    var projectDir:cpp.ConstCharStar;
    var defaultTileSizeX:Int;
    var defaultTileSizeY:Int;
}
