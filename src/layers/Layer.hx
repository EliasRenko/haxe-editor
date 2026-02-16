package layers;

class Layer {

    public var name:String;
    public var visible:Bool = true;
    public var locked:Bool = false;
    
    public function new(name:String) {
        this.name = name;
    }

    public function init():Void {
        
    }
    
    public function release():Void {
        
    }
    
    public function getType():String {
        return "base";
    }
    
    public function render(cameraMatrix:Dynamic, renderer:Dynamic):Void {

    }
}
