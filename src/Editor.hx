package;

import haxe.io.Path;
import data.TextureData;
import Log.LogCategory;
import states.EditorState;
import math.Vec2;
import layers.TilemapLayer;
import struct.MapProps;
import struct.ProjectProps;
import struct.EntityDataStruct;
import struct.EntityStruct;
import struct.TextureDataStruct;
import struct.TilesetInfoStruct;
import struct.LayerInfoStruct;
import cpp.Pointer;
import cpp.Reference;
import manager.TilesetManager;
import manager.EntityManager;
import utils.UIDGenerator;

/** Project-level metadata shared across all maps.
 *  Tileset and entity-definition data live in the shared managers, not here. */
typedef ProjectData = {
    var projectFilePath:Null<String>;
    var projectDir:Null<String>;
    var projectId:String;
    var projectName:String;
    var defaultTileSizeX:Int;
    var defaultTileSizeY:Int;
};

@:headerCode('#include "editor_native.h"')
@:build(macro.NativeExportMacro.build())

class Editor {

    private static var app:App = null;
    private static var initialized:Bool = false;
    // Project-level metadata
    private static var _projectData:ProjectData = null;
    // Shared managers — owned here, referenced by every EditorState
    private static var tilesetManager:TilesetManager = null;
    private static var entityManager:EntityManager = null;
    // Convenience accessor — always mirrors app.currentState
    private static var editorState(get, never):states.EditorState;
    private static inline function get_editorState():states.EditorState {
        return (app != null && Std.isOfType(app.currentState, states.EditorState))
            ? cast app.currentState : null;
    }

    public static function main():Void {
    }

    // Custom log function that uses SDL logging (forwarded to C# via CustomLogOutput)
    private static function log(msg:String):Void {
        untyped __cpp__("SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, \"%s\", {0})", msg);
    }

    // Redirect haxe.Log.trace → OutputDebugString so traces appear in the
    // Visual Studio Output (Debug) panel even when running as a DLL.
    // private static function redirectTraceToDebugOutput():Void {
    //     haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos):Void {
    //         var msg = (pos != null ? pos.fileName + ":" + pos.lineNumber + ": " : "") + Std.string(v);
    //         untyped __cpp__("OutputDebugStringA({0})", msg + "\n");
    //     };
    // }

    // ===== ENGINE LIFECYCLE =====

    @:keep
    public static function init():Bool {
        //redirectTraceToDebugOutput();
        if (initialized) {
            log("Engine already initialized");
            return true;
        }

        tilesetManager = new TilesetManager();
        entityManager = new EntityManager();

        try {
            app = new App();
            app.init();
            
            var initialState = new EditorState(app, tilesetManager, entityManager);
            app.addState(initialState);

            // TODO: Refine later
            wireEditorStateCallbacks();

            initialized = true;
            app.log.info(Log.LogCategory.SYSTEM, "Editor init successfully.");

            return true;
        } catch (e:Dynamic) {
            app.log.error(Log.LogCategory.SYSTEM, "Editor: Init error: " + e);
            return false;
        }
    }

    @:keep
    public static function release():Void {
        app.log.info(Log.LogCategory.SYSTEM, "Releasing editor resources...");
        app.release();
        app = null;
        initialized = false;
        tilesetManager = null;
        entityManager = null;
        _projectData = null;
    }

    @:keep
    public static function isRunning():Bool {
        return app.active ? true : false;
    }

    @:keep
    public static function updateFrame(deltaTime:Float):Void {
        app.processEvents();
        app.updateFrame(deltaTime);
    }

    @:keep
    public static function render():Void {
        app.render();
    }

    @:keep
    public static function swapBuffers():Void {
        app.swapBuffers();
    }

    // ===== STATE MANAGEMENT =====

    /**
     * Create a blank new EditorState, register it with the app, make it active,
     * and return its index. Returns -1 on failure.
     */
    @:keep
    public static function newEditorState():Int {
        if (app == null || !initialized) return -1;
        try {
            var newState = new EditorState(app, tilesetManager, entityManager);
            var index = app.addState(newState);
            app.switchToState(newState);

            applyProjectToState(newState);

            wireEditorStateCallbacks();
            app.log.info(Log.LogCategory.SYSTEM, "Editor: Created new EditorState at index " + index);
            return index;
        } catch (e:Dynamic) {
            app.log.error(Log.LogCategory.SYSTEM, "Editor: newEditorState error: " + e);
            return -1;
        }
    }

    /**
     * Switch the active editor state by index.
     * @return true on success, false if index is out of range
     */
    @:keep
    public static function setActiveState(index:Int):Bool {
        if (app == null || !initialized) return false;
        if (!app.states.isValid(index)) {
            app.log.warn(Log.LogCategory.SYSTEM, "Editor: setActiveState — index " + index + " is not a valid state");
            return false;
        }
        var success = app.switchToState(app.states.get(index));
        if (success) wireEditorStateCallbacks();
        return success;
    }

    /**
     * Fully release and destroy the editor state at the given index.
     * If it was the active state the app will switch to the next available one.
     * @return true on success, false if index is out of range
     */
    @:keep
    public static function releaseState(index:Int):Bool {
        if (app == null || !initialized) return false;
        if (!app.states.isValid(index)) {
            app.log.warn(Log.LogCategory.SYSTEM, "Editor: releaseState — index " + index + " is not a valid state");
            return false;
        }
        app.removeState(index);
        // Re-wire callbacks to whichever state is now active (if any)
        if (editorState != null) wireEditorStateCallbacks();
        app.log.info(Log.LogCategory.SYSTEM, "Editor: Released state " + index + " (" + app.states.count + " remaining)");
        return true;
    }

