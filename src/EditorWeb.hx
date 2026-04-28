package;

/**
 * EditorWeb — JavaScript/web entry point for the Haxe editor.
 *
 * Mirrors the API of Editor.hx but targets the JS platform:
 *  - @:expose("Editor") publishes every method to window.Editor
 *  - No cpp.Pointer / C-struct interop — getters return plain Dynamic objects
 *  - File I/O uses app.saveBytes() / app.loadBytes() (web Runtime)
 *  - app.run() drives the RAF loop automatically after init()
 */

import haxe.io.Path;
import Log.LogCategory;
import states.EditorState;
import math.Vec2;
import layers.TilemapLayer;
import manager.TilesetManager;
import manager.EntityManager;
import utils.UIDGenerator;
import components.Components;

typedef ProjectData = {
    var projectFilePath:Null<String>;
    var projectDir:Null<String>;
    var projectId:String;
    var projectName:String;
    var defaultTileSizeX:Int;
    var defaultTileSizeY:Int;
}

@:expose("Editor")
class EditorWeb {

    private static var app:App = null;
    private static var initialized:Bool = false;
    private static var _projectData:ProjectData = null;
    private static var tilesetManager:TilesetManager = null;
    private static var entityManager:EntityManager = null;
    private static var _entitySelectionChangedCallback:()->Void = null;
    private static var _labelsVisible:Bool = true;

    private static var editorState(get, never):EditorState;
    private static inline function get_editorState():EditorState {
        return (app != null && Std.isOfType(app.currentState, EditorState))
            ? cast app.currentState : null;
    }

    /** Entry point — unused on web (app.run() starts the loop). */
    public static function main():Void {
        Components.registerAll();
    }

    // =========================================================================
    // LIFECYCLE
    // =========================================================================

    /**
     * Initialise the editor engine.
     * @param width   Initial GL viewport width  (defaults to 800)
     * @param height  Initial GL viewport height (defaults to 600)
     */
    @:keep
    public static function init(width:Int = 800, height:Int = 600):Bool {
        if (initialized) return true;

        tilesetManager = new TilesetManager();
        entityManager  = new EntityManager();

        try {
            app = new App();
            app.WINDOW_WIDTH  = width;
            app.WINDOW_HEIGHT = height;
            app.init();

            var initialState = new EditorState(app, tilesetManager, entityManager);
            app.addState(initialState);
            wireEditorStateCallbacks();

            initialized = true;
            app.log.info(LogCategory.SYSTEM, "Editor init successfully.");

            app.run(); // start requestAnimationFrame loop
            return true;
        } catch (e:Dynamic) {
            if (app != null) app.log.error(LogCategory.SYSTEM, "Editor: Init error: " + e);
            return false;
        }
    }

    @:keep
    public static function release():Void {
        if (app == null) return;
        app.log.info(LogCategory.SYSTEM, "Releasing editor resources...");
        app.release();
        app = null;
        initialized = false;
        tilesetManager = null;
        entityManager  = null;
        _projectData   = null;
    }

    @:keep
    public static function isRunning():Bool {
        return app != null && app.active;
    }

    // =========================================================================
    // WINDOW / VIEWPORT
    // =========================================================================

    @:keep
    public static function setWindowSize(width:Int, height:Int):Void {
        if (app == null || !initialized) return;
        app.WINDOW_WIDTH  = width;
        app.WINDOW_HEIGHT = height;
        app.window.size   = new Vec2(width, height);
        GL.viewport(0, 0, width, height);
    }

    @:keep
    public static function getWindowWidth():Int  { return app != null ? app.WINDOW_WIDTH  : 0; }

    @:keep
    public static function getWindowHeight():Int { return app != null ? app.WINDOW_HEIGHT : 0; }

    // =========================================================================
    // STATE MANAGEMENT
    // =========================================================================

