package layers;

/**
 * Base layer class for the editor
 * Layers organize content in the map editor
 */
class Layer {
    public var name:String;
    public var visible:Bool = true;
    public var locked:Bool = false;
    
    public function new(name:String) {
        this.name = name;
    }
    
    /**
     * Get the type of this layer as a string
     * Override in subclasses
     */
    public function getType():String {
        return "base";
    }
    
    /**
     * Render this layer
     * Override in subclasses
     */
    public function render(cameraMatrix:Dynamic, renderer:Dynamic):Void {
        // Override in subclasses
    }
    
    /**
     * Release resources used by this layer
     * Override in subclasses
     */
    public function release():Void {
        // Override in subclasses
    }
}
