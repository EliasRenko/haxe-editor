package manager;

import Log.LogCategory;
import layers.Layer;
import layers.TilemapLayer;
import layers.EntityLayer;
import layers.FolderLayer;
import display.ManagedTileBatch;
import states.EditorState;

/**
 * Owns the layer stack for a single EditorState.
 * Handles CRUD, reordering, active-layer tracking, and layer factory methods.
 * EditorState delegates all layer operations here and exposes the same public
 * API as thin one-liner wrappers so the native C# boundary is unchanged.
 */
class LayerManager {

    /** The currently active layer (used by input tools and tile/entity placement). */
    public var activeLayer:Layer = null;

    /** Back-reference to the owning state (app, renderer, tilesetManager, entities…). */
    private var state:EditorState;

    public function new(state:EditorState) {
        this.state = state;
    }

    // ── Add ─────────────────────────────────────────────────────────────────

    /**
     * Push a layer to the end of the entity array and wire up its dependencies
     * (quadtree bounds, labelFont, log).  Makes it the active layer when none exists.
     */
    public function add(layer:Layer):Void {
        if (layer == null) return;
        state.addEntity(layer);
        _initLayerDeps(layer);
        if (activeLayer == null) _makeActive(layer);
    }

    /**
     * Insert a layer at a specific layer-only index position.
     * @param index  0-based layer index; -1 or out-of-bounds appends at the end.
     */
    public function addAtIndex(layer:Layer, index:Int):Void {
        if (layer == null) return;
        layer.state = state;
        var entities = state.entities;
        if (index < 0 || index >= entities.length) {
            entities.push(layer);
        } else {
            var layerCount = 0;
            var insertIndex = 0;
            for (i in 0...entities.length) {
                if (Std.isOfType(entities[i], Layer)) {
                    if (layerCount == index) { insertIndex = i; break; }
                    layerCount++;
                }
                insertIndex = i + 1;
            }
            entities.insert(insertIndex, layer);
        }
        _initLayerDeps(layer);
        if (activeLayer == null) _makeActive(layer);
    }

    // ── Remove ───────────────────────────────────────────────────────────────

    /** Remove a layer by name. Returns false if not found. */
    public function remove(layerName:String):Bool {
        var layer = getByName(layerName);
        if (layer == null) {
            state.app.log.error(LogCategory.APP, "LayerManager: layer not found: " + layerName);
            return false;
        }
        state.removeEntity(layer);
        layer.cleanup(null);
        if (activeLayer == layer) _resetActive();
        return true;
    }

    /** Remove a layer by zero-based index. Returns false if not found. */
    public function removeAt(index:Int):Bool {
        var layer = getAt(index);
        if (layer == null) {
            state.app.log.error(LogCategory.APP, "LayerManager: layer not found at index: " + index);
            return false;
        }
        state.removeEntity(layer);
        layer.cleanup(null);
        if (activeLayer == layer) _resetActive();
        return true;
    }

    // ── Active layer ─────────────────────────────────────────────────────────

    /** Set active layer by name. Returns false if not found. */
    public function setActive(layerName:String):Bool {
        var layer = getByName(layerName);
        if (layer == null) {
            state.app.log.error(LogCategory.APP, "LayerManager: layer not found: " + layerName);
            return false;
        }
        return _makeActive(layer);
    }

    /** Set active layer by zero-based index. Returns false if not found. */
    public function setActiveAt(index:Int):Bool {
        var layer = getAt(index);
        if (layer == null) {
            state.app.log.error(LogCategory.APP, "LayerManager: layer not found at index: " + index);
            return false;
        }
        return _makeActive(layer);
    }

    // ── Query ────────────────────────────────────────────────────────────────

    /**
     * Find a layer by name; searches FolderLayer children recursively.
     * Returns null if not found.
     */
    public function getByName(name:String):Layer {
        for (entity in state.entities) {
            if (Std.isOfType(entity, Layer)) {
                var layer:Layer = cast entity;
                if (layer.id == name) return layer;
                if (Std.isOfType(layer, FolderLayer)) {
                    var found = (cast layer:FolderLayer).findLayerByName(name);
                    if (found != null) return found;
                }
            }
        }
        return null;
    }