    /** Apply project-level defaults (tile size) to a state.
     *  Also connect state.projectFilePath/projectName when project context exists.
     */
    @:noExport @:keep
    private static function applyProjectToState(state:EditorState):Void {
        if (_projectData == null || state == null) return;
        @:privateAccess state.setTileSize(_projectData.defaultTileSizeX, _projectData.defaultTileSizeY);
        state.projectFilePath = _projectData.projectFilePath;
        state.projectId = _projectData.projectId;
        state.projectName = _projectData.projectName;
    }

    @:noExport @:keep
    public static function wireEditorStateCallbacks():Void {
        editorState.onEntitySelectionChanged = function() {
            untyped __cpp__("if (g_entitySelectionChangedCallback) g_entitySelectionChangedCallback()");
        };
    }

    // ===== WINDOW =====

    /**
     * Get native window handle (HWND on Windows)
     * Returns void* which can be cast to IntPtr in C#
     */
    @:keep
    public static function getWindowHandle():cpp.RawPointer<cpp.Void> {
        if (app != null && initialized && app.window != null) {
            return untyped __cpp__("SDL_GetPointerProperty(SDL_GetWindowProperties({0}), SDL_PROP_WINDOW_WIN32_HWND_POINTER, NULL)", app.window.ptr);
        }
        return null;
    }

    /**
     * Get window width
     */
    @:keep
    public static function getWindowWidth():Int {
        return app.WINDOW_WIDTH;
    }

    /**
     * Get window height
     */
    @:keep
    public static function getWindowHeight():Int {
        return app.WINDOW_HEIGHT;
    }

    @:keep
    public static function setWindowPosition(x:Int, y:Int):Void {
        app.window.setPosition(x, y);
    }

    /**
     * Set window size
     */
    @:keep
    public static function setWindowSize(width:Int, height:Int):Void {
        app.window.size = new Vec2(width, height);
    }

    // ===== INPUT =====

    @:keep
    public static function onMouseMotion(x:Int, y:Int):Void {
        @:privateAccess app.onMouseMotion(x, y, 0, 0, 1);
    }

    @:keep
    public static function onMouseButtonDown(x:Int, y:Int, button:Int):Void {
        @:privateAccess app.onMouseButtonDown(x, y, button, 1);
    }

    @:keep
    public static function onMouseButtonUp(x:Int, y:Int, button:Int):Void {
        @:privateAccess app.onMouseButtonUp(x, y, button, 1);
    }

    @:keep
    public static function onKeyboardDown(scancode:Int):Void {
       @:privateAccess app.onKeyDown(scancode, scancode, false, 0, 1);
    }

    @:keep
    public static function onKeyboardUp(scancode:Int):Void {
        @:privateAccess app.onKeyUp(scancode, scancode, false, 0, 1);
    }

    /**
     * Forward a mouse-wheel event to the active editor state.
     * @param x      Cursor X in screen pixels at the time of the scroll
     * @param y      Cursor Y in screen pixels at the time of the scroll
     * @param delta  Wheel delta: positive = scroll up (zoom in), negative = scroll down (zoom out)
     */
    @:keep
    public static function onMouseWheel(x:Float, y:Float, delta:Float):Void {
        if (editorState != null) editorState.onMouseWheel(x, y, delta);
    }

    // ===== PROJECT SERIALIZATION =====

    /**
     * Save entity definitions and tilesets to a project file (.hxproject).
     * After a successful save the active state's projectFilePath is updated so
     * subsequent map exports reference this file instead of embedding entity data.
     * @param filePath     Absolute path for the output .hxproject JSON file.
     * @param projectName  Human-readable name stored inside the file.
     * @return Number of entity definitions written, or -1 on error.
     */
    @:keep
    public static function exportProject(filePath:String, projectName:String):Bool {
        try {
            // Tilesets
            var tilesetsArray:Array<Dynamic> = [];
            for (name in tilesetManager.tilesets.keys()) {
                var ts = tilesetManager.tilesets.get(name);
                tilesetsArray.push({ name: ts.name, texturePath: ts.texturePath });
            }

            // Entity definitions
            var entitiesArray:Array<Dynamic> = [];
            for (name in entityManager.entityDefinitions.keys()) {
                var def = entityManager.getEntityDefinition(name);
                entitiesArray.push({
                    name:         def.name,
                    width:        def.width,
                    height:       def.height,
                    tilesetName:  def.tilesetName,
                    regionX:      def.regionX,
                    regionY:      def.regionY,
                    regionWidth:  def.regionWidth,
                    regionHeight: def.regionHeight,
                    pivotX:       def.pivotX,
                    pivotY:       def.pivotY
                });
            }

            var projectId:String = (_projectData != null && _projectData.projectId != null && _projectData.projectId != "")
                ? _projectData.projectId : UIDGenerator.generate();

            var data = {
                version:          "1.0",
                projectId:        projectId,
                projectName:      projectName != "" ? projectName : "Untitled",
                defaultTileSizeX: editorState.tileSizeX,
                defaultTileSizeY: editorState.tileSizeY,
                tilesets:         tilesetsArray,
                entityDefinitions: entitiesArray
            };

            var payload = {
                project: data
            };

            sys.io.File.saveContent(filePath, haxe.Json.stringify(payload, null, "  "));

            // Update editor-level project metadata only.
            // state.projectFilePath is map-level — not touched here.
            if (_projectData == null) {
                _projectData = {
                    projectFilePath:  filePath,
                    projectDir:     Path.directory(filePath),
                    projectId:        projectId,
                    projectName:      projectName,
                    defaultTileSizeX: editorState.tileSizeX,
                    defaultTileSizeY: editorState.tileSizeY
                };
            } else {
                _projectData.projectFilePath = filePath;
                _projectData.projectId       = projectId;
                _projectData.projectName     = projectName;
                _projectData.projectDir      = Path.directory(filePath);
            }

            app.log.info(LogCategory.APP, "Editor: Exported project '" + projectName + "' with " + entitiesArray.length + " entity definitions to: " + filePath);
            return true;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Error exporting project: " + e);
            return false;
        }
    }

