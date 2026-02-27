package;

import data.TextureData;
import display.Tile;
import Log.LogCategory;
import states.EditorState;
import math.Vec2;
import layers.TilemapLayer;
import struct.MapProps;
import struct.EntityDataStruct;
import struct.TextureDataStruct;
import struct.TilesetInfoStruct;
import struct.LayerInfoStruct;
import cpp.Pointer;
import cpp.Reference;

@:headerCode('#include "editor_native.h"')
@:headerInclude("haxe/io/Bytes.h")
@:cppFileCode('
#include <SDL3/SDL_log.h>

bool hxcpp_initialized = false;
CustomCallback g_callback = nullptr;

void SDLCALL CustomLogOutput(void* userdata, int category, SDL_LogPriority priority, const char* message) {
    if (g_callback != nullptr) {
        char buffer[1024];
        snprintf(buffer, sizeof(buffer), "%s", message);
        g_callback(buffer);
    }
}

extern "C" {
    __declspec(dllexport) const char* HxcppInit() {
        if (hxcpp_initialized) {
            return NULL;  // Already initialized
        }
        
        const char* err = hx::Init();
        if (err == NULL) {
            hxcpp_initialized = true;
        }
        return err;
    }
    
    __declspec(dllexport) int init() {
        if (!hxcpp_initialized) {
            const char* err = hx::Init();
            if (err != NULL) return 0;
            hxcpp_initialized = true;
        }
        
        hx::NativeAttach attach;
        return ::Editor_obj::init();
    }
    
    __declspec(dllexport) int initWithCallback(CustomCallback callback) {
        if (callback != nullptr) {
            g_callback = callback;
            SDL_SetLogOutputFunction(CustomLogOutput, (void*)callback);
        }
        
        return init();
    }
    
    __declspec(dllexport) void updateFrame(float deltaTime) {
        ::Editor_obj::updateFrame(deltaTime);
    }
    
    __declspec(dllexport) void render() {
        ::Editor_obj::render();
    }
    
    __declspec(dllexport) void swapBuffers() {
        ::Editor_obj::swapBuffers();
    }
    
    __declspec(dllexport) void release() {
        ::Editor_obj::release();
    }
    
    __declspec(dllexport) void loadState(int stateIndex) {
        ::Editor_obj::loadState(stateIndex);
    }
    
    __declspec(dllexport) int isRunning() {
        return ::Editor_obj::engineIsRunning();
    }
    
    __declspec(dllexport) int getWindowWidth() {
        return ::Editor_obj::engineGetWindowWidth();
    }
    
    __declspec(dllexport) int getWindowHeight() {
        return ::Editor_obj::engineGetWindowHeight();
    }
    
    __declspec(dllexport) void setWindowSize(int width, int height) {
        ::Editor_obj::engineSetWindowSize(width, height);
    }
    
    __declspec(dllexport) void* getWindowHandle() {
        return ::Editor_obj::getWindowHandle();
    }
    
    __declspec(dllexport) void setWindowPosition(int x, int y) {
        ::Editor_obj::setWindowPosition(x, y);
    }
    
    __declspec(dllexport) void setWindowSizeAndBorderless(int width, int height) {
        ::Editor_obj::engineSetWindowSizeAndBorderless(width, height);
    }

    __declspec(dllexport) void onMouseMotion(int x, int y) {
        ::Editor_obj::onMouseMotion(x, y);
    }
    
    __declspec(dllexport) void onMouseButtonDown(int x, int y, int button) {
        ::Editor_obj::onMouseButtonDown(x, y, button);
    }

    __declspec(dllexport) void onMouseButtonUp(int x, int y, int button) {
        ::Editor_obj::onMouseButtonUp(x, y, button);
    }

    __declspec(dllexport) void onKeyboardDown(int keyCode) {
        ::Editor_obj::onKeyboardDown(keyCode);
    }

    __declspec(dllexport) void onKeyboardUp(int keyCode) {
        ::Editor_obj::onKeyboardUp(keyCode);
    }
    
    __declspec(dllexport) void getTextureData(const char* path, TextureDataStruct* outData) {
        ::Editor_obj::getTextureData(path, outData);
    }

    __declspec(dllexport) void setActiveTile(int tileRegionId) {
    ::Editor_obj::setActiveTile(tileRegionId);
    }
    
    __declspec(dllexport) int getActiveTile() {
        return ::Editor_obj::getActiveTile();
    }
    
    __declspec(dllexport) int exportMap(const char* filePath) {
        return ::Editor_obj::exportMap(::String(filePath));
    }
    
    __declspec(dllexport) int importMap(const char* filePath) {
        return ::Editor_obj::importMap(::String(filePath));
    }

    __declspec(dllexport) int getTileset(const char* tilesetName, TilesetInfoStruct* outInfo) {
        return ::Editor_obj::getTileset(::String(tilesetName), outInfo);
    }

    __declspec(dllexport) int getTilesetAt(int index, TilesetInfoStruct* outInfo) {
        return ::Editor_obj::getTilesetAt(index, outInfo);
    }
    
    __declspec(dllexport) const char* createTileset(const char* texturePath, const char* tilesetName, int tileSize) {
        return ::Editor_obj::createTileset(::String(texturePath), ::String(tilesetName), tileSize).__s;
    }
    
    __declspec(dllexport) int getTilesetCount() {
        return ::Editor_obj::getTilesetCount();
    }
    
    __declspec(dllexport) int setActiveTileset(const char* tilesetName) {
        return ::Editor_obj::setActiveTileset(::String(tilesetName));
    }
    
    // Layer management functions
    __declspec(dllexport) void createTilemapLayer(const char* layerName, const char* tilesetName, int index) {
        ::Editor_obj::createTilemapLayer(::String(layerName), ::String(tilesetName), index);
    }
    
    __declspec(dllexport) void createEntityLayer(const char* layerName) {
        ::Editor_obj::createEntityLayer(::String(layerName));
    }
    
    __declspec(dllexport) void createFolderLayer(const char* layerName) {
        ::Editor_obj::createFolderLayer(::String(layerName));
    }
    
    __declspec(dllexport) int setActiveLayer(const char* layerName) {
        return ::Editor_obj::setActiveLayer(::String(layerName));
    }
    
    __declspec(dllexport) int setActiveLayerAt(int index) {
        return ::Editor_obj::setActiveLayerAt(index);
    }
    
    __declspec(dllexport) int removeLayer(const char* layerName) {
        return ::Editor_obj::removeLayer(::String(layerName));
    }
    
    __declspec(dllexport) int removeLayerByIndex(int index) {
        return ::Editor_obj::removeLayerByIndex(index);
    }
    
    __declspec(dllexport) int getLayerCount() {
        return ::Editor_obj::getLayerCount();
    }
    
    __declspec(dllexport) int getLayerInfoAt(int index, LayerInfoStruct* outInfo) {
        return ::Editor_obj::getLayerInfoAt(index, outInfo);
    }
    
    __declspec(dllexport) int getLayerInfo(const char* layerName, LayerInfoStruct* outInfo) {
        ::String hxLayerName = ::String(layerName);
        return ::Editor_obj::getLayerInfo(hxLayerName, outInfo);
    }

    // entity layer batch accessors
    __declspec(dllexport) int getEntityLayerBatchCount(const char* layerName) {
        return ::Editor_obj::getEntityLayerBatchCount(::String(layerName));
    }

    __declspec(dllexport) int getEntityLayerBatchCountAt(int index) {
        return ::Editor_obj::getEntityLayerBatchCountAt(index);
    }

    __declspec(dllexport) const char* getEntityLayerBatchTilesetName(const char* layerName, int batchIndex) {
        return ::Editor_obj::getEntityLayerBatchTilesetName(::String(layerName), batchIndex).__s;
    }

    // batch movement wrappers
    __declspec(dllexport) int moveEntityLayerBatchUp(const char* layerName, int batchIndex) {
        return ::Editor_obj::moveEntityLayerBatchUp(::String(layerName), batchIndex);
    }

    __declspec(dllexport) int moveEntityLayerBatchDown(const char* layerName, int batchIndex) {
        return ::Editor_obj::moveEntityLayerBatchDown(::String(layerName), batchIndex);
    }

    __declspec(dllexport) int moveEntityLayerBatchTo(const char* layerName, int batchIndex, int newIndex) {
        return ::Editor_obj::moveEntityLayerBatchTo(::String(layerName), batchIndex, newIndex);
    }

    __declspec(dllexport) int moveEntityLayerBatchUpByIndex(int layerIndex, int batchIndex) {
        return ::Editor_obj::moveEntityLayerBatchUpByIndex(layerIndex, batchIndex);
    }

    __declspec(dllexport) int moveEntityLayerBatchDownByIndex(int layerIndex, int batchIndex) {
        return ::Editor_obj::moveEntityLayerBatchDownByIndex(layerIndex, batchIndex);
    }

    __declspec(dllexport) int moveEntityLayerBatchToByIndex(int layerIndex, int batchIndex, int newIndex) {
        return ::Editor_obj::moveEntityLayerBatchToByIndex(layerIndex, batchIndex, newIndex);
    }
    
    __declspec(dllexport) int moveLayerUp(const char* layerName) {
        return ::Editor_obj::moveLayerUp(::String(layerName));
    }
    
    __declspec(dllexport) int moveLayerDown(const char* layerName) {
        return ::Editor_obj::moveLayerDown(::String(layerName));
    }

    __declspec(dllexport) int moveLayerTo(const char* layerName, int newIndex) {
        return ::Editor_obj::moveLayerTo(::String(layerName), newIndex);
    }
    
    __declspec(dllexport) int moveLayerUpByIndex(int index) {
        return ::Editor_obj::moveLayerUpByIndex(index);
    }
    
    __declspec(dllexport) int moveLayerDownByIndex(int index) {
        return ::Editor_obj::moveLayerDownByIndex(index);
    }
    
    // Entity definition management
    __declspec(dllexport) const char* createEntityDef(const char* entityName, int width, int height, const char* tilesetName) {
        return ::Editor_obj::createEntityDef(::String(entityName), width, height, ::String(tilesetName)).__s;
    }
    
    __declspec(dllexport) void setEntityDefRegion(const char* entityName, int x, int y, int width, int height) {
        ::Editor_obj::setEntityDefRegion(::String(entityName), x, y, width, height);
    }
    
    __declspec(dllexport) const char* getEntityDef(const char* entityName, EntityDataStruct* outData) {
        return ::Editor_obj::getEntityDef(::String(entityName), outData).__s;
    }
    
    __declspec(dllexport) const char* getEntityDefAt(int index, EntityDataStruct* outData) {
        return ::Editor_obj::getEntityDefAt(index, outData).__s;
    }
    
    __declspec(dllexport) int getEntityDefCount() {
        return ::Editor_obj::getEntityDefCount();
    }
    
    __declspec(dllexport) int setActiveEntityDef(const char* entityName) {
        return ::Editor_obj::setActiveEntityDef(::String(entityName));
    }

    __declspec(dllexport) void setLayerProperties(const char* layerName, LayerInfoStruct* properties) {
        ::Editor_obj::setLayerProperties(::String(layerName), properties);
    }

    __declspec(dllexport) void setLayerPropertiesAt(int index, LayerInfoStruct* properties) {
        ::Editor_obj::setLayerPropertiesAt(index, properties);
    }

    __declspec(dllexport) void replaceLayerTileset(const char* layerName, const char* newTilesetName) {
        ::Editor_obj::replaceLayerTileset(::String(layerName), ::String(newTilesetName));
    }

    // MAP PROPERTIES

    __declspec(dllexport) const char* getMapProps(MapProps* outInfo) {
        return ::Editor_obj::getMapProps((cpp::Pointer<MapProps>)outInfo);
    }

    __declspec(dllexport) const char* setMapProps(MapProps* info) {
        return ::Editor_obj::setMapProps((cpp::Pointer<MapProps>)info);
    }
}')

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
    @:keep
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
    public static function engineIsRunning():Int {
        if (app != null && initialized) {
            return app.active ? 1 : 0;
        }
        return 0;
    }
    
    /**
     * Get window width
     */
    @:keep
    public static function engineGetWindowWidth():Int {
        if (app != null && initialized) {
            return app.WINDOW_WIDTH;
        }
        return 0;
    }
    
    /**
     * Get window height
     */
    @:keep
    public static function engineGetWindowHeight():Int {
        if (app != null && initialized) {
            return app.WINDOW_HEIGHT;
        }
        return 0;
    }
    
    /**
     * Set window size
     */
    @:keep
    public static function engineSetWindowSize(width:Int, height:Int):Void {
        if (app != null && initialized) {
            app.window.size = new Vec2(width, height);
        }
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
    
    /**
     * Set window position (screen coordinates)
     */
    @:keep
    public static function setWindowPosition(x:Int, y:Int):Void {
        if (app != null && initialized && app.window != null) {
            app.window.setPosition(x, y);
        }
    }
    
    /**
     * Set window size and make it borderless for embedding
     */
    @:keep
    public static function engineSetWindowSizeAndBorderless(width:Int, height:Int):Void {
        if (app != null && initialized && app.window != null) {
            //app.window.setSize(width, height);
            //app.window.setBorderless(true);
        }
    }

        @:keep
    public static function onMouseMotion(x:Int, y:Int):Void {
        if (app != null && initialized) {
            @:privateAccess app.onMouseMotion(x, y, 0, 0, 1);
        }
    }
    
    @:keep
    public static function onMouseButtonDown(x:Int, y:Int, button:Int):Void {
        if (app != null && initialized) {
            @:privateAccess app.onMouseButtonDown(x, y, button, 1);
        }
    }

    @:keep
    public static function onMouseButtonUp(x:Int, y:Int, button:Int):Void {
        if (app != null && initialized) {
            @:privateAccess app.onMouseButtonUp(x, y, button, 1);
        }
    }

    /**
     * Handle keyboard down event from C# host
     * @param scancode SDL scancode of the pressed key (from KeyMapper.ToSDLScancode)
     */
    @:keep
    public static function onKeyboardDown(scancode:Int):Void {
        if (app != null && initialized) {
            // Pass scancode as keycode since use_scancodes is not defined
            // and Keycode constants are actually scancode values
            @:privateAccess app.onKeyDown(scancode, scancode, false, 0, 1);
        }
    }

    /**
     * Handle keyboard up event from C# host
     * @param scancode SDL scancode of the released key (from KeyMapper.ToSDLScancode)
     */
    @:keep
    public static function onKeyboardUp(scancode:Int):Void {
        if (app != null && initialized) {
            // Pass scancode as keycode since use_scancodes is not defined
            // and Keycode constants are actually scancode values
            @:privateAccess app.onKeyUp(scancode, scancode, false, 0, 1);
        }
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

    @:keep
    public static function populateEntityDataStruct(entityDef:EntityDefinition, outData:Pointer<EntityDataStruct>):Void {
        var ref:Reference<EntityDataStruct> = outData.ref;
        ref.name        = entityDef.name;
        ref.width       = entityDef.width;
        ref.height      = entityDef.height;
        ref.tilesetName = entityDef.tilesetName;
        ref.regionX     = entityDef.regionX;
        ref.regionY     = entityDef.regionY;
        ref.regionWidth = entityDef.regionWidth;
        ref.regionHeight= entityDef.regionHeight;
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

    // movement helpers
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
        
        // var name:String = null;
        // var type:Int = 0;
        // var tilesetName:String = null;
        // var visible:Int = 1;
        // var silhouette:Int = 0;
        // var silhouetteColor:Int = 0xFFFFFFFF;

        // untyped __cpp__("
        // LayerInfoStruct* inStruct = (LayerInfoStruct*)({0});
        // {1} = ::String(inStruct->name);
        // {2} = inStruct->type;
        // {3} = ::String(inStruct->tilesetName);
        // {4} = inStruct->visible;
        // {5} = inStruct->silhouette;
        // {6} = inStruct->silhouetteColor;
        // ", properties, name, type, tilesetName, visible, silhouette, silhouetteColor);

	    editorState.setLayerProperties(layerName, ref.name, ref.type, ref.tilesetName, ref.visible != 0, ref.silhouette, ref.silhouetteColor);
	}

	@:keep
	public static function setLayerPropertiesAt(index:Int, properties:Pointer<LayerInfoStruct>):Void {
        var ref:Reference<LayerInfoStruct> = properties.ref;
        
        // var name:String = null;
        // var type:Int = 0;
        // var tilesetName:String = null;
        // var visible:Int = 1;
        // var silhouette:Int = 0;
        // var silhouetteColor:Int = 0xFFFFFFFF;

        // untyped __cpp__("
        // LayerInfoStruct* inStruct = (LayerInfoStruct*)({0});
        // {1} = ::String(inStruct->name);
        // {2} = inStruct->type;
        // {3} = ::String(inStruct->tilesetName);
        // {4} = inStruct->visible;
        // {5} = inStruct->silhouette;
        // {6} = inStruct->silhouetteColor;
        // ", properties, name, type, tilesetName, visible, silhouette, silhouetteColor);

		editorState.setLayerPropertiesAt(index, ref.name, ref.type, ref.tilesetName, ref.visible != 0, ref.silhouette, ref.silhouetteColor);

	}

	@:keep
	public static function replaceLayerTileset(layerName:String, newTilesetName:String):Void {
		editorState.replaceLayerTileset(layerName, newTilesetName);
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