    /** Count of top-level Layer entries in the entity array. */
    public function count():Int {
        var n = 0;
        for (e in state.entities) if (Std.isOfType(e, Layer)) n++;
        return n;
    }

    /** Get a layer by zero-based layer-only index. Returns null if out of range. */
    public function getAt(index:Int):Layer {
        var i = 0;
        for (entity in state.entities) {
            if (Std.isOfType(entity, Layer)) {
                if (i == index) return cast entity;
                i++;
            }
        }
        return null;
    }

    // ── Reorder ──────────────────────────────────────────────────────────────

    /** Move a layer one step toward the front (rendered earlier = visually behind). */
    public function moveUp(layerName:String):Bool {
        var layer = getByName(layerName);
        if (layer == null) {
            state.app.log.error(LogCategory.APP, "LayerManager: layer not found: " + layerName);
            return false;
        }
        var entities = state.entities;
        var cur = entities.indexOf(layer);
        if (cur <= 0) return false;
        var target = -1;
        for (i in 0...cur) {
            var prev = cur - 1 - i;
            if (Std.isOfType(entities[prev], Layer)) { target = prev; break; }
        }
        if (target == -1) return false;
        var tmp = entities[cur]; entities[cur] = entities[target]; entities[target] = tmp;
        return true;
    }

    /** Move a layer one step toward the back (rendered later = visually on top). */
    public function moveDown(layerName:String):Bool {
        var layer = getByName(layerName);
        if (layer == null) {
            state.app.log.error(LogCategory.APP, "LayerManager: layer not found: " + layerName);
            return false;
        }
        var entities = state.entities;
        var cur = entities.indexOf(layer);
        if (cur == -1 || cur >= entities.length - 1) return false;
        var target = -1;
        for (i in (cur + 1)...entities.length) {
            if (Std.isOfType(entities[i], Layer)) { target = i; break; }
        }
        if (target == -1) return false;
        var tmp = entities[cur]; entities[cur] = entities[target]; entities[target] = tmp;
        return true;
    }

    /** Move a layer to an absolute layer-only index position. */
    public function moveTo(layerName:String, newIndex:Int):Bool {
        var layer = getByName(layerName);
        if (layer == null) {
            state.app.log.error(LogCategory.APP, "LayerManager: layer not found: " + layerName);
            return false;
        }
        var entities = state.entities;
        if (entities.indexOf(layer) == -1) return false;
        var total = count();
        if (newIndex < 0) newIndex = 0;
        if (newIndex >= total) newIndex = total - 1;
        // Determine current layer-only index
        var curLayerIdx = 0;
        for (i in 0...entities.length) {
            if (Std.isOfType(entities[i], Layer)) {
                if (entities[i] == layer) break;
                curLayerIdx++;
            }
        }
        if (curLayerIdx == newIndex) return true;
        entities.remove(layer);
        var insertIndex = 0;
        var cnt = 0;
        for (i in 0...entities.length) {
            if (Std.isOfType(entities[i], Layer)) {
                if (cnt == newIndex) { insertIndex = i; break; }
                cnt++;
            }
            insertIndex = i + 1;
        }
        entities.insert(insertIndex, layer);
        return true;
    }

    /** Move a layer up by zero-based layer index. */
    public function moveUpByIndex(index:Int):Bool {
        var layer = getAt(index);
        return layer != null ? moveUp(layer.id) : false;
    }

    /** Move a layer down by zero-based layer index. */
    public function moveDownByIndex(index:Int):Bool {
        var layer = getAt(index);
        return layer != null ? moveDown(layer.id) : false;
    }

    // ── Factory methods ──────────────────────────────────────────────────────