    /**
     * Load entity definitions and tilesets from a project file (.hxproject).
     * Only one project may be active at a time: all existing EditorStates are
     * shut down before the new project is applied.  A single fresh blank state
     * is created so the renderer stays operational; maps are opened separately
     * via importMap / newEditorState, both of which inherit the project context
     * through applyProjectToState.
     * @param filePath  Absolute path to the .hxproject JSON file.
     * @return true on success, false on IO / parse error.
     */
    @:keep
    public static function importProject(filePath:String):Bool {
        try {
            var jsonString = app.loadBytes(filePath).toString();
            var data:Dynamic = haxe.Json.parse(jsonString);

            tilesetManager = new TilesetManager();
            entityManager  = new EntityManager();

            // Set the resource manager's base path to the project directory so tileset paths resolve correctly.
            var projectDir = Path.directory(filePath);
            app.resources.preDefinedPath = projectDir + "/res";

            // One blank state wired to the new managers — keeps the renderer alive.
            var blankState = new EditorState(app, tilesetManager, entityManager);
            app.addState(blankState);
            wireEditorStateCallbacks();

            var projectData:Dynamic;
            if (data.project != null) {
                projectData = data.project;
            } else {
                throw "Invalid project file: missing top-level 'project' object";
            }

            // Global tile size
            var tileSizeX = 16;
            var tileSizeY = 16;
            if (projectData.defaultTileSizeX != null && projectData.defaultTileSizeY != null) {
                tileSizeX = Std.int(projectData.defaultTileSizeX);
                tileSizeY = Std.int(projectData.defaultTileSizeY);
            }

            // Tilesets — one bad path must not abort the rest
            if (projectData.tilesets != null) {
                var tilesetsArray:Array<Dynamic> = projectData.tilesets;
                for (tilesetData in tilesetsArray) {
                    var name:String = tilesetData.name;
                    var path:String = tilesetData.texturePath;
                    var err = Editor.createTileset(path, name);
                        if (err == false) {
                            app.log.error(LogCategory.APP, "Editor: Warning — could not load tileset '" + name + "': " + err);
                        }
                }
            }

            // Entity definitions — written directly to shared EntityManager
            var entitiesLoaded = 0;
            if (projectData.entityDefinitions != null) {
                var entitiesArray:Array<Dynamic> = projectData.entityDefinitions;
                for (entityData in entitiesArray) {
                    var pivotX:Float = entityData.pivotX != null ? entityData.pivotX : 0.0;
                    var pivotY:Float = entityData.pivotY != null ? entityData.pivotY : 0.0;
                    entityManager.setEntityFull(
                        entityData.name,
                        entityData.width,       entityData.height,
                        entityData.tilesetName,
                        entityData.regionX,     entityData.regionY,
                        entityData.regionWidth, entityData.regionHeight,
                        pivotX, pivotY
                    );
                    entitiesLoaded++;
                }
            }

            // Persist project metadata and apply to the single blank state.
            var projectId:String = (projectData.projectId != null && Std.is(projectData.projectId, String) && cast(projectData.projectId, String) != "")
                ? cast(projectData.projectId, String) : UIDGenerator.generate();

            _projectData = {
                projectFilePath:  filePath,
                projectId:        projectId,
                projectDir:     Path.directory(filePath),
                projectName:      projectData.projectName != null ? projectData.projectName : "",
                defaultTileSizeX: tileSizeX,
                defaultTileSizeY: tileSizeY
            };
            applyProjectToState(blankState);

            app.log.info(LogCategory.APP, "Editor: Imported project '" + _projectData.projectName + "' with " + entitiesLoaded + " entity definitions from: " + filePath);
            return true;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Error importing project: " + e);
            return false;
        }
    }

    /**
     * Fill a ProjectProps struct with the current editor-level project metadata.
     * @return 1 if a project is loaded, 0 if not.
     */
    @:keep
    public static function getProjectProps(outProps:Pointer<ProjectProps>):Bool {
        if (_projectData == null) return false;

        var ref:Reference<ProjectProps> = outProps.ref;
        var fp:String = _projectData.projectFilePath != null ? _projectData.projectFilePath : "";
        var pid:String = _projectData.projectId != null ? _projectData.projectId : "";
        var pn:String = _projectData.projectName;
        var pd:String = _projectData.projectDir != null ? _projectData.projectDir : "";
        ref.filePath         = fp;
        ref.projectDir      = pd;
        ref.projectId        = pid;
        ref.projectName      = pn;
        ref.defaultTileSizeX = _projectData.defaultTileSizeX;
        ref.defaultTileSizeY = _projectData.defaultTileSizeY;
        return true;
    }

    /**
     * Update the editor-level project metadata from a ProjectProps struct.
     * Applies the new values to _projectData and re-applies project defaults
     * (e.g. tile size) to every currently active EditorState.
     * @return false if no project is loaded.
     */
    @:keep
    public static function editProject(inProps:Pointer<ProjectProps>):Bool {
        if (_projectData == null) return false;
        var ref:Reference<ProjectProps> = inProps.ref;
        var fp:String = ref.filePath;
        var pd:String = ref.projectDir;
        var pid:String = ref.projectId;
        var pn:String = ref.projectName;
        _projectData.projectFilePath  = fp != null && fp != "" ? fp : _projectData.projectFilePath;
        _projectData.projectDir       = pd != null && pd != "" ? pd : _projectData.projectDir;
        _projectData.projectId        = pid != null && pid != "" ? pid : _projectData.projectId;
        _projectData.projectName      = pn;
        _projectData.defaultTileSizeX = ref.defaultTileSizeX;
        _projectData.defaultTileSizeY = ref.defaultTileSizeY;

        // Save the edited project back to disk if the project path is set.
        if (_projectData.projectFilePath != null && _projectData.projectFilePath != "") {
            var saveName = _projectData.projectName != null ? _projectData.projectName : "";
            if (!exportProject(_projectData.projectFilePath, saveName)) {
                app.log.error(LogCategory.APP, "Editor: Failed to save project after edit: " + _projectData.projectFilePath);
                return false;
            }
        }

        // Re-apply project defaults to all active states.
        for (state in app.states) {
            applyProjectToState(cast state);
        }
        return true;
    }

