package layers;

import display.ManagedTileBatch;
import Tileset;

/**
 * Entity layer that holds entities as tiles in a batch
 * Similar to TilemapLayer but for entity placement
 */
class EntityLayer extends Layer implements ITilesLayer {
    public var tileset:Tileset; // The tileset used for entity graphics
    public var managedTileBatch:ManagedTileBatch; // Alias for entityBatch to implement ITilesLayer
    public var entities:Map<Int, {name:String, tileId:Int, x:Float, y:Float}>;

    public var definedRegions:Map<String,Int>;

    private var nextEntityId:Int = 0;
    
    public function new(name:String, tileset:Tileset, managedTileBatch:ManagedTileBatch) {
        super(name);
        this.tileset = tileset;
        this.managedTileBatch = managedTileBatch;
        this.entities = new Map<Int, {name:String, tileId:Int, x:Float, y:Float}>();
        this.definedRegions = new Map<String,Int>();
    }
    
    override public function getType():String {
        return "entity";
    }
    
    override public function render(renderer:Dynamic, viewProjectionMatrix:Dynamic):Void {
        if (!visible) {
            trace("EntityLayer '" + id + "': not visible");
            return;
        }
        
        if (managedTileBatch == null) {
            trace("EntityLayer '" + id + "': managedTileBatch is null");
            return;
        }
        
        if (!managedTileBatch.visible) {
            return;
        }
        
        managedTileBatch.uniforms.set("silhouette", false);
        managedTileBatch.uniforms.set("silhouetteColor", [1.0, 0.8, 0.0, 0.4]); // Orange silhouette for debugging (can be toggled on/off with uniform)

        // renderer.renderDisplayObject() automatically calls updateBuffers() and render()
        renderer.renderDisplayObject(managedTileBatch, viewProjectionMatrix);
    }
    
    override public function cleanup(renderer:Dynamic):Void {
        if (managedTileBatch != null) {
            managedTileBatch.clear();
        }
        
        if (entities != null) {
            entities.clear();
        }
        
        super.cleanup(renderer);
    }
    
    /**
     * Add an entity at world position
     * Creates a new atlas region for this entity instance
     * Returns the entity ID
     */
    public function addEntity(name:String, x:Float, y:Float, width:Float, height:Float, atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Int {
        if (managedTileBatch == null) {
            trace("EntityLayer.addEntity: managedTileBatch is null!");
            return -1;
        }
        
        var regionId:Int = -1;

        // Check if region for this entity name already exists, otherwise define a new one
        if (definedRegions.exists(name)) {
            regionId = definedRegions.get(name);
        } else {
            regionId = managedTileBatch.defineRegion(atlasX, atlasY, atlasWidth, atlasHeight);
            if (regionId < 0) {
                trace("EntityLayer.addEntity: ERROR - defineRegion failed!");
                return -1;
            }
            definedRegions.set(name, regionId);
        }
        
        // Add tile to batch
        var tileId = managedTileBatch.addTile(x, y, width, height, regionId);
        if (tileId < 0) {
            trace("EntityLayer.addEntity: ERROR - addTile failed!");
            return -1;
        }
        
        // Mark batch as needing buffer update
        managedTileBatch.needsBufferUpdate = true;
        
        // Store entity info
        var entityId = nextEntityId++;
        entities.set(entityId, {name: name, tileId: tileId, x: x, y: y});
        
        return entityId;
    }
    
    /**
     * Remove an entity by ID
     */
    public function removeEntity(entityId:Int):Bool {
        if (!entities.exists(entityId)) return false;
        
        var entity = entities.get(entityId);
        
        // Remove tile from batch
        if (managedTileBatch != null) {
            managedTileBatch.removeTile(entity.tileId);
        }
        
        // Remove entity info
        entities.remove(entityId);
        
        return true;
    }
    
    /**
     * Get entity at world position (with tolerance)
     */
    public function getEntityAt(worldX:Float, worldY:Float, tolerance:Float = 5.0):Int {
        for (entityId in entities.keys()) {
            var entity = entities.get(entityId);
            if (Math.abs(entity.x - worldX) <= tolerance && 
                Math.abs(entity.y - worldY) <= tolerance) {
                return entityId;
            }
        }
        return -1;
    }
    
    /**
     * Get the number of entities in this layer
     */
    public function getEntityCount():Int {
        return entities != null ? Lambda.count(entities) : 0;
    }
    
    /**
     * Clear all entities from this layer
     */
    public function clear():Void {
        if (managedTileBatch != null) {
            managedTileBatch.clear();
        }
        if (entities != null) {
            entities.clear();
        }
        nextEntityId = 0;
    }

    public function redefineRegions(tileset:Tileset):Void {
        // We should not be able to change the tileset for an EntityLayer since each entity has its own tileset.
    }
}
