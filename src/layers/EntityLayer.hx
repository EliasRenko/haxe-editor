package layers;

import display.ManagedTileBatch;
import Tileset;
import EntityDefinition;
import Lambda;
import Map; // for convenience


// helper used only by EntityLayer - combines tileset and its batch plus bookkeeping
class BatchEntry {
    public var tileset:Tileset;
    public var batch:ManagedTileBatch;
    public var entities:Map<Int, {name:String, tileId:Int, x:Float, y:Float}>;
    public var definedRegions:Map<String,Int>;
    public function new(tileset:Tileset, batch:ManagedTileBatch) {
        this.tileset = tileset;
        this.batch = batch;
        this.entities = new Map<Int, {name:String, tileId:Int, x:Float, y:Float}>();
        this.definedRegions = new Map<String,Int>();
    }
}

class EntityLayer extends Layer implements ITilesLayer {
    // list of all batches, one per tileset used by entities in this layer
    public var batches:Array<BatchEntry>;

    private var nextEntityId:Int = 0;
    
    public function new(name:String) {
        super(name);
        batches = [];
    }

    /**
     * helper to add an existing batch entry (used by callers that create a batch
     * ahead of time, e.g. when the layer is first created)
     */
    public function addBatch(tileset:Tileset, batch:ManagedTileBatch):Void {
        batches.push(new BatchEntry(tileset, batch));
    }
    
    override public function getType():String {
        return "entity";
    }
    
    override public function render(renderer:Dynamic, viewProjectionMatrix:Dynamic):Void {
        if (!visible) {
            trace("EntityLayer '" + id + "': not visible");
            return;
        }
        
        // draw each batch separately, in reverse order
        for (i in 0...batches.length) {
            var entry = batches[batches.length - 1 - i];
            var mb = entry.batch;
            if (mb == null) continue;
            if (!mb.visible) continue;
            // allow caller to control silhouette per-batch via uniforms if desired
            renderer.renderDisplayObject(mb, viewProjectionMatrix);
        }
    }
    
    override public function cleanup(renderer:Dynamic):Void {
        if (batches != null) {
            for (entry in batches) {
                if (entry.batch != null) entry.batch.clear();
                if (entry.entities != null) entry.entities.clear();
                if (entry.definedRegions != null) entry.definedRegions.clear();
            }
            batches = [];
        }
        super.cleanup(renderer);
    }
    
    /**
     * Place an entity defined by the given definition at world coordinates.
     * The definition contains the tileset name and atlas region info.
     * If the tileset isn't already represented, a new batch will be created
     * using the supplied renderer and program info.
     * Returns a unique entity ID or -1 on failure.
     */
    public function placeEntity(def:EntityDefinition, tileset:Tileset, x:Float, y:Float, renderer:Dynamic, programInfo:Dynamic):Int {
        // find or create batch entry for the provided tileset
        var entry:BatchEntry = null;
        for (e in batches) {
            if (e.tileset == tileset) {
                entry = e;
                break;
            }
        }
        if (entry == null) {
            // create a new batch for this tileset
            var mb = new ManagedTileBatch(programInfo, tileset.textureId);
            mb.init(renderer);
            entry = new BatchEntry(tileset, mb);
            batches.push(entry);
        }

        // determine region
        var regionId:Int = -1;
        if (entry.definedRegions.exists(def.name)) {
            regionId = entry.definedRegions.get(def.name);
        } else {
            regionId = entry.batch.defineRegion(def.regionX, def.regionY,
                                                def.regionWidth, def.regionHeight);
            if (regionId < 0) {
                trace("EntityLayer.placeEntity: defineRegion failed");
                return -1;
            }
            entry.definedRegions.set(def.name, regionId);
        }

        var tileId = entry.batch.addTile(x, y, def.width, def.height, regionId);
        if (tileId < 0) {
            trace("EntityLayer.placeEntity: addTile failed");
            return -1;
        }
        entry.batch.needsBufferUpdate = true;

        var entityId = nextEntityId++;
        entry.entities.set(entityId, {name:def.name, tileId:tileId, x:x, y:y});
        return entityId;
    }

    /**
     * Remove an entity by ID, searching all batches
     */
    public function removeEntity(entityId:Int):Bool {
        for (entry in batches) {
            if (entry.entities.exists(entityId)) {
                var ent = entry.entities.get(entityId);
                if (entry.batch != null) entry.batch.removeTile(ent.tileId);
                entry.entities.remove(entityId);
                return true;
            }
        }
        return false;
    }

    public function getEntityAt(worldX:Float, worldY:Float, tolerance:Float = 5.0):Int {
        for (entry in batches) {
            for (id in entry.entities.keys()) {
                var ent = entry.entities.get(id);
                if (Math.abs(ent.x - worldX) <= tolerance &&
                    Math.abs(ent.y - worldY) <= tolerance) {
                    return id;
                }
            }
        }
        return -1;
    }

    public function getEntityCount():Int {
        var total = 0;
        for (entry in batches) total += Lambda.count(entry.entities);
        return total;
    }

    public function clear():Void {
        for (entry in batches) {
            if (entry.batch != null) entry.batch.clear();
            if (entry.entities != null) entry.entities.clear();
            if (entry.definedRegions != null) entry.definedRegions.clear();
        }
        batches = [];
        nextEntityId = 0;
    }

    /** move specified batch earlier in the sequence */
    public function moveBatchUp(entry:BatchEntry):Bool {
        var idx = batches.indexOf(entry);
        if (idx <= 0) return false;
        var tmp = batches[idx-1]; batches[idx-1] = batches[idx]; batches[idx] = tmp;
        return true;
    }

    /** move specified batch later in the sequence */
    public function moveBatchDown(entry:BatchEntry):Bool {
        var idx = batches.indexOf(entry);
        if (idx < 0 || idx >= batches.length-1) return false;
        batches.splice(idx, 1);
        batches.insert(idx + 1, entry);
        return true;
    }

    /** relocate a batch to arbitrary index */
    public function moveBatchTo(entry:BatchEntry, newIndex:Int):Bool {
        var idx = batches.indexOf(entry);
        if (idx < 0) return false;
        if (newIndex < 0) newIndex = 0;
        if (newIndex > batches.length - 1) newIndex = batches.length - 1;
        if (newIndex == idx) return true;
        batches.splice(idx,1);
        batches.insert(newIndex, entry);
        return true;
    }

    public function redefineRegions(tileset:Tileset):Void {
        // We should not be able to change the tileset for an EntityLayer since each entity has its own tileset.
    }

    /** number of batch entries in this layer */
    public function getBatchCount():Int {
        return batches != null ? batches.length : 0;
    }

    /** return the batch entry at the given index or null */
    public function getBatchEntryAt(index:Int):BatchEntry {
        if (batches == null) return null;
        if (index < 0 || index >= batches.length) return null;
        return batches[index];
    }
}
