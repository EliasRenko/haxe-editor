package layers;

import display.ManagedTileBatch;
import display.LineBatch;
import Tileset;
import EntityDefinition;
import Lambda;
import Map;
import utils.EntityQuadtree;
import utils.EntityQuadtree.EntityBounds;

typedef Entity = {
    name:String,
    tileId:Int,
    x:Float,
    y:Float,
    width:Float,
    height:Float,
    /** Normalized pivot X (0 = left edge, 0.5 = center, 1 = right edge). x/y is the world position of this pivot point. */
    pivotX:Float,
    /** Normalized pivot Y (0 = top edge, 0.5 = center, 1 = bottom edge). x/y is the world position of this pivot point. */
    pivotY:Float
}

// helper used only by EntityLayer - combines tileset and its batch plus bookkeeping
class BatchEntry {
    public var tileset:Tileset;
    public var batch:ManagedTileBatch;
    public var entities:Map<Int, Entity>;
    public var definedRegions:Map<String,Int>;
    public function new(tileset:Tileset, batch:ManagedTileBatch) {
        this.tileset = tileset;
        this.batch = batch;
        this.entities = new Map<Int, Entity>();
        this.definedRegions = new Map<String,Int>();
    }
}

class EntityLayer extends Layer implements ITilesLayer {
    // list of all batches, one per tileset used by entities in this layer
    public var batches:Array<BatchEntry>;

    private var nextEntityId:Int = 0;

    /**
     * Spatial quadtree for broad-phase entity picking and collision queries.
     * Call setWorldBounds() to configure the root region before placing entities.
     */
    public var quadtree:EntityQuadtree;

    // World bounds used when rebuilding the quadtree
    private var _qtX:Float = 0;
    private var _qtY:Float = 0;
    private var _qtW:Float = 4096;
    private var _qtH:Float = 4096;

    public function new(name:String) {
        super(name);
        batches   = [];
        quadtree  = new EntityQuadtree(_qtX, _qtY, _qtW, _qtH);
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
            return;
        }
        
        // draw each batch separately, in reverse order
        for (i in 0...batches.length) {
            var entry = batches[batches.length - 1 - i];
            var mb = entry.batch;
            if (mb == null) continue;
            if (!mb.visible) continue;

            // Always reset silhouette to false first — GLSL uniforms are program-wide and
            // persist across draw calls, so a previous TilemapLayer that rendered with
            // silhouette=true would otherwise bleed into entity rendering.
            mb.uniforms.set("silhouette", false);

            renderer.renderDisplayObject(mb, viewProjectionMatrix);

            if (silhouette) {
                mb.uniforms.set("silhouette", true);
                mb.uniforms.set("silhouetteColor", [silhouetteColor.r, silhouetteColor.g, silhouetteColor.b, 0.4]);
                renderer.renderDisplayObject(mb, viewProjectionMatrix);
            }

            if (missingTileset) {
                mb.uniforms.set("silhouette", true);
                mb.uniforms.set("silhouetteColor", [1.0, 0.0, 0.0, 0.5]);
                renderer.renderDisplayObject(mb, viewProjectionMatrix);
            }
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
        if (quadtree != null) quadtree.clear();
        super.cleanup(renderer);
    }
    
    /**
     * Place an entity defined by the given definition at world coordinates.
     * The definition contains the tileset name and atlas region info.
     * If the tileset isn't already represented, a new batch will be created
     * using the supplied renderer and program info.
     * Returns a unique entity ID or -1 on failure.
     */
    /**
     * pivotX / pivotY are normalised (0–1).
     * (0, 0) = top-left   (0.5, 0.5) = centre   (1, 1) = bottom-right
     * x / y always refer to the world position of the pivot point on the tile.
     *
     * When pivotX / pivotY are omitted (or Math.NaN), the entity definition's
     * own default pivot (def.pivotX / def.pivotY) is used instead.
     */
    public function placeEntity(def:EntityDefinition, tileset:Tileset, x:Float, y:Float, renderer:Dynamic, programInfo:Dynamic, ?pivotX:Null<Float>, ?pivotY:Null<Float>):Int {
        // Resolve pivot: explicit override > definition default
        var px:Float = (pivotX != null) ? pivotX : def.pivotX;
        var py:Float = (pivotY != null) ? pivotY : def.pivotY;
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

        // Actual top-left render position is offset from the pivot world position
        var renderX = x - px * def.width;
        var renderY = y - py * def.height;

        var tileId = entry.batch.addTile(renderX, renderY, def.width, def.height, regionId);
        if (tileId < 0) {
            trace("EntityLayer.placeEntity: addTile failed");
            return -1;
        }
        entry.batch.needsBufferUpdate = true;

        var entityId = nextEntityId++;
        entry.entities.set(entityId, {name:def.name, tileId:tileId, x:x, y:y, width:def.width, height:def.height, pivotX:px, pivotY:py});

        // Insert into the spatial quadtree for future queries (quadtree uses center coords)
        // Center = pivot world pos + offset from pivot to center
        var cx = x + (0.5 - px) * def.width;
        var cy = y + (0.5 - py) * def.height;
        if (quadtree != null) quadtree.insert(entityId, cx, cy, def.width, def.height);

        return entityId;
    }