    /**
     * Export the current tilemap to a JSON file
     * @param filePath Absolute path where to save the JSON file
     * @return true on success, false on error
     */
    @:keep
    public static function exportMap(filePath:String):Bool {
        try {
            var success = editorState.exportToJSON(filePath);

            if (success) {
                app.log.info(LogCategory.APP, "Editor: Exported map to: " + filePath);
            }
            return success;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Error exporting tilemap: " + e);
            return false;
        }
    }

    /**
     * Import tilemap from a JSON file into a brand-new EditorState.
     * The new state is registered with the app and made active.
     * @param filePath Absolute path to the JSON file
     * @return The index of the newly created state, or -1 on error
     */
    @:keep
    public static function importMap(filePath:String):Int {
        try {
            var jsonString = app.loadBytes(filePath).toString();
            var data:Dynamic = haxe.Json.parse(jsonString);

            if (data.map == null) {
                app.log.error(LogCategory.APP, "Editor: Invalid map JSON: missing top-level 'map' object");
                return -1;
            }

            var mapContent:Dynamic = data.map;
            if (mapContent == null) {
                app.log.error(LogCategory.APP, "Editor: Invalid map JSON: 'map' object is null");
                return -1;
            }

            // ** Project handling
            var mapProjectPath:String = null;
            if (mapContent.projectFile != null && Std.is(mapContent.projectFile, String)) {
                mapProjectPath = cast(mapContent.projectFile, String);
                if (mapProjectPath == "") mapProjectPath = null;
            }

            var mapProjectId:String = null;
            if (mapContent.projectId != null && Std.is(mapContent.projectId, String)) {
                mapProjectId = cast(mapContent.projectId, String);
                if (mapProjectId == "") mapProjectId = null;
            }

            var mapProjectName:String = null;
            if (mapContent.projectName != null && Std.is(mapContent.projectName, String)) {
                mapProjectName = cast(mapContent.projectName, String);
                if (mapProjectName == "") mapProjectName = null;
            }

            if (_projectData == null) {
                
                if (mapProjectPath != null) {
                    if (!sys.FileSystem.exists(mapProjectPath)) {
                        app.log.error(LogCategory.APP, "Editor: Map references missing project file: " + mapProjectPath);
                        return -1;
                    }

                    if (!importProject(mapProjectPath)) {
                        app.log.error(LogCategory.APP, "Editor: Failed to import referenced project: " + mapProjectPath);
                        return -1;
                    }

                    if (mapProjectId != null && _projectData != null && _projectData.projectId != mapProjectId) {
                        app.log.error(LogCategory.APP, "Editor: Map projectId does not match project file id");
                        return -1;
                    }

                    if (mapProjectName != null && _projectData != null && _projectData.projectName != mapProjectName) {
                        app.log.warn(LogCategory.APP, "Editor: Map projectName does not match project file name, using project file name");
                    }

                    // active state is created by importProject (blank state with project context)
                    if (editorState == null) {
                        app.log.error(LogCategory.APP, "Editor: No editor state available after importing project");
                        return -1;
                    }

                } else {
                    throw "Map JSON does not reference a project file";
                }

            } else {
                if (mapProjectId != null && _projectData.projectId != mapProjectId) {
                    app.log.error(LogCategory.APP, "Editor: Map projectId does not match active project id");
                    return -1;
                }
            }

            var newState = new EditorState(app, tilesetManager, entityManager);
            newState.projectFilePath = mapProjectPath;
            newState.projectId = mapProjectId;
            newState.projectName = mapProjectName;

            var index = app.addState(newState);
            wireEditorStateCallbacks();

            // Import map contents (layers, tiles, entity instances, etc.)
            var success = newState.importFromJSON(mapContent, filePath);
            if (success) {
                app.log.info(LogCategory.APP, "Editor: Imported map from: " + filePath);
            }

            app.switchToState(newState);

            return index;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Error importing tilemap: " + e);
            return -1;
        }
    }

    @:keep
	public static function getMapProps(outInfo:Pointer<MapProps>):Bool {
        var error:String = null;

		try {
			var ref:Reference<MapProps> = outInfo.ref;
			ref.idd = editorState.iid;
			ref.name = editorState.name;
			ref.worldx = Std.int(editorState.mapX);
			ref.worldy = Std.int(editorState.mapY);
			ref.width = Std.int(editorState.mapWidth);
			ref.height = Std.int(editorState.mapHeight);
			ref.tileSizeX = editorState.tileSizeX;
			ref.tileSizeY = editorState.tileSizeY;
			ref.bgColor = editorState.grid.backgroundColor.hexValue;
			ref.gridColor = editorState.grid.gridColor.hexValue;
			ref.projectFilePath = editorState.projectFilePath != null ? editorState.projectFilePath : "";
			ref.projectId       = editorState.projectId       != null ? editorState.projectId       : "";
			ref.projectName     = editorState.projectName     != null ? editorState.projectName     : "";
		} catch (e:Dynamic) {
			error = "Editor: Failed to get map properties: " + e;
            app.log.error(LogCategory.APP, error);
			return false;
		}

		return true;
	}

