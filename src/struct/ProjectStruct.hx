package struct;

@:native("ProjectStruct")
@:struct
@:structAccess
extern class ProjectStruct {
    var filePath:cpp.ConstCharStar;
    var projectId:cpp.ConstCharStar;
    var projectName:cpp.ConstCharStar;
    var projectDir:cpp.ConstCharStar;
    var defaultTileSizeX:Int;
    var defaultTileSizeY:Int;
}
