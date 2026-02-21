package layers;

import Entity;
import utils.Color;

class Layer extends Entity {

    public var locked:Bool = false;
    public var silhouette:Bool = false;
    public var silhouetteColor:Color = new Color(0xFFFFFF); // Default white silhouette
    public var missingTileset:Bool = false;
    
    public function new(name:String) {
        super(name);
    }
    
    public function getType():String {
        return "base";
    }
}