    /** Create and register a new TilemapLayer. Returns null on failure. */
    public function createTilemap(name:String, tilesetName:String, index:Int = -1, tileSize:Int = 64):TilemapLayer {
        try {
            var tileset = state.tilesetManager.tilesets.get(tilesetName);
            if (tileset == null) {
                state.app.log.error(LogCategory.APP, "Cannot create tilemap layer: tileset not found: " + tilesetName);
                return null;
            }
            var programInfo = state.app.renderer.getProgramInfo("texture");
            var batch = new ManagedTileBatch(programInfo, tileset.textureId);
            batch.debugName = "TilemapLayer:" + name;
            batch.depthTest = false;
            batch.init(state.app.renderer);
            var tilesPerRow = Std.int(tileset.textureId.width / tileSize);
            var tilesPerCol = Std.int(tileset.textureId.height / tileSize);
            for (row in 0...tilesPerCol)
                for (col in 0...tilesPerRow)
                    batch.defineRegion(col * tileSize, row * tileSize, tileSize, tileSize);
            var layer = new TilemapLayer(name, tileset, batch, tileSize, tilesPerRow, tilesPerCol);
            addAtIndex(layer, index);
            return layer;
        } catch (e:Dynamic) {
            state.app.log.error(LogCategory.APP, "Error creating tilemap layer '" + name + "': " + e);
            return null;
        }
    }

    /** Create and register a new empty EntityLayer. */
    public function createEntity(name:String):EntityLayer {
        var layer = new EntityLayer(name);
        add(layer);
        state.app.log.info(LogCategory.APP, "Created empty entity layer: " + name);
        return layer;
    }

    /** Create and register a new FolderLayer. */
    public function createFolder(name:String):FolderLayer {
        var layer = new FolderLayer(name);
        add(layer);
        state.app.log.info(LogCategory.APP, "Created folder layer: " + name);
        return layer;
    }

    /**
     * Swap a TilemapLayer's backing tileset and recompute its atlas regions.
     * Returns false if the layer or new tileset is not found.
     */
    public function replaceTileset(layerName:String, newTilesetName:String):Bool {
        var layer = getByName(layerName);
        if (layer == null) {
            state.app.log.error(LogCategory.APP, "LayerManager.replaceTileset: layer not found: " + layerName);
            return false;
        }
        if (!Std.isOfType(layer, TilemapLayer)) {
            state.app.log.error(LogCategory.APP, "LayerManager.replaceTileset: layer is not a tilemap layer: " + layerName);
            return false;
        }
        var tl:TilemapLayer = cast layer;
        var newTileset = state.tilesetManager.tilesets.get(newTilesetName);
        if (newTileset == null) {
            state.app.log.error(LogCategory.APP, "LayerManager.replaceTileset: tileset not found: " + newTilesetName);
            return false;
        }
        tl.editorTexture = newTileset;
        tl.managedTileBatch.setTexture(newTileset.textureId);
        tl.tilesPerRow = Std.int(newTileset.textureId.width / tl.tileSize);
        tl.tilesPerCol = Std.int(newTileset.textureId.height / tl.tileSize);
        tl.redefineRegions();
        tl.managedTileBatch.needsBufferUpdate = true;
        return true;
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /**
     * Wire up quadtree bounds, labelFont, and log reference for a newly added
     * EntityLayer.  No-op for TilemapLayer / FolderLayer.
     */
    private function _initLayerDeps(layer:Layer):Void {
        var el = Std.downcast(layer, EntityLayer);
        if (el != null) {
            el.setWorldBounds(
                state.mapX + state.mapWidth  * 0.5,
                state.mapY + state.mapHeight * 0.5,
                state.mapWidth, state.mapHeight
            );
            el.labelFont = state.entityLabelFont;
            el.log = state.app.log;
            state.app.log.info(LogCategory.APP,
                "[LabelFont] addLayer '" + el.id + "': labelFont set, isNull=" + (state.entityLabelFont == null));
        }
    }

    /**
     * Make a layer the active one.
     * For TilemapLayers also switches the TilesetManager's active tileset.
     * @return true on success (or false if setActiveTileset fails for tilemap layers).
     */
    private function _makeActive(layer:Layer):Bool {
        activeLayer = layer;
        if (Std.isOfType(layer, TilemapLayer)) {
            var tl:TilemapLayer = cast layer;
            return state.tilesetManager.setActiveTileset(tl.editorTexture.name);
        }
        return true;
    }

    /**
     * After the active layer is removed, promote the first remaining layer.
     * Sets activeLayer to null if no layers remain.
     */
    private function _resetActive():Void {
        activeLayer = null;
        for (e in state.entities) {
            if (Std.isOfType(e, Layer)) {
                _makeActive(cast e);
                return;
            }
        }
    }
}