    @:keep
    public static function setMapProps(info:Pointer<MapProps>):Bool {
        var error:String = null;

        try {
            var ref:Reference<MapProps> = info.ref;
            editorState.grid.gridColor.hexValue = ref.gridColor;
            editorState.grid.backgroundColor.hexValue = ref.bgColor;
            if (ref.tileSizeX != editorState.tileSizeX || ref.tileSizeY != editorState.tileSizeY) {
                editorState.recalibrateTileSize(ref.tileSizeX, ref.tileSizeY);
            }
            var fp:String = ref.projectFilePath;
            editorState.projectFilePath = (fp != null && fp != "") ? fp : null;
            var pid:String = ref.projectId;
            editorState.projectId = (pid != null && pid != "") ? pid : null;
            var pn:String = ref.projectName;
            editorState.projectName = (pn != null && pn != "") ? pn : null;
        } catch (e:Dynamic) {
            error = "Editor: Failed to set map properties: " + e;
            app.log.error(LogCategory.APP, error);
            return false;
        }

        return true;
    }

    // ===== TEXTURE MANAGEMENT =====

    /**
     * Get texture data by resource path
     * @param path Resource path (e.g., "textures/myTexture.tga")
     * @param outData Pointer to TextureDataStruct to fill
     */
    @:keep
    public static function getTextureData(path:String, outData:Pointer<TextureDataStruct>):Void {
        var textureData:TextureData = app.resources.getTexture(path);
        if (textureData == null) {
            log("Editor: Texture not found: " + path);
            return;
        }

        var ref:Reference<TextureDataStruct> = outData.ref;
        ref.width = textureData.width;
        ref.height = textureData.height;
            // take address of first byte; cast the element to cpp.UInt8 so
        // RawPointer<T> is instantiated with the correct type
        // reinterpret the UInt8Array as a generic ArrayBufferView to
        // access its underlying Bytes buffer, then take the address of the
        // first element.  Cast to cpp.UInt8 so the resulting pointer has the
        // correct element type.
        // allocate a C buffer and copy the texture bytes into it; this
        // avoids needing an l-value for the original array and sidesteps the
        // private field visibility entirely
        var len = textureData.bytes.length;
        if (len > 0) {
            ref.data = cast cpp.Stdlib.nativeMalloc(len);
            // copy each byte from the UInt8Array into the C buffer
            for (i in 0...len) {
                var v:Int = textureData.bytes.get(i);
                untyped __cpp__("((unsigned char*){0})[{1}] = {2};", ref.data, i, v);
            }
        } else {
            ref.data = null;
        }
        ref.bytesPerPixel = textureData.bytesPerPixel;
        ref.dataLength = textureData.bytes.length;
        ref.transparent = textureData.transparent ? 1 : 0;
    }

    // ===== TILESET MANAGEMENT =====

    @:keep public static function createTileset(relativePath:String, tilesetName:String):Bool {
        try {
            if (!app.resources.cached(relativePath)) {
                app.log.info(LogCategory.APP, "Loading texture: " + relativePath);
                app.resources.loadTexture(relativePath, true);
            }

            if (tilesetManager.exists(tilesetName)) {
                app.log.info(LogCategory.APP, "Tileset with the name " + tilesetName + " already exists");
                return true;
            }
            
            var glTexture:Texture = app.renderer.uploadTexture(app.resources.getTexture(relativePath));
            tilesetManager.setTileset(glTexture, tilesetName, relativePath);

        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Error creating tileset '" + tilesetName + "': " + e);
            return false;
        }

        return true;
    }

    @:keep public static function deleteTileset(name:String):Bool {
        // Remove from shared manager, then mark entity batches as missing in all states.
        // Entity definitions are intentionally kept so instances can be seen in the editor
        // as red silhouettes, and the definitions remain available for re-linking later.
        tilesetManager.deleteTileset(name);
        for (s in app.states) (cast s:EditorState).removeTilesetReferences(name);
        return true;
    }

	/**
	 * Get tileset information by name
	 * @param tilesetName Name of the tileset (e.g., "devTiles")
	 * @param outInfo Pointer to TilesetInfoStruct to fill
	 * @return 1 if successful, 0 if tileset not found
	 */
	@:keep
	public static function getTileset(tilesetName:String, outInfo:Pointer<TilesetInfoStruct>):Bool {
		if (tilesetManager == null)
			return false;
		var et = tilesetManager.getTilesetInfo(tilesetName);
		if (et == null) {
			log("Editor: Tileset not found: " + tilesetName);
			return false;
		}
		var ref:Reference<TilesetInfoStruct> = outInfo.ref;
		ref.name = et.name;
		ref.texturePath = et.texturePath;
		return true;
	}

    @:keep
    public static function getTilesetAt(index:Int, outInfo:Pointer<TilesetInfoStruct>):Bool {
        var et = tilesetManager != null ? tilesetManager.getTilesetInfoAt(index) : null;
        if (et == null) { log("Editor: Tileset not found at index: " + index); return false; }
        var ref:Reference<TilesetInfoStruct> = outInfo.ref;
        ref.name = et.name;
        ref.texturePath = et.texturePath;
        return true;
    }

    /**
     * Get the count of loaded tilesets
     * @return Number of tilesets loaded
     */
    @:keep
    public static function getTilesetCount():Int {
        return tilesetManager != null ? tilesetManager.getTilesetCount() : 0;
    }

    /**
     * Set the current active tileset for drawing
     * @param tilesetName Name of the tileset to make active
     * @return 1 if tileset was found and set, 0 otherwise
     */
    @:keep
    public static function setActiveTileset(tilesetName:String):Bool {
        return editorState.tilesetManager.setActiveTileset(tilesetName);
    }

    
    @:keep
    public static function getActiveTile():Int {
        return editorState.getActiveTile();
    }

    @:keep
    public static function setActiveTile(tileRegionId:Int):Void {
        editorState.setActiveTile(tileRegionId);
    }

