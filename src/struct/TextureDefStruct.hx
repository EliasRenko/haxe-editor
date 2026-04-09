package struct;

@:native("TextureDefStruct")
@:struct
@:structAccess
extern class TextureDefStruct {
    var name:cpp.ConstCharStar;
    var texturePath:cpp.ConstCharStar;
}