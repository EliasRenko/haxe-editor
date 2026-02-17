package layers;

import Entity;

class Layer extends Entity {

    public var locked:Bool = false;
    
    public function new(name:String) {
        super(name);
    }
    
    public function getType():String {
        return "base";
    }
}