    // ===== ENTITY DEFINITIONS =====

    @:keep
    public static function createEntityDef(entityName:String, data:Pointer<EntityDataStruct>):Bool {
        var ref:Reference<EntityDataStruct> = data.ref;
        var tilesetName:String = ref.tilesetName;

        if (entityManager.exists(entityName)) {
            app.log.error(LogCategory.APP, "Cannot create entity '" + entityName + "': definition already exists");
            return false;
        }

        var rX = ref.regionX;
        var rY = ref.regionY;
        var rW = ref.regionWidth;
        var rH = ref.regionHeight;
        if (tilesetName == null || tilesetName == "") {
            rX = 0;
            rY = 0;
            rW = ref.width;
            rH = ref.height;
        }

        entityManager.setEntityFull(
            entityName,
            ref.width, ref.height,
            tilesetName,
            rX, rY, rW, rH,
            ref.pivotX, ref.pivotY
        );

        return true;
    }

    @:keep
    public static function editEntityDef(entityName:String, data:Pointer<EntityDataStruct>):Bool {
        var ref:Reference<EntityDataStruct> = data.ref;
        var tilesetName:String = ref.tilesetName;
        // tilesetName null/empty means "no tileset" — allowed.
        // Non-null/empty names must exist in the manager.
        if (tilesetName != null && tilesetName != "" && !tilesetManager.exists(tilesetName)) {
            app.log.error(LogCategory.APP, "Cannot edit entity '" + entityName + "': tileset '" + tilesetName + "' does not exist");
            return false;
        }
        // Update the shared manager record.
        // When there's no tileset, use the entity's own dimensions as the render region
        // so the red silhouette is sized correctly.
        var rX = ref.regionX; var rY = ref.regionY; var rW = ref.regionWidth; var rH = ref.regionHeight;
        if (tilesetName == null || tilesetName == "") { rX = 0; rY = 0; rW = ref.width; rH = ref.height; }
        entityManager.setEntityFull(entityName, ref.width, ref.height, tilesetName,
            rX, rY, rW, rH,
            ref.pivotX, ref.pivotY);
        // Refresh placed entity instances in every state
        var def = entityManager.getEntityDefinition(entityName);
        // ts will be null when tilesetName is null/empty — applyDefinitionUpdate handles this
        // by migrating instances to the orphan batch.
        var ts = (tilesetName != null && tilesetName != "") ? tilesetManager.getTilesetInfo(tilesetName) : null;
        for (s in app.states) {
            var state:EditorState = cast s;
            var programInfo = app.renderer.getProgramInfo("texture");
            var allEntityLayers:Array<layers.EntityLayer> = [];
            @:privateAccess state.collectEntityLayers(state.entities, allEntityLayers);
            for (el in allEntityLayers) el.applyDefinitionUpdate(def, ts, app.renderer, programInfo);
        }
        return true;
    }

    @:keep
    public static function deleteEntityDef(entityName:String):Bool {
        if (entityManager == null || !entityManager.exists(entityName)) {
            app.log.error(LogCategory.APP, "Cannot delete entity '" + entityName + "': definition does not exist");
            return false;
        }
        // Remove placed instances from all states, then delete from shared manager
        for (s in app.states) (cast s:EditorState).removeEntityInstances(entityName);
        entityManager.deleteEntityDefinition(entityName);
        return true;
    }

    @:keep
    public static function getEntityDef(entityName:String, outData:Pointer<EntityDataStruct>):Bool {
        var entityDef = entityManager != null ? entityManager.getEntityDefinition(entityName) : null;
        if (entityDef == null) {
            var error = "Editor: No entity definition found: " + entityName;
            app.log.warn(LogCategory.APP, error);
            return false;
        }
        try { populateEntityDataStruct(entityDef, outData); }
        catch (e:Dynamic) {
            var error = "Editor: Failed to retrieve data for entity '" + entityName + "': " + e;
            app.log.error(LogCategory.APP, error);
            return false;
        }
        return true;
    }

    @:keep
    public static function getEntityDefAt(index:Int, outData:Pointer<EntityDataStruct>):Bool {
        var entityDef = entityManager != null ? entityManager.getEntityDefinitionAt(index) : null;
        if (entityDef == null) {
            var error = "Editor: No entity definition found at index: " + index;
            app.log.warn(LogCategory.APP, error);
            return false;
        }
        try { populateEntityDataStruct(entityDef, outData); }
        catch (e:Dynamic) {
            var error = "Editor: Failed to retrieve data for entity at index '" + index + "': " + e;
            app.log.error(LogCategory.APP, error);
            return false;
        }
        return true;
    }

    @:keep
    public static function getEntityDefCount():Int {
        return entityManager != null ? entityManager.getEntityDefinitionCount() : 0;
    }

    @:keep
    public static function setActiveEntityDef(entityName:String):Bool {
        return editorState.setActiveEntity(entityName);
    }

    @:keep @:noExport
    public static function populateEntityDataStruct(entityDef:EntityDefinition, outData:Pointer<EntityDataStruct>):Void {
        var ref:Reference<EntityDataStruct> = outData.ref;
		ref.name = entityDef.name;
		ref.width = entityDef.width;
		ref.height = entityDef.height;
		ref.tilesetName = entityDef.tilesetName;
		ref.regionX = entityDef.regionX;
		ref.regionY = entityDef.regionY;
		ref.regionWidth = entityDef.regionWidth;
		ref.regionHeight = entityDef.regionHeight;
		ref.pivotX = entityDef.pivotX;
		ref.pivotY = entityDef.pivotY;
    }

    // ===== ENTITY SELECTION & TOOLS =====

    @:keep
    public static function getEntitySelectionCount():Int {
        return editorState.selectedEntities.length;
    }

