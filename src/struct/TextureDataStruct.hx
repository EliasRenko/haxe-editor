package struct;

@:native("TextureDataStruct")
@:struct
@:structAccess
extern class TextureDataStruct {
    var data:cpp.RawPointer<cpp.UInt8>;
    var width:Int;
    var height:Int;
    var bytesPerPixel:Int;
    var dataLength:Int;
    var transparent:Int;
}