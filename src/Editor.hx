package;

import data.TextureData;
import display.Tile;
import Log.LogCategory;
import states.EditorState;
import math.Vec2;
import layers.TilemapLayer;
import struct.MapProps;
import struct.EntityDataStruct;
import struct.EntityStruct;
import struct.TextureDataStruct;
import struct.TilesetInfoStruct;
import struct.LayerInfoStruct;
import cpp.Pointer;
import cpp.Reference;

@:headerCode('#include "editor_native.h"')
@:build(macro.NativeExportMacro.build())

class Editor {

    private static var app:App = null;
    private static var initialized:Bool = false;
    private static var editorState:states.EditorState = null; // Store reference to editor state
    
    public static function main():Void {
    }
    
    // Custom log function that uses SDL logging (forwarded to C# via CustomLogOutput)
    private static function log(msg:String):Void {
        untyped __cpp__("SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, \"%s\", {0})", msg);
    }
    
    /**
     * Initialize the engine
     * @return 1 on success, 0 on failure
     */
    @:keep @:noExport
    public static function init():Int {
        if (initialized) {
            log("Engine already initialized");
            return 1;
        }
        
        try {
            log("Editor: Initializing engine...");
            app = new App();
            if (!app.init()) {
                log("Editor: App.init() failed");
                return 0;
            }
            
            // Load the font baker state
            editorState = new EditorState(app);
            app.addState(editorState);
            wireEditorStateCallbacks();
            app.log.info(1, "EditorState loaded");
            
            initialized = true;
            log("Engine initialized successfully");

            return 1;
        } catch (e:Dynamic) {
            //log("Editor: Init error: " + e);
            // TODO: Better error handling to C# on exceptions
            app.log.error(Log.LogCategory.SYSTEM, "Editor: Init error: " + e);
            return 0;
        }
    }
    
    /**
     * Run one frame update
     * @param deltaTime Time since last frame in seconds
     */
    @:keep
    public static function updateFrame(deltaTime:Float):Void {
        if (app == null || !initialized) {
            log("Editor: Cannot update - engine not initialized");
            return;
        }
        
        try {
            // Process events and update frame
            app.processEvents();
            app.updateFrame(deltaTime);
        } catch (e:Dynamic) {
            log("Editor: Update error: " + e);
        }
    }
    
    /**
     * Render one frame
     */
    @:keep
    public static function render():Void {
        if (app == null || !initialized) {
            log("Editor: Cannot render - engine not initialized");
            return;
        }
        
        try {
            app.renderFrame();
        } catch (e:Dynamic) {
            log("Editor: Render error: " + e);
            #if cpp
            var stack = haxe.CallStack.exceptionStack();
            log("Stack trace:");
            for (item in stack) {
                log("  " + haxe.CallStack.toString([item]));
            }
            #end
        }
    }
    
    /**
     * Swap window buffers (present frame)
     */
    @:keep
    public static function swapBuffers():Void {
        if (app != null && initialized) {
            app.swapBuffers();
        }
    }
    
    /**
     * Release/cleanup engine resources
     */
    @:keep
    public static function release():Void {
        log("Editor: Releasing engine resources...");
        if (app != null) {
            app.release();
            log("Editor: Engine resources released");
            app = null;
            initialized = false;
        }
    }
    
    /**
     * Load a game state by ID
     * @param stateId State identifier (0 = FontBakerState)
     * @return 1 on success, 0 on failure
     */
    @:keep
    public static function loadState(stateId:Int):Int {
        if (app == null || !initialized) {
            log("Editor: Engine not initialized");
            return 0;
        }
        
        try {
            log("Editor: Loading state " + stateId);
            switch (stateId) {
                case 0: 
                    editorState = new EditorState(app);
                    app.addState(editorState);
                    wireEditorStateCallbacks();
                    log("Editor: EditorState loaded");
                default: 
                    log("Editor: Unknown state ID: " + stateId);
                    return 0;
            }
            return 1;
        } catch (e:Dynamic) {
            log("Editor: LoadState error: " + e);
            return 0;
        }
    }
    
    /**
     * Check if engine is running
     * @return 1 if running, 0 if stopped
     */
    @:keep
    public static function isRunning():Int {
        if (app != null && initialized) {
            return app.active ? 1 : 0;
        }
        return 0;
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
    
    /**
     * Set window size
     */
    @:keep
    public static function setWindowSize(width:Int, height:Int):Void {
        app.window.size = new Vec2(width, height);
    }
    
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
    
    @:keep
    public static function setWindowPosition(x:Int, y:Int):Void {
        app.window.setPosition(x, y);
    }

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
     * Get texture data by resource path
     * @param path Resource path (e.g., "textures/myTexture.tga")
     * @param outData Pointer to TextureDataStruct to fill
     */
    @:keep
    public static function getTextureData(path:String, outData:Pointer<TextureDataStruct>):Void {
        var textureData:TextureData = app.resources.getTexture(path, false);
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
    
    /**
     * Get tileset information by name
     * @param tilesetName Name of the tileset (e.g., "devTiles")
     * @param outInfo Pointer to TilesetInfoStruct to fill
     * @return 1 if successful, 0 if tileset not found
     */
    @:keep
    public static function getTileset(tilesetName:String, outInfo:Pointer<TilesetInfoStruct>):Int {

        var tilesetInfo:Tileset = editorState.tilesetManager.getTilesetInfo(tilesetName);
            
        if (tilesetInfo == null) {
            log("Editor: Tileset not found: " + tilesetName);
            return 0;
        }
        
        // copy values directly into the C struct via the pointer reference

        var ref:Reference<TilesetInfoStruct> = outInfo.ref;
        ref.name = tilesetInfo.name;
        ref.texturePath = tilesetInfo.texturePath;
        ref.tileSize = tilesetInfo.tileSize;
        ref.tilesPerRow = tilesetInfo.tilesPerRow;
        ref.tilesPerCol = tilesetInfo.tilesPerCol;
        ref.regionCount = tilesetInfo.tilesPerRow * tilesetInfo.tilesPerCol;

        return 1;
    }

    @:keep
    public static function getTilesetAt(index:Int, outInfo:Pointer<TilesetInfoStruct>):Int {
        if (app == null || !initialized) {
            log("Editor: Cannot get tileset - engine not initialized");
            return 0;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return 0;
        }
        
        try {
            var tilesetInfo:Tileset = editorState.tilesetManager.getTilesetInfoAt(index);
            
            if (tilesetInfo == null) {
                log("Editor: Tileset not found at index: " + index);
                return 0;
            }
            
            // copy values directly into the C struct via the pointer reference
            var name = tilesetInfo.name;
            var texturePath = tilesetInfo.texturePath;
            var tileSize = tilesetInfo.tileSize;
            var tilesPerRow = tilesetInfo.tilesPerRow;
            var tilesPerCol = tilesetInfo.tilesPerCol;
            var regionCount = tilesetInfo.tilesPerRow * tilesetInfo.tilesPerCol;

            var ref:Reference<TilesetInfoStruct> = outInfo.ref;
            ref.name = name;
            ref.texturePath = texturePath;
            ref.tileSize = tileSize;
            ref.tilesPerRow = tilesPerRow;
            ref.tilesPerCol = tilesPerCol;
            ref.regionCount = regionCount;

            log("Editor: Retrieved tileset at index " + index + ": " + name + " (" + tilesPerRow + "x" + tilesPerCol + " tiles)");
            return 1;
            
        } catch (e:Dynamic) {
            log("Editor: Error getting tileset at index " + index + ": " + e);
            return 0;
        }
    }

    @:keep
    public static function getActiveTile():Int {
        return editorState.getActiveTile();
    }
    
    @:keep
    public static function setActiveTile(tileRegionId:Int):Void {
        editorState.setActiveTile(tileRegionId);
    }

    @:keep
    public static function setToolType(toolType:Int):Void {
        editorState.toolType = toolType;
    }

    @:keep
    public static function getToolType():Int {
        return editorState.toolType;
    }

    @:noExport @:keep
    public static function wireEditorStateCallbacks():Void {
        editorState.onEntitySelectionChanged = function() {
            untyped __cpp__("if (g_entitySelectionChangedCallback) g_entitySelectionChangedCallback()");
        };
    }

    @:keep
    public static function getEntitySelectionCount():Int {
        return editorState.selectedEntities.length;
    }

    @:keep
    public static function getEntitySelectionInfo(index:Int, outData:cpp.Pointer<EntityStruct>):Int {
        if (index < 0 || index >= editorState.selectedEntities.length) return 0;
        var ent = editorState.selectedEntities[index];
        var ref:cpp.Reference<EntityStruct> = outData.ref;
        var entName:String = ent.name;
        untyped __cpp__("{0}.name = {1}.__s", ref, entName);
        ref.x = Std.int(ent.x);
        ref.y = Std.int(ent.y);
        ref.width = Std.int(ent.width);
        ref.height = Std.int(ent.height);
        return 1;
    }
    
    /**
     * Export the current tilemap to a JSON file
     * @param filePath Absolute path where to save the JSON file
     * @return Number of tiles exported, or -1 on error
     */
    @:keep
    public static function exportMap(filePath:String):Int {
        if (app == null || !initialized) {
            log("Editor: Cannot export tilemap - engine not initialized");
            return -1;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return -1;
        }
        
        try {
            var tileCount = editorState.exportToJSON(filePath);
            if (tileCount >= 0) {
                log("Editor: Exported " + tileCount + " tiles to: " + filePath);
            } else {
                log("Editor: Failed to export tilemap");
            }
            return tileCount;
        } catch (e:Dynamic) {
            log("Editor: Error exporting tilemap: " + e);
            return -1;
        }
    }
    
    /**
     * Import tilemap from a JSON file
     * @param filePath Absolute path to the JSON file
     * @return Number of tiles imported, or -1 on error
     */
    @:keep
    public static function importMap(filePath:String):Int {
        if (app == null || !initialized) {
            log("Editor: Cannot import tilemap - engine not initialized");
            return -1;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return -1;
        }
        
        try {
            var tileCount = editorState.importFromJSON(filePath);
            if (tileCount >= 0) {
                log("Editor: Imported " + tileCount + " tiles from: " + filePath);
            } else {
                log("Editor: Failed to import tilemap");
            }
            return tileCount;
        } catch (e:Dynamic) {
            log("Editor: Error importing tilemap: " + e);
            return -1;
        }
    }
    
    @:keep public static function createTileset(texturePath:String, tilesetName:String, tileSize:Int):String { 
        return editorState.createTileset(texturePath, tilesetName, tileSize);
    }
    
    /**
     * Get the count of loaded tilesets
     * @return Number of tilesets loaded
     */
    @:keep
    public static function getTilesetCount():Int {
        if (app == null || !initialized) {
            log("Editor: Cannot get tileset count - engine not initialized");
            return 0;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return 0;
        }
        
        try {
            return editorState.tilesetManager.getTilesetCount();
        } catch (e:Dynamic) {
            log("Editor: Error getting tileset count: " + e);
            return 0;
        }
    }
    
    /**
     * Set the current active tileset for drawing
     * @param tilesetName Name of the tileset to make active
     * @return 1 if tileset was found and set, 0 otherwise
     */
    @:keep
    public static function setActiveTileset(tilesetName:String):Int {
        if (app == null || !initialized) {
            log("Editor: Cannot set tileset - engine not initialized");
            return 0;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return 0;
        }
        
        try {
            var result = editorState.tilesetManager.setActiveTileset(tilesetName);
            if (result) {
                log("Editor: Active tileset set to: " + tilesetName);
                return 1;
            } else {
                log("Editor: Tileset not found: " + tilesetName);
                return 0;
            }
        } catch (e:Dynamic) {
            log("Editor: Error setting tileset: " + e);
            return 0;
        }
    }
    
    // ===== ENTITY DEFINITION MANAGEMENT =====
    
    @:keep
    public static function createEntityDef(entityName:String, width:Int, height:Int, tilesetName:String):String {
        return editorState.createEntity(entityName, width, height, tilesetName);
    }
    
    @:keep
    public static function getEntityDef(entityName:String, outData:Pointer<EntityDataStruct>):String {
        var error:String = null;
        var entityDef = editorState.entityManager.getEntityDefinition(entityName);
        if (entityDef == null) {
            error = "Editor: No entity definition found: " + entityName;
            app.log.warn(LogCategory.APP, error);
            return error;
        }

        try {
            populateEntityDataStruct(entityDef, outData);
        } catch (e:Dynamic) {
            error = "Editor: Failed to retrieve data for entity '" + entityName + "': " + e;
            app.log.error(LogCategory.APP, error);
        }

        return error;
    }
    
    @:keep
    public static function getEntityDefAt(index:Int, outData:Pointer<EntityDataStruct>):String {
        var error:String = null;
        var entityDef:EntityDefinition = editorState.entityManager.getEntityDefinitionAt(index);
        if (entityDef == null) {
            error = "Editor: No entity definition found at index: " + index;
            app.log.warn(LogCategory.APP, error);
            return error;
        }

       try {
            populateEntityDataStruct(entityDef, outData);
        } catch (e:Dynamic) {
            error = "Editor: Failed to retrieve data for entity at index '" + index + "': " + e;
            app.log.error(LogCategory.APP, error);
        }

        return error;
    }
    
    @:keep
    public static function getEntityDefCount():Int {
        return editorState.entityManager.getEntityDefinitionCount();
    }

    @:keep
    public static function setEntityDefRegion(entityName:String, x:Int, y:Int, width:Int, height:Int):Void {
        editorState.setEntityRegion(entityName, x, y, width, height);
    }
    
    @:keep
    public static function setActiveEntityDef(entityName:String):Int {
        return editorState.setActiveEntity(entityName) ? 1 : 0;
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
    }
    
    // ===== LAYER MANAGEMENT =====
    
    @:keep
    public static function createTilemapLayer(layerName:String, tilesetName:String, index:Int = -1):Void {
        editorState.createTilemapLayer(layerName, tilesetName, index);
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
    public static function setActiveLayer(layerName:String):Int {
        return editorState.setActiveLayer(layerName) ? 1 : 0;
    }

    @:keep
    public static function setActiveLayerAt(index:Int):Int {
        return editorState.setActiveLayerAt(index) ? 1 : 0;
    }
    
    @:keep
    public static function removeLayer(layerName:String):Int {
        return editorState.removeLayer(layerName) ? 1 : 0;
    }
    
    @:keep
    public static function removeLayerByIndex(index:Int):Int {
        return editorState.removeLayerByIndex(index) ? 1 : 0;
    }
    
    @:keep
    public static function moveLayerUp(layerName:String):Int {
        return editorState.moveLayerUp(layerName) ? 1 : 0;
    }
    
    @:keep
    public static function moveLayerDown(layerName:String):Int {
        return editorState.moveLayerDown(layerName) ? 1 : 0;
    }

    @:keep
    public static function moveLayerTo(layerName:String, newIndex:Int):Int {
        return editorState.moveLayerTo(layerName, newIndex) ? 1 : 0;
    }
    
    @:keep
    public static function moveLayerUpByIndex(index:Int):Int {
       return editorState.moveLayerUpByIndex(index) ? 1 : 0;
    }
    
    @:keep
    public static function moveLayerDownByIndex(index:Int):Int {
        return editorState.moveLayerDownByIndex(index) ? 1 : 0;
    }
    
    @:keep
    public static function getLayerCount():Int {
        return editorState.getLayerCount();
    }

    @:keep
	public static function getLayerInfoAt(index:Int, outInfo:Pointer<LayerInfoStruct>):Int {
		var layer = editorState.getLayerAt(index);
        var type:Int = 0;
        var tilesetName:String = "";

		if (layer == null) {
			log("Editor: Layer not found at index: " + index);
			return 0;
		}

		// Determine layer type
		if (Std.isOfType(layer, layers.TilemapLayer)) {
			type = 0;
			var tilemapLayer:layers.TilemapLayer = cast layer;
			tilesetName = tilemapLayer.tileset.name;
		} else if (Std.isOfType(layer, layers.EntityLayer)) {
			type = 1;
			var entityLayer:layers.EntityLayer = cast layer;
            if (entityLayer.batches != null && entityLayer.batches.length > 0) {
                tilesetName = entityLayer.batches[0].tileset.name;
            }
        }

        // write result into the C struct via the pointer reference
        var ref:Reference<LayerInfoStruct> = outInfo.ref;
        ref.name = layer.id;
        ref.type = type; // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
        ref.tilesetName = tilesetName;
        ref.visible = layer.visible ? 1 : 0;
        ref.silhouette = layer.silhouette;
        ref.silhouetteColor = layer.silhouetteColor.hexValue;
        return 1;
    }

    @:keep
    public static function getLayerInfo(layerName:String, outInfo:Pointer<LayerInfoStruct>):Int {
		var layer = editorState.getLayerByName(layerName);
        var type:Int = 0;
        var tilesetName:String = "";
		if (layer == null) {
			log("Editor: Layer not found: " + layerName);
			return 0;
		}

		//Determine layer type
		if (Std.isOfType(layer, layers.TilemapLayer)) {
			type = 0;
			var tilemapLayer:layers.TilemapLayer = cast layer;
			tilesetName = tilemapLayer.tileset.name;
		} else if (Std.isOfType(layer, layers.EntityLayer)) {
			type = 1;
			var entityLayer:layers.EntityLayer = cast layer;
            if (entityLayer.batches != null && entityLayer.batches.length > 0) {
                tilesetName = entityLayer.batches[0].tileset.name;
            }
        }

        // write result into the C struct via the pointer reference
        var ref:Reference<LayerInfoStruct> = outInfo.ref;
        ref.name = layer.id;
        ref.type = type; // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
        ref.tilesetName = tilesetName;
        ref.visible = layer.visible ? 1 : 0;
        ref.silhouette = layer.silhouette;
        ref.silhouetteColor = layer.silhouetteColor.hexValue;
        return 1;
    }
    
    @:keep
    public static function setLayerProperties(layerName:String, properties:Pointer<LayerInfoStruct>):Void {
        var ref:Reference<LayerInfoStruct> = properties.ref;
	    editorState.setLayerProperties(layerName, ref.name, ref.type, ref.tilesetName, ref.visible != 0, ref.silhouette, ref.silhouetteColor);
	}

	@:keep
	public static function setLayerPropertiesAt(index:Int, properties:Pointer<LayerInfoStruct>):Void {
        var ref:Reference<LayerInfoStruct> = properties.ref;
		editorState.setLayerPropertiesAt(index, ref.name, ref.type, ref.tilesetName, ref.visible != 0, ref.silhouette, ref.silhouetteColor);
	}

	@:keep
	public static function replaceLayerTileset(layerName:String, newTilesetName:String):Void {
		editorState.replaceLayerTileset(layerName, newTilesetName);
	}

    // ----- entity layer batch accessors -----
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
        return entry.tileset != null ? entry.tileset.name : "";
    }

    @:keep
    public static function moveEntityLayerBatchUp(layerName:String, batchIndex:Int):Int {
        return editorState.moveEntityLayerBatchUp(layerName, batchIndex) ? 1 : 0;
    }

    @:keep
    public static function moveEntityLayerBatchDown(layerName:String, batchIndex:Int):Int {
        return editorState.moveEntityLayerBatchDown(layerName, batchIndex) ? 1 : 0;
    }

    @:keep
    public static function moveEntityLayerBatchTo(layerName:String, batchIndex:Int, newIndex:Int):Int {
        return editorState.moveEntityLayerBatchTo(layerName, batchIndex, newIndex) ? 1 : 0;
    }

    @:keep
    public static function moveEntityLayerBatchUpByIndex(layerIndex:Int, batchIndex:Int):Int {
        return editorState.moveEntityLayerBatchUpByLayerIndex(layerIndex, batchIndex) ? 1 : 0;
    }

    @:keep
    public static function moveEntityLayerBatchDownByIndex(layerIndex:Int, batchIndex:Int):Int {
        return editorState.moveEntityLayerBatchDownByLayerIndex(layerIndex, batchIndex) ? 1 : 0;
    }

    @:keep
    public static function moveEntityLayerBatchToByIndex(layerIndex:Int, batchIndex:Int, newIndex:Int):Int {
        return editorState.moveEntityLayerBatchToByLayerIndex(layerIndex, batchIndex, newIndex) ? 1 : 0;
    }
    
	@:keep
	public static function getMapProps(outInfo:Pointer<MapProps>):String {
        var error:String = null;

		try {
			var ref:Reference<MapProps> = outInfo.ref;
			ref.idd = editorState.iid;
			ref.name = editorState.name;
			ref.worldx = Std.int(editorState.mapX);
			ref.worldy = Std.int(editorState.mapY);
			ref.width = Std.int(editorState.mapWidth);
			ref.height = Std.int(editorState.mapHeight);
			ref.tileSize = editorState.tileSize;
			ref.bgColor = editorState.grid.backgroundColor.hexValue;
			ref.gridColor = editorState.grid.gridColor.hexValue;
		} catch (e:Dynamic) {
			error = "Editor: Failed to get map properties: " + e;
            app.log.error(LogCategory.APP, error);
			return error;
		}

		return null;
	}

    @:keep
    public static function setMapProps(info:Pointer<MapProps>):String {
        var error:String = null;

        try {
            var ref:Reference<MapProps> = info.ref;
            editorState.grid.gridColor.hexValue = ref.gridColor; 
            editorState.grid.backgroundColor.hexValue = ref.bgColor;
        } catch (e:Dynamic) {
            error = "Editor: Failed to set map properties: " + e;
            app.log.error(LogCategory.APP, error);
        }

        return error;
    }
}
