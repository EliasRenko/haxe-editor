package layers;

class FolderLayer extends Layer {
    public var children:Array<Layer>;
    public var expanded:Bool = true; // For UI purposes
    
    public function new(name:String) {
        super(name);
        this.children = [];
    }
    
    override public function getType():String {
        return "folder";
    }
    
    override public function render(cameraMatrix:Dynamic, renderer:Dynamic):Void {
        if (visible && children != null) {
            for (child in children) {
                if (child != null) {
                    child.render(cameraMatrix, renderer);
                }
            }
        }
    }
    
    override public function release():Void {
        if (children != null) {
            for (child in children) {
                if (child != null) {
                    child.release();
                }
            }
            children = [];
        }
    }
    
    /**
     * Add a child layer to this folder
     */
    public function addLayer(layer:Layer):Void {
        if (children != null && layer != null) {
            children.push(layer);
        }
    }
    
    /**
     * Remove a child layer from this folder
     */
    public function removeLayer(layer:Layer):Bool {
        if (children != null && layer != null) {
            return children.remove(layer);
        }
        return false;
    }
    
    /**
     * Get the number of child layers
     */
    public function getChildCount():Int {
        return children != null ? children.length : 0;
    }
    
    /**
     * Get a child layer by index
     */
    public function getChildAt(index:Int):Layer {
        if (children != null && index >= 0 && index < children.length) {
            return children[index];
        }
        return null;
    }
    
    /**
     * Find a layer by name (recursive search)
     */
    public function findLayerByName(name:String):Layer {
        if (this.name == name) {
            return this;
        }
        
        if (children != null) {
            for (child in children) {
                if (child.name == name) {
                    return child;
                }
                
                // Recursive search in folder layers
                if (Std.isOfType(child, FolderLayer)) {
                    var folder:FolderLayer = cast child;
                    var found = folder.findLayerByName(name);
                    if (found != null) {
                        return found;
                    }
                }
            }
        }
        
        return null;
    }
}
