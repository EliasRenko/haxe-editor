package layers;

import display.ManagedTileBatch;
import Tileset;

/**
 * Entity layer that holds entities as tiles in a batch
 * Similar to TilemapLayer but for entity placement
 */
class EntityLayer extends Layer {
    public var tileset:Tileset; // The tileset used for entity graphics
    public var entityBatch:ManagedTileBatch; // Batch containing all entity tiles
    
    // Entity storage: entityId -> {name: String, tileId: Int, x: Float, y: Float}
    public var entities:Map<Int, {name:String, tileId:Int, x:Float, y:Float}>;
    private var nextEntityId:Int = 0;
    private var nextRegionId:Int = 0; // Auto-incrementing region ID for entity atlas regions
    
    public function new(name:String, tileset:Tileset, entityBatch:ManagedTileBatch) {
        super(name);
        this.tileset = tileset;
        this.entityBatch = entityBatch;
        this.entities = new Map<Int, {name:String, tileId:Int, x:Float, y:Float}>();
    }
    
    override public function getType():String {
        return "entity";
    }
    
    override public function render(renderer:Dynamic, viewProjectionMatrix:Dynamic):Void {
        if (!visible) {
            trace("EntityLayer '" + id + "': not visible");
            return;
        }
        
        if (entityBatch == null) {
            trace("EntityLayer '" + id + "': entityBatch is null");
            return;
        }
        
        if (!entityBatch.visible) {
            trace("EntityLayer '" + id + "': entityBatch not visible");
            return;
        }
        
        trace("EntityLayer.render: batch has " + entityBatch.getTileCount() + " tiles, " + entityBatch.vertices.length + " vertices");
        
        // renderer.renderDisplayObject() automatically calls updateBuffers() and render()
        renderer.renderDisplayObject(entityBatch, viewProjectionMatrix);
    }
    
    override public function cleanup(renderer:Dynamic):Void {
        if (entityBatch != null) {
            entityBatch.clear();
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
        if (entityBatch == null) {
            trace("EntityLayer.addEntity: entityBatch is null!");
            return -1;
        }
        
        // Define a new region for this entity
        var regionId = entityBatch.defineRegion(atlasX, atlasY, atlasWidth, atlasHeight);
        trace("EntityLayer.addEntity: defined region " + regionId + " for atlas(" + atlasX + "," + atlasY + "," + atlasWidth + "," + atlasHeight + ")");
        
        if (regionId < 0) {
            trace("EntityLayer.addEntity: ERROR - defineRegion failed! Returned: " + regionId);
            return -1;
        }
        
        // Verify the region exists before adding tile
        if (!entityBatch.atlasRegions.exists(regionId)) {
            trace("EntityLayer.addEntity: ERROR - Region " + regionId + " does not exist in atlasRegions after defineRegion!");
            return -1;
        }
        
        // Add tile to batch
        var tileId = entityBatch.addTile(x, y, width, height, regionId);
        trace("EntityLayer.addEntity: added tile " + tileId + " at (" + x + "," + y + ") size(" + width + "," + height + ") regionId=" + regionId);
        
        if (tileId < 0) {
            trace("EntityLayer.addEntity: ERROR - addTile failed! Returned: " + tileId);
            return -1;
        }
        
        // Mark batch as needing buffer update
        entityBatch.needsBufferUpdate = true;
        
        // Store entity info
        var entityId = nextEntityId++;
        entities.set(entityId, {name: name, tileId: tileId, x: x, y: y});
        
        trace("EntityLayer.addEntity: created entity " + entityId + ", batch now has " + entityBatch.getTileCount() + " tiles");
        return entityId;
    }
    
    /**
     * Remove an entity by ID
     */
    public function removeEntity(entityId:Int):Bool {
        if (!entities.exists(entityId)) return false;
        
        var entity = entities.get(entityId);
        
        // Remove tile from batch
        if (entityBatch != null) {
            entityBatch.removeTile(entity.tileId);
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
        if (entityBatch != null) {
            entityBatch.clear();
        }
        if (entities != null) {
            entities.clear();
        }
        nextEntityId = 0;
    }
}