    /**
     * Propagate an updated EntityDefinition to every placed entity of that type.
     * Re-registers the atlas region with the new pixel coordinates, then patches
     * each matching tile's position, size, and regionId in-place.
     * Call this after updating the definition in EntityManager (via editEntityDef).
     *
     * @param def The already-updated definition object.
     */
    public function applyDefinitionUpdate(def:EntityDefinition):Void {
        var changed = false;
        for (entry in batches) {
            // Skip batches that have no entities of this type
            var hasAny = false;
            for (ent in entry.entities) {
                if (ent.name == def.name) { hasAny = true; break; }
            }
            if (!hasAny) continue;

            syncRegion(entry, def);

            for (id in entry.entities.keys()) {
                var ent = entry.entities.get(id);
                if (ent.name != def.name) continue;

                ent.width  = def.width;
                ent.height = def.height;
                ent.pivotX = def.pivotX;
                ent.pivotY = def.pivotY;

                var renderX = ent.x - def.pivotX * def.width;
                var renderY = ent.y - def.pivotY * def.height;

                var tile = entry.batch.getTile(ent.tileId);
                if (tile != null) {
                    tile.x      = renderX;
                    tile.y      = renderY;
                    tile.width  = def.width;
                    tile.height = def.height;
                }
            }
            entry.batch.needsBufferUpdate = true;
            changed = true;
        }
        if (changed) rebuildQuadtree();
    }

    /**
     * Ensure the atlas region for `def` in `entry` is up-to-date.
     *
     * - If the region has never been registered, register it now.
     * - If it exists but the pixel rect changed, patch the UV in-place via updateRegion.
     * - If updateRegion reports the slot is missing, create a fresh region and
     *   re-point every matching tile to the new ID.
     * - Skips region work when regionWidth/Height are 0 (partially-filled struct).
     */
    private function syncRegion(entry:BatchEntry, def:EntityDefinition):Void {
        if (def.regionWidth <= 0 || def.regionHeight <= 0) return;

        var regionId = entry.definedRegions.get(def.name);

        if (regionId == null) {
            // First time this entity type appears in this batch — register fresh.
            regionId = entry.batch.defineRegion(
                def.regionX, def.regionY, def.regionWidth, def.regionHeight);
            entry.definedRegions.set(def.name, regionId);
            return;
        }

        // Check whether the pixel rect actually changed before touching the GPU data.
        var existing = entry.batch.getRegion(regionId);
        var changed = (existing == null)
            || existing.x != def.regionX     || existing.y != def.regionY
            || existing.width != def.regionWidth || existing.height != def.regionHeight;

        if (!changed) return;

        if (entry.batch.updateRegion(regionId,
                def.regionX, def.regionY, def.regionWidth, def.regionHeight)) return;

        // updateRegion returned false — the slot was somehow lost.
        // Create a new region and re-point every matching tile to it.
        var newId = entry.batch.defineRegion(
            def.regionX, def.regionY, def.regionWidth, def.regionHeight);
        entry.definedRegions.set(def.name, newId);
        for (id in entry.entities.keys()) {
            var ent = entry.entities.get(id);
            if (ent.name != def.name) continue;
            var t = entry.batch.getTile(ent.tileId);
            if (t != null) t.regionId = newId;
        }
    }