    @:keep
    public static function getEntitySelectionInfo(index:Int, outData:cpp.Pointer<EntityStruct>):Bool {
        if (index < 0 || index >= editorState.selectedEntities.length) return false;
        var ent = editorState.selectedEntities[index];
        var ref:cpp.Reference<EntityStruct> = outData.ref;
        var entUid:String = ent.uid;
        untyped __cpp__("{0}.uid = {1}.__s", ref, entUid);
        var entName:String = ent.name;
        untyped __cpp__("{0}.name = {1}.__s", ref, entName);
        ref.x = Std.int(ent.x);
        ref.y = Std.int(ent.y);
        ref.width = Std.int(ent.width);
        ref.height = Std.int(ent.height);
        return true;
    }

    @:keep
    public static function selectEntityByUID(uid:String):Bool {
        return editorState.selectEntityByUID(uid);
    }

    @:keep
    public static function selectEntityInLayerByUID(layerName:String, uid:String):Bool {
        return editorState.selectEntityInLayerByUID(layerName, uid);
    }

    @:keep
    public static function deselectEntity():Void {
        editorState.deselectEntity();
    }

    // ===== LAYER MANAGEMENT =====

    @:keep
    public static function createTilemapLayer(layerName:String, tilesetName:String, tileSize:Int, index:Int = -1):Bool {
        return editorState.createTilemapLayer(layerName, tilesetName, index, tileSize) != null;
    }

    @:keep
    public static function createEntityLayer(layerName:String):Void {
        editorState.createEntityLayer(layerName);
    }

    @:keep
    public static function createFolderLayer(layerName:String):Void {
        editorState.createFolderLayer(layerName);
    }

    @:keep
    public static function getLayerCount():Int {
        return editorState.getLayerCount();
    }

    @:keep
    public static function getLayerInfo(layerName:String, outInfo:Pointer<LayerInfoStruct>):Bool {
		var layer = editorState.getLayerByName(layerName);
        var type:Int = 0;
        var tilesetName:String = "";
        var tileSize:Int = 0;
		if (layer == null) {
			app.log.error(LogCategory.APP, "Editor: Layer not found: " + layerName);
			return false;
		}

		//Determine layer type
		if (Std.isOfType(layer, layers.TilemapLayer)) {
			type = 0;
			var tilemapLayer:layers.TilemapLayer = cast layer;
			tilesetName = tilemapLayer.editorTexture.name;
			tileSize = tilemapLayer.tileSize;
		} else if (Std.isOfType(layer, layers.EntityLayer)) {
			type = 1;
			var entityLayer:layers.EntityLayer = cast layer;
            if (entityLayer.batches != null && entityLayer.batches.length > 0) {
                var firstEntry = entityLayer.batches[0];
                if (firstEntry.editorTexture != null)
                    tilesetName = firstEntry.editorTexture.name;
            }
        }

        // write result into the C struct via the pointer reference
        var ref:Reference<LayerInfoStruct> = outInfo.ref;
        ref.name = layer.id;
        ref.type = type; // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
        ref.tilesetName = tilesetName;
        ref.tileSize = tileSize;
        ref.visible = layer.visible ? 1 : 0;
        ref.silhouette = layer.silhouette;
        ref.silhouetteColor = layer.silhouetteColor.hexValue;
        return true;
    }

    @:keep
	public static function getLayerInfoAt(index:Int, outInfo:Pointer<LayerInfoStruct>):Bool {
		var layer = editorState.getLayerAt(index);
        var type:Int = 0;
        var tilesetName:String = "";
        var tileSize:Int = 0;

		if (layer == null) {
			app.log.error(LogCategory.APP, "Editor: No layer found at index: " + index);
			return false;
		}

		// Determine layer type
		if (Std.isOfType(layer, layers.TilemapLayer)) {
			type = 0;
			var tilemapLayer:layers.TilemapLayer = cast layer;
			tilesetName = tilemapLayer.editorTexture.name;
			tileSize = tilemapLayer.tileSize;
		} else if (Std.isOfType(layer, layers.EntityLayer)) {
			type = 1;
			var entityLayer:layers.EntityLayer = cast layer;
            if (entityLayer.batches != null && entityLayer.batches.length > 0) {
                var firstEntry = entityLayer.batches[0];
                if (firstEntry.editorTexture != null)
                    tilesetName = firstEntry.editorTexture.name;
            }
        }

        // write result into the C struct via the pointer reference
        var ref:Reference<LayerInfoStruct> = outInfo.ref;
        ref.name = layer.id;
        ref.type = type; // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
        ref.tilesetName = tilesetName;
        ref.tileSize = tileSize;
        ref.visible = layer.visible ? 1 : 0;
        ref.silhouette = layer.silhouette;
        ref.silhouetteColor = layer.silhouetteColor.hexValue;
        return true;
    }

    @:keep
	public static function replaceLayerTileset(layerName:String, newTilesetName:String):Bool {
		return editorState.replaceLayerTileset(layerName, newTilesetName);
	}

    @:keep
    public static function setActiveLayer(layerName:String):Bool {
        return editorState.setActiveLayer(layerName);
    }

    @:keep
    public static function setActiveLayerAt(index:Int):Bool {
        return editorState.setActiveLayerAt(index);
    }

    @:keep
    public static function setLayerProperties(layerName:String, properties:Pointer<LayerInfoStruct>):Bool {
        var ref:Reference<LayerInfoStruct> = properties.ref;
        try {
	        editorState.setLayerProperties(layerName, ref.name, ref.type, ref.tilesetName, ref.visible != 0, ref.silhouette, ref.silhouetteColor);
            return true;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Failed to set layer properties for layer: " + layerName + " - " + e);
            return false;
        }
	}