    @:keep
    public static function newEditorState():Int {
        if (app == null || !initialized) return -1;
        try {
            var newState = new EditorState(app, tilesetManager, entityManager);
            var index    = app.addState(newState);
            app.switchToState(newState);
            applyProjectToState(newState);
            wireEditorStateCallbacks();
            return index;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.SYSTEM, "Editor: newEditorState error: " + e);
            return -1;
        }
    }

    @:keep
    public static function setActiveState(index:Int):Bool {
        if (app == null || !initialized || !app.states.isValid(index)) return false;
        var ok = app.switchToState(app.states.get(index));
        if (ok) wireEditorStateCallbacks();
        return ok;
    }

    @:keep
    public static function releaseState(index:Int):Bool {
        if (app == null || !initialized || !app.states.isValid(index)) return false;
        app.removeState(index);
        if (editorState != null) wireEditorStateCallbacks();
        return true;
    }

    @:keep
    public static function setEntitySelectionChangedCallback(cb:()->Void):Void {
        _entitySelectionChangedCallback = cb;
    }

    @:noExport @:keep
    private static function applyProjectToState(state:EditorState):Void {
        if (_projectData == null || state == null) return;
        @:privateAccess state.setTileSize(_projectData.defaultTileSizeX, _projectData.defaultTileSizeY);
        state.projectFilePath = _projectData.projectFilePath;
        state.projectId       = _projectData.projectId;
        state.projectName     = _projectData.projectName;
    }

    @:noExport @:keep
    private static function wireEditorStateCallbacks():Void {
        if (editorState == null) return;
        editorState.onEntitySelectionChanged = function() {
            if (_entitySelectionChangedCallback != null) _entitySelectionChangedCallback();
        };
    }

    // =========================================================================
    // INPUT (forwarded from HTML events)
    // =========================================================================

    @:keep
    public static function onMouseMotion(x:Int, y:Int):Void {
        if (app == null) return;
        @:privateAccess app.onMouseMotion(x, y, 0, 0, 1);
    }

    @:keep
    public static function onMouseButtonDown(x:Int, y:Int, button:Int):Void {
        if (app == null) return;
        @:privateAccess app.onMouseButtonDown(x, y, button, 1);
    }

    @:keep
    public static function onMouseButtonUp(x:Int, y:Int, button:Int):Void {
        if (app == null) return;
        @:privateAccess app.onMouseButtonUp(x, y, button, 1);
    }

    @:keep
    public static function onKeyboardDown(scancode:Int):Void {
        if (app == null) return;
        @:privateAccess app.onKeyDown(scancode, scancode, false, 0, 1);
    }

    @:keep
    public static function onKeyboardUp(scancode:Int):Void {
        if (app == null) return;
        @:privateAccess app.onKeyUp(scancode, scancode, false, 0, 1);
    }

    @:keep
    public static function onMouseWheel(x:Float, y:Float, delta:Float):Void {
        if (editorState != null) editorState.onMouseWheel(x, y, delta);
    }

    // =========================================================================
    // PROJECT SERIALIZATION
    // =========================================================================

    @:keep
    public static function exportProject(filePath:String, projectName:String):Bool {
        try {
            var tilesetsArray:Array<Dynamic> = [];
            for (name in tilesetManager.tilesets.keys()) {
                var ts = tilesetManager.tilesets.get(name);
                tilesetsArray.push({ name: ts.name, texturePath: ts.texturePath });
            }
            var entitiesArray:Array<Dynamic> = [];
            for (name in entityManager.entityDefinitions.keys()) {
                var def = entityManager.getEntityDefinition(name);
                entitiesArray.push({
                    name: def.name, width: def.width, height: def.height,
                    tilesetName: def.tilesetName,
                    regionX: def.regionX, regionY: def.regionY,
                    regionWidth: def.regionWidth, regionHeight: def.regionHeight,
                    pivotX: def.pivotX, pivotY: def.pivotY
                });
            }
            var projectId = (_projectData != null && _projectData.projectId != null && _projectData.projectId != "")
                ? _projectData.projectId : UIDGenerator.generate();
            var payload = { project: {
                version: "1.0", projectId: projectId,
                projectName: projectName != "" ? projectName : "Untitled",
                defaultTileSizeX: editorState != null ? editorState.tileSizeX : 64,
                defaultTileSizeY: editorState != null ? editorState.tileSizeY : 64,
                tilesets: tilesetsArray, entityDefinitions: entitiesArray
            }};
            app.saveBytes(filePath, haxe.Json.stringify(payload, null, "  "));
            if (_projectData == null) {
                _projectData = {
                    projectFilePath: filePath, projectDir: Path.directory(filePath),
                    projectId: projectId, projectName: projectName,
                    defaultTileSizeX: editorState != null ? editorState.tileSizeX : 64,
                    defaultTileSizeY: editorState != null ? editorState.tileSizeY : 64
                };
            } else {
                _projectData.projectFilePath = filePath;
                _projectData.projectId       = projectId;
                _projectData.projectName     = projectName;
                _projectData.projectDir      = Path.directory(filePath);
            }
            app.log.info(LogCategory.APP, "Editor: Exported project '" + projectName + "'");
            return true;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Error exporting project: " + e);
            return false;
        }
    }

    @:keep
    public static function importProject(filePath:String):Bool {
        try {
            var data:Dynamic = haxe.Json.parse(app.loadBytes(filePath).toString());
            tilesetManager = new TilesetManager();
            entityManager  = new EntityManager();
            app.resources.preDefinedPath = Path.directory(filePath) + "/res";
            var blankState = new EditorState(app, tilesetManager, entityManager);
            app.addState(blankState);
            wireEditorStateCallbacks();
            if (data.project == null) throw "Invalid project file: missing 'project' key";
            var pd:Dynamic = data.project;
            var tsX = pd.defaultTileSizeX != null ? Std.int(pd.defaultTileSizeX) : 16;
            var tsY = pd.defaultTileSizeY != null ? Std.int(pd.defaultTileSizeY) : 16;
            if (pd.tilesets != null) {
                for (ts in (pd.tilesets : Array<Dynamic>)) EditorWeb.createTileset(ts.texturePath, ts.name);
            }
            var loaded = 0;
            if (pd.entityDefinitions != null) {
                for (ed in (pd.entityDefinitions : Array<Dynamic>)) {
                    var px:Float = ed.pivotX != null ? ed.pivotX : 0.0;
                    var py:Float = ed.pivotY != null ? ed.pivotY : 0.0;
                    entityManager.setEntityFull(ed.name, ed.width, ed.height, ed.tilesetName,
                        ed.regionX, ed.regionY, ed.regionWidth, ed.regionHeight, px, py);
                    loaded++;
                }
            }
            var pid = (pd.projectId != null && Std.string(pd.projectId) != "")
                ? Std.string(pd.projectId) : UIDGenerator.generate();
            _projectData = {
                projectFilePath: filePath, projectDir: Path.directory(filePath),
                projectId: pid, projectName: pd.projectName != null ? pd.projectName : "",
                defaultTileSizeX: tsX, defaultTileSizeY: tsY
            };
            applyProjectToState(blankState);
            app.log.info(LogCategory.APP, "Editor: Imported project '" + _projectData.projectName + "' (" + loaded + " entities)");
            return true;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Error importing project: " + e);
            return false;
        }
    }

    @:keep
    public static function getProjectProps():Dynamic {
        if (_projectData == null) return null;
        return {
            filePath:        _projectData.projectFilePath != null ? _projectData.projectFilePath : "",
            projectDir:      _projectData.projectDir      != null ? _projectData.projectDir      : "",
            projectId:       _projectData.projectId       != null ? _projectData.projectId       : "",
            projectName:     _projectData.projectName,
            defaultTileSizeX: _projectData.defaultTileSizeX,
            defaultTileSizeY: _projectData.defaultTileSizeY
        };
    }

    @:keep
    public static function editProject(props:Dynamic):Bool {
        if (_projectData == null) return false;
        if (props.filePath  != null && props.filePath  != "") _projectData.projectFilePath = props.filePath;
        if (props.projectDir != null && props.projectDir != "") _projectData.projectDir = props.projectDir;
        if (props.projectId  != null && props.projectId  != "") _projectData.projectId  = props.projectId;
        _projectData.projectName     = props.projectName;
        _projectData.defaultTileSizeX = props.defaultTileSizeX;
        _projectData.defaultTileSizeY = props.defaultTileSizeY;
        if (_projectData.projectFilePath != null && _projectData.projectFilePath != "") {
            if (!exportProject(_projectData.projectFilePath, _projectData.projectName)) return false;
        }
        for (s in app.states) applyProjectToState(cast s);
        return true;
    }

    // =========================================================================
    // MAP SERIALIZATION
    // =========================================================================

    @:keep
    public static function exportMap(filePath:String):Bool {
        if (editorState == null) return false;
        try {
            var ok = editorState.exportToJSON(filePath);
            if (ok) app.log.info(LogCategory.APP, "Editor: Exported map to: " + filePath);
            return ok;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Error exporting map: " + e);
            return false;
        }
    }

    @:keep
    public static function importMap(filePath:String):Int {
        try {
            var data:Dynamic = haxe.Json.parse(app.loadBytes(filePath).toString());
            if (data.map == null) { app.log.error(LogCategory.APP, "Editor: Invalid map JSON"); return -1; }
            var mc:Dynamic = data.map;
            var mapProjPath = (mc.projectFile != null && Std.string(mc.projectFile) != "")
                ? Std.string(mc.projectFile) : null;
            var mapProjId   = (mc.projectId != null && Std.string(mc.projectId) != "")
                ? Std.string(mc.projectId) : null;
            var mapProjName = (mc.projectName != null && Std.string(mc.projectName) != "")
                ? Std.string(mc.projectName) : null;
            if (_projectData == null) {
                if (mapProjPath != null) {
                    if (!importProject(mapProjPath)) { app.log.error(LogCategory.APP, "Editor: Failed to import referenced project"); return -1; }
                } else {
                    throw "Map JSON does not reference a project file";
                }
            }
            var newState = new EditorState(app, tilesetManager, entityManager);
            newState.projectFilePath = mapProjPath;
            newState.projectId       = mapProjId;
            newState.projectName     = mapProjName;
            var index = app.addState(newState);
            wireEditorStateCallbacks();
            newState.importFromJSON(mc, filePath);
            app.switchToState(newState);
            app.log.info(LogCategory.APP, "Editor: Imported map from: " + filePath);
            return index;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Error importing map: " + e);
            return -1;
        }
    }

    @:keep
    public static function getMapProps():Dynamic {
        if (editorState == null) return null;
        return {
            idd:             editorState.iid,
            name:            editorState.name,
            worldx:          Std.int(editorState.mapX),
            worldy:          Std.int(editorState.mapY),
            width:           Std.int(editorState.mapWidth),
            height:          Std.int(editorState.mapHeight),
            tileSizeX:       editorState.tileSizeX,
            tileSizeY:       editorState.tileSizeY,
            bgColor:         editorState.grid.backgroundColor.hexValue,
            gridColor:       editorState.grid.gridColor.hexValue,
            projectFilePath: editorState.projectFilePath != null ? editorState.projectFilePath : "",
            projectId:       editorState.projectId       != null ? editorState.projectId       : "",
            projectName:     editorState.projectName     != null ? editorState.projectName     : ""
        };
    }

    @:keep
    public static function setMapProps(props:Dynamic):Bool {
        if (editorState == null) return false;
        try {
            editorState.grid.gridColor.hexValue       = props.gridColor;
            editorState.grid.backgroundColor.hexValue = props.bgColor;
            if (props.tileSizeX != editorState.tileSizeX || props.tileSizeY != editorState.tileSizeY)
                editorState.recalibrateTileSize(props.tileSizeX, props.tileSizeY);
            editorState.projectFilePath = (props.projectFilePath != null && props.projectFilePath != "") ? props.projectFilePath : null;
            editorState.projectId       = (props.projectId != null && props.projectId != "") ? props.projectId : null;
            editorState.projectName     = (props.projectName != null && props.projectName != "") ? props.projectName : null;
            return true;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: setMapProps error: " + e);
            return false;
        }
    }

    // =========================================================================
    // TILESET MANAGEMENT
    // =========================================================================

    @:keep
    public static function createTileset(relativePath:String, tilesetName:String):Bool {
        // Normalize: forward slashes, strip any leading slash
        relativePath = StringTools.replace(relativePath, "\\", "/");
        if (relativePath.charAt(0) == "/") relativePath = relativePath.substr(1);
        try {
            if (!app.resources.cached(relativePath)) app.resources.loadTexture(relativePath, true);
            if (tilesetManager.exists(tilesetName)) return true;
            var tex = app.renderer.uploadTexture(app.resources.getTexture(relativePath));
            tilesetManager.setTileset(tex, tilesetName, relativePath);
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: createTileset '" + tilesetName + "': " + e);
            return false;
        }
        return true;
    }

    @:keep
    public static function deleteTileset(name:String):Bool {
        tilesetManager.deleteTileset(name);
        for (s in app.states) (cast s:EditorState).removeTilesetReferences(name);
        return true;
    }

    @:keep
    public static function getTileset(tilesetName:String):Dynamic {
        var et = tilesetManager != null ? tilesetManager.getTilesetInfo(tilesetName) : null;
        return et != null ? { name: et.name, texturePath: et.texturePath } : null;
    }

    @:keep
    public static function getTilesetAt(index:Int):Dynamic {
        var et = tilesetManager != null ? tilesetManager.getTilesetInfoAt(index) : null;
        return et != null ? { name: et.name, texturePath: et.texturePath } : null;
    }

    @:keep
    public static function getTilesetCount():Int {
        return tilesetManager != null ? tilesetManager.getTilesetCount() : 0;
    }

    /**
     * Returns dimensional and path metadata for a tileset's texture.
     * Result: { name, texturePath, width, height, bpp }  or null.
     */
    @:keep
    public static function getTextureInfo(tilesetName:String):Dynamic {
        if (tilesetManager == null) return null;
        var et = tilesetManager.getTilesetInfo(tilesetName);
        if (et == null) return null;
        var td:data.TextureData = null;
        try { td = app.resources.getTexture(et.texturePath); } catch (_:Dynamic) {}
        if (td != null) {
            return { name: et.name, texturePath: et.texturePath, width: td.width, height: td.height, bpp: td.bytesPerPixel };
        }
        return { name: et.name, texturePath: et.texturePath, width: 0, height: 0, bpp: 0 };
    }

    /**
     * Encodes a tileset's texture as a PNG data URL suitable for <img src>.
     * Pixel bytes are converted from RGB/RGBA/grayscale to canvas RGBA.
     * Returns null if the texture is not cached.
     */
    @:keep
    public static function getTextureDataUrl(tilesetName:String):String {
        if (tilesetManager == null) return null;
        var et = tilesetManager.getTilesetInfo(tilesetName);
        if (et == null) return null;
        var td:data.TextureData = null;
        try { td = app.resources.getTexture(et.texturePath); } catch (_:Dynamic) {}
        if (td == null) return null;

        var w   = td.width;
        var h   = td.height;
        var bpp = td.bytesPerPixel;
        var src = td.bytes;
        var n   = w * h;

        // Build an RGBA Haxe Array that JS will treat as a plain Array<Int>
        var rgba:Array<Int> = new Array<Int>();
        for (i in 0...n) {
            var si = i * bpp;
            rgba.push(src.get(si));
            rgba.push(bpp > 1 ? src.get(si + 1) : src.get(si));
            rgba.push(bpp > 2 ? src.get(si + 2) : src.get(si));
            rgba.push(bpp > 3 ? src.get(si + 3) : 255);
        }

        return js.Syntax.code("(function(w,h,px){
            var u8=new Uint8ClampedArray(px);
            var cv=document.createElement('canvas'); cv.width=w; cv.height=h;
            cv.getContext('2d').putImageData(new ImageData(u8,w,h),0,0);
            return cv.toDataURL('image/png');
        })({0},{1},{2})", w, h, rgba);
    }

    @:keep
    public static function setActiveTileset(tilesetName:String):Bool {
        return editorState != null ? editorState.tilesetManager.setActiveTileset(tilesetName) : false;
    }

    @:keep
    public static function getActiveTile():Int {
        return editorState != null ? editorState.getActiveTile() : 0;
    }

    @:keep
    public static function setActiveTile(tileRegionId:Int):Void {
        if (editorState != null) editorState.setActiveTile(tileRegionId);
    }

    // =========================================================================
    // ENTITY DEFINITIONS
    // =========================================================================

    @:keep
    public static function createEntityDef(entityName:String, data:Dynamic):Bool {
        if (entityManager.exists(entityName)) return false;
        var ts:String = data.tilesetName;
        var rX = data.regionX; var rY = data.regionY;
        var rW = data.regionWidth; var rH = data.regionHeight;
        if (ts == null || ts == "") { rX = 0; rY = 0; rW = data.width; rH = data.height; }
        entityManager.setEntityFull(entityName, data.width, data.height, ts, rX, rY, rW, rH, data.pivotX, data.pivotY);
        return true;
    }

    @:keep
    public static function editEntityDef(entityName:String, data:Dynamic):Bool {
        var ts:String = data.tilesetName;
        if (ts != null && ts != "" && !tilesetManager.exists(ts)) return false;
        var rX = data.regionX; var rY = data.regionY;
        var rW = data.regionWidth; var rH = data.regionHeight;
        if (ts == null || ts == "") { rX = 0; rY = 0; rW = data.width; rH = data.height; }
        // editEntity propagates changes to all placed instances in the active state
        var err = editorState != null ? editorState.editEntity(entityName, data.width, data.height, ts, rX, rY, rW, rH, data.pivotX, data.pivotY) : null;
        return err == null;
    }

    @:keep
    public static function deleteEntityDef(entityName:String):Bool {
        if (!entityManager.exists(entityName)) return false;
        for (s in app.states) (cast s:EditorState).removeEntityInstances(entityName);
        entityManager.deleteEntityDefinition(entityName);
        return true;
    }

    @:keep
    public static function getEntityDef(entityName:String):Dynamic {
        var def = entityManager != null ? entityManager.getEntityDefinition(entityName) : null;
        if (def == null) return null;
        return { name: def.name, width: def.width, height: def.height, tilesetName: def.tilesetName,
                 regionX: def.regionX, regionY: def.regionY, regionWidth: def.regionWidth, regionHeight: def.regionHeight,
                 pivotX: def.pivotX, pivotY: def.pivotY };
    }

    @:keep
    public static function getEntityDefAt(index:Int):Dynamic {
        var def = entityManager != null ? entityManager.getEntityDefinitionAt(index) : null;
        if (def == null) return null;
        return { name: def.name, width: def.width, height: def.height, tilesetName: def.tilesetName,
                 regionX: def.regionX, regionY: def.regionY, regionWidth: def.regionWidth, regionHeight: def.regionHeight,
                 pivotX: def.pivotX, pivotY: def.pivotY };
    }

    @:keep
    public static function getEntityDefCount():Int {
        return entityManager != null ? entityManager.getEntityDefinitionCount() : 0;
    }

    @:keep
    public static function setActiveEntityDef(entityName:String):Bool {
        if (entityManager == null || !entityManager.exists(entityName)) return false;
        entityManager.selectedEntityName = entityName;
        return true;
    }

    // =========================================================================
    // ENTITY SELECTION
    // =========================================================================

    @:keep
    public static function getEntitySelectionCount():Int {
        return editorState != null ? editorState.selectedEntities.length : 0;
    }

    @:keep
    public static function getEntitySelectionInfo(index:Int):Dynamic {
        if (editorState == null || index >= editorState.selectedEntities.length) return null;
        var e = editorState.selectedEntities[index];
        return { uid: e.uid, name: e.name, x: Std.int(e.x), y: Std.int(e.y),
                 width: Std.int(e.width), height: Std.int(e.height) };
    }

    @:keep
    public static function selectEntityByUID(uid:String):Bool {
        return editorState != null ? editorState.selectEntityByUID(uid) : false;
    }

    @:keep
    public static function deselectEntity():Void {
        if (editorState != null) editorState.deselectEntity();
    }

    // =========================================================================
    // LAYER MANAGEMENT
    // =========================================================================

    @:keep
    public static function createTilemapLayer(name:String, tilesetName:String, tileSize:Int):Bool {
        return editorState != null && editorState.createTilemapLayer(name, tilesetName, -1, tileSize) != null;
    }

    @:keep
    public static function createEntityLayer(name:String):Bool {
        return editorState != null && editorState.createEntityLayer(name) != null;
    }

    @:keep
    public static function createFolderLayer(name:String):Bool {
        return editorState != null && editorState.createFolderLayer(name) != null;
    }

    @:keep
    public static function getLayerCount():Int {
        return editorState != null ? editorState.getLayerCount() : 0;
    }

    @:keep
    public static function getLayerInfo(layerName:String):Dynamic {
        if (editorState == null) return null;
        var layer = editorState.getLayerByName(layerName);
        if (layer == null) return null;
        var tilesetName = "";
        if (Std.isOfType(layer, TilemapLayer)) {
            var tl:TilemapLayer = cast layer;
            if (tl.editorTexture != null) tilesetName = tl.editorTexture.name;
        }
        return { name: layer.id, type: layerTypeToInt(layer), tilesetName: tilesetName,
                 visible: layer.visible ? 1 : 0, silhouette: layer.silhouette ? 1 : 0 };
    }

    @:keep
    public static function getLayerInfoAt(index:Int):Dynamic {
        if (editorState == null) return null;
        var layer = editorState.getLayerAt(index);
        if (layer == null) return null;
        var tilesetName = "";
        if (Std.isOfType(layer, TilemapLayer)) {
            var tl:TilemapLayer = cast layer;
            if (tl.editorTexture != null) tilesetName = tl.editorTexture.name;
        }
        return { name: layer.id, type: layerTypeToInt(layer), tilesetName: tilesetName,
                 visible: layer.visible ? 1 : 0, silhouette: layer.silhouette ? 1 : 0 };
    }

    @:keep
    public static function setActiveLayer(layerName:String):Bool {
        return editorState != null ? editorState.setActiveLayer(layerName) : false;
    }

    @:keep
    public static function removeLayer(layerName:String):Bool {
        return editorState != null ? editorState.removeLayer(layerName) : false;
    }

    @:keep
    public static function moveLayerUp(layerName:String):Bool {
        return editorState != null ? editorState.moveLayerUp(layerName) : false;
    }

    @:keep
    public static function moveLayerDown(layerName:String):Bool {
        return editorState != null ? editorState.moveLayerDown(layerName) : false;
    }

    @:keep
    public static function renameLayer(oldName:String, newName:String):Bool {
        return editorState != null ? editorState.renameLayer(oldName, newName) : false;
    }

    // =========================================================================
    // TOOLS
    // =========================================================================

    @:keep
    public static function setToolType(toolIndex:Int):Void {
        if (editorState == null) return;
        editorState.toolType = switch (toolIndex) {
            case 0: type.ToolType.TILE_DRAW;
            case 1: type.ToolType.TILE_ERASE;
            case 2: type.ToolType.ENTITY_ADD;
            case 3: type.ToolType.ENTITY_SELECT;
            default: type.ToolType.TILE_DRAW;
        };
    }

    @:keep
    public static function getToolType():Int {
        if (editorState == null) return 0;
        return switch (editorState.toolType) {
            case TILE_DRAW:    0;
            case TILE_ERASE:   1;
            case ENTITY_ADD:   2;
            case ENTITY_SELECT: 3;
        };
    }

    @:keep
    public static function toggleLabels():Void {
        _labelsVisible = !_labelsVisible;
        if (editorState != null) editorState.toggleLabels(_labelsVisible);
    }

    // =========================================================================
    // HELPERS
    // =========================================================================

    private static function layerTypeToInt(layer:layers.Layer):Int {
        if (Std.isOfType(layer, layers.TilemapLayer)) return 0;
        if (Std.isOfType(layer, layers.EntityLayer))  return 1;
        if (Std.isOfType(layer, layers.FolderLayer))  return 2;
        return 0;
    }
}