    /**
     * Remove all placed entities associated with the given definition name across all batches.
     * Cleans up tiles and de-registers the atlas region for that definition.
     * Returns the number of entities removed.
     */
    public function removeEntitiesByDefName(defName:String):Int {
        var count = 0;
        var batchesToRemove:Array<BatchEntry> = [];
        for (entry in batches) {
            var idsToRemove:Array<Int> = [];
            for (id in entry.entities.keys()) {
                if (entry.entities.get(id).name == defName) idsToRemove.push(id);
            }
            for (id in idsToRemove) {
                var ent = entry.entities.get(id);
                if (entry.batch != null) entry.batch.removeTile(ent.tileId);
                entry.entities.remove(id);
                count++;
            }
            // Clean up the cached region ID so it won't be reused if the definition is recreated later
            entry.definedRegions.remove(defName);
            // If this batch is now empty, schedule it for removal
            if (!entry.entities.keys().hasNext()) {
                if (entry.batch != null) entry.batch.clear();
                batchesToRemove.push(entry);
            }
        }
        for (entry in batchesToRemove) batches.remove(entry);
        if (count > 0) rebuildQuadtree();
        return count;
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
                // If this was the last entity in the batch, remove the batch entirely
                if (!entry.entities.keys().hasNext()) {
                    if (entry.batch != null) entry.batch.clear();
                    batches.remove(entry);
                }
                // Quadtree does not support single-node removal — rebuild from remaining data
                rebuildQuadtree();
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
        if (quadtree != null) quadtree.clear();
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

    // -----------------------------------------------------------------------
    // Quadtree / collision API
    // -----------------------------------------------------------------------

    /**
     * Configure the world-space bounds of the quadtree root node and rebuild it.
     * Call this once when you know the map dimensions (or whenever the map resizes).
     *
     * @param wx  Center X of the world region
     * @param wy  Center Y of the world region
     * @param ww  Width  of the world region
     * @param wh  Height of the world region
     */
    public function setWorldBounds(wx:Float, wy:Float, ww:Float, wh:Float):Void {
        _qtX = wx;  _qtY = wy;  _qtW = ww;  _qtH = wh;
        rebuildQuadtree();
    }

    /**
     * Rebuild the quadtree from scratch using the current entity data.
     * Called automatically after removeEntity(); you can also call it manually
     * after bulk modifications.
     */
    public function rebuildQuadtree():Void {
        quadtree = new EntityQuadtree(_qtX, _qtY, _qtW, _qtH);
        for (entry in batches) {
            for (id in entry.entities.keys()) {
                var e = entry.entities.get(id);
                // quadtree uses center coords; e.x/y is the pivot world position
                var cx = e.x + (0.5 - e.pivotX) * e.width;
                var cy = e.y + (0.5 - e.pivotY) * e.height;
                quadtree.insert(id, cx, cy, e.width, e.height);
            }
        }
    }

    /**
     * Build a flat map of every entity's bounding box, keyed by entity ID.
     * Pass this to EntityQuadtree.pickEntity() for narrow-phase SAT tests.
     */
    public function getAllEntityBounds():Map<Int, EntityBounds> {
        var map = new Map<Int, EntityBounds>();
        for (entry in batches) {
            for (id in entry.entities.keys()) {
                var e = entry.entities.get(id);
                // SAT rect uses center coords; e.x/y is the pivot world position
                var cx = e.x + (0.5 - e.pivotX) * e.width;
                var cy = e.y + (0.5 - e.pivotY) * e.height;
                map.set(id, { id:id, x:cx, y:cy, width:e.width, height:e.height });
            }
        }
        return map;
    }

    /**
     * Pick the entity at world position (px, py).
     * Uses broad-phase quadtree + narrow-phase SAT (Differ) for accuracy.
     * Falls back to getEntityAt() tolerance-based search if the quadtree is null.
     *
     * @return Entity ID or -1 if nothing is hit.
     */
    public function pickEntityAt(px:Float, py:Float):Int {
        if (quadtree == null) return getEntityAt(px, py, 5.0);
        return quadtree.pickEntity(px, py, getAllEntityBounds());
    }

    /**
     * Draw the quadtree cell outlines into a LineBatch for debug visualisation.
     * Intended for use each frame before rendering:
     *
     *   entityLayer.drawDebugQuadtree(lineBatch, [0.2, 0.9, 0.2, 0.7]);
     *   renderer.renderDisplayObject(lineBatch, vpMatrix);
     *
     * @param lineBatch  A non-persistent LineBatch cleared each frame,
     *                   or a persistent one that you clear manually.
     * @param color      RGBA color, e.g. [0.2, 0.9, 0.2, 0.7]
     */
    public function drawDebugQuadtree(lineBatch:LineBatch, color:Array<Float>):Void {
        if (quadtree != null) quadtree.drawDebug(lineBatch, color);
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
