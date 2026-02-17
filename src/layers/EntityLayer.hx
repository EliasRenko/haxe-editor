package layers;

import entity.DisplayEntity;

/**
 * Entity layer that holds DisplayEntity objects
 */
class EntityLayer extends Layer {
    public var entities:Array<DisplayEntity>;
    
    public function new(name:String) {
        super(name);
        this.entities = [];
    }
    
    override public function getType():String {
        return "entity";
    }
    
    override public function render(renderer:Dynamic, viewProjectionMatrix:Dynamic):Void {
        if (visible && entities != null) {
            for (entity in entities) {
                if (entity != null && entity.displayObject != null && entity.displayObject.visible) {
                    entity.displayObject.render(viewProjectionMatrix);
                }
            }
        }
    }
    
    override public function cleanup(renderer:Dynamic):Void {
        if (entities != null) {
            // Note: We don't cleanup the entities themselves, just clear the array
            // The entities might be managed elsewhere
            entities = [];
        }
        
        super.cleanup(renderer);
    }
    
    /**
     * Add an entity to this layer
     */
    public function addEntity(entity:DisplayEntity):Void {
        if (entities != null && entity != null) {
            entities.push(entity);
        }
    }
    
    /**
     * Remove an entity from this layer
     */
    public function removeEntity(entity:DisplayEntity):Bool {
        if (entities != null && entity != null) {
            return entities.remove(entity);
        }
        return false;
    }
    
    /**
     * Get the number of entities in this layer
     */
    public function getEntityCount():Int {
        return entities != null ? entities.length : 0;
    }
    
    /**
     * Clear all entities from this layer
     */
    public function clear():Void {
        if (entities != null) {
            entities = [];
        }
    }
}