	@:keep
	public static function setLayerPropertiesAt(index:Int, properties:Pointer<LayerInfoStruct>):Bool {
        var ref:Reference<LayerInfoStruct> = properties.ref;
        try {
		    editorState.setLayerPropertiesAt(index, ref.name, ref.type, ref.tilesetName, ref.visible != 0, ref.silhouette, ref.silhouetteColor);
            return true;
        } catch (e:Dynamic) {
            app.log.error(LogCategory.APP, "Editor: Failed to set layer properties at index: " + index + " - " + e);
            return false;
        }
    }

    @:keep
    public static function removeLayer(layerName:String):Bool {
        return editorState.removeLayer(layerName);
    }

    @:keep
    public static function removeLayerByIndex(index:Int):Bool {
        return editorState.removeLayerByIndex(index);
    }

    @:keep
    public static function moveLayerUp(layerName:String):Bool {
        return editorState.moveLayerUp(layerName);
    }

    @:keep
    public static function moveLayerDown(layerName:String):Bool {
        return editorState.moveLayerDown(layerName);
    }

    @:keep
    public static function moveLayerTo(layerName:String, newIndex:Int):Bool {
        return editorState.moveLayerTo(layerName, newIndex);
    }

    @:keep
    public static function moveLayerUpByIndex(index:Int):Bool {
       return editorState.moveLayerUpByIndex(index);
    }

    @:keep
    public static function moveLayerDownByIndex(index:Int):Bool {
        return editorState.moveLayerDownByIndex(index);
    }

    // ===== Batch management =====

    @:keep
    public static function getEntityLayerBatchCount(layerName:String):Int {
        var layer = editorState.getLayerByName(layerName);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return 0;
        return (cast layer:layers.EntityLayer).getBatchCount();
    }

    @:keep
    public static function getEntityLayerBatchCountAt(index:Int):Int {
        var layer = editorState.getLayerAt(index);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return 0;
        return (cast layer:layers.EntityLayer).getBatchCount();
    }

    @:keep
    public static function getEntityLayerBatchTilesetName(layerName:String, batchIndex:Int):String {
        var layer = editorState.getLayerByName(layerName);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return "";
        var entry = (cast layer:layers.EntityLayer).getBatchEntryAt(batchIndex);
        if (entry == null) return "";
        return entry.editorTexture != null ? entry.editorTexture.name : "";
    }

    @:keep
    public static function getEntityLayerInstanceCount(layerName:String, batchIndex:Int):Int {
        var layer = editorState.getLayerByName(layerName);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return 0;
        var entityLayer:layers.EntityLayer = cast layer;
        if (batchIndex == -1) return entityLayer.getEntityCount();
        var entry = entityLayer.getBatchEntryAt(batchIndex);
        if (entry == null) return 0;
        return Lambda.count(entry.entities);
    }

    @:keep
    public static function getEntityLayerInstanceAt(layerName:String, batchIndex:Int, instanceIndex:Int, outData:cpp.Pointer<EntityStruct>):Int {
        var layer = editorState.getLayerByName(layerName);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return 0;
        var entityLayer:layers.EntityLayer = cast layer;

        // Collect the target entity by walking batches up to instanceIndex
        var counter = 0;
        var found:layers.EntityLayer.Entity = null;
        if (batchIndex == -1) {
            var done = false;
            for (entry in entityLayer.batches) {
                if (done) break;
                for (ent in entry.entities) {
                    if (counter == instanceIndex) { found = ent; done = true; break; }
                    counter++;
                }
            }
        } else {
            var entry = entityLayer.getBatchEntryAt(batchIndex);
            if (entry == null) return 0;
            for (ent in entry.entities) {
                if (counter == instanceIndex) { found = ent; break; }
                counter++;
            }
        }

        if (found == null) return 0;
        var ref:cpp.Reference<EntityStruct> = outData.ref;
        var entUid:String = found.uid;
        untyped __cpp__("{0}.uid = {1}.__s", ref, entUid);
        var entName:String = found.name;
        untyped __cpp__("{0}.name = {1}.__s", ref, entName);
        ref.x = Std.int(found.x);
        ref.y = Std.int(found.y);
        ref.width = Std.int(found.width);
        ref.height = Std.int(found.height);
        return 1;
    }

    @:keep
    public static function moveEntityLayerBatchUp(layerName:String, batchIndex:Int):Bool {
        return editorState.moveEntityLayerBatchUp(layerName, batchIndex);
    }

    @:keep
    public static function moveEntityLayerBatchDown(layerName:String, batchIndex:Int):Bool {
        return editorState.moveEntityLayerBatchDown(layerName, batchIndex);
    }

    @:keep
    public static function moveEntityLayerBatchTo(layerName:String, batchIndex:Int, newIndex:Int):Bool {
        return editorState.moveEntityLayerBatchTo(layerName, batchIndex, newIndex);
    }

    @:keep
    public static function moveEntityLayerBatchUpByIndex(layerIndex:Int, batchIndex:Int):Bool {
        return editorState.moveEntityLayerBatchUpByLayerIndex(layerIndex, batchIndex);
    }

    @:keep
    public static function moveEntityLayerBatchDownByIndex(layerIndex:Int, batchIndex:Int):Bool {
        return editorState.moveEntityLayerBatchDownByLayerIndex(layerIndex, batchIndex);
    }

    @:keep
    public static function moveEntityLayerBatchToByIndex(layerIndex:Int, batchIndex:Int, newIndex:Int):Bool {
        return editorState.moveEntityLayerBatchToByLayerIndex(layerIndex, batchIndex, newIndex);
    }

    @:keep
    public static function setToolType(toolType:Int):Void {
        editorState.toolType = toolType;
    }

    @:keep
    public static function getToolType():Int {
        return editorState.toolType;
    }

    @:keep
    public static function toggleLabels(enable:Bool):Void {
        editorState.toggleLabels(enable);
    }
}
