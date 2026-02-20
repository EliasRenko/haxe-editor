package;

import states.EditorState;
import math.Vec2;
import layers.TilemapLayer;

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
    
    __declspec(dllexport) void createEntityLayer(const char* layerName, const char* tilesetName) {
        ::Editor_obj::createEntityLayer(::String(layerName), ::String(tilesetName));
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
    
    __declspec(dllexport) const char* getLayerNameAt(int index) {
        return ::Editor_obj::getLayerNameAt(index).__s;
    }
    
    __declspec(dllexport) int getLayerInfoAt(int index, LayerInfoStruct* outInfo) {
        return ::Editor_obj::getLayerInfoAt(index, outInfo);
    }
    
    __declspec(dllexport) int getLayerInfo(const char* layerName, LayerInfoStruct* outInfo) {
        ::String hxLayerName = ::String(layerName);
        return ::Editor_obj::getLayerInfo(hxLayerName, outInfo);
    }
    
    __declspec(dllexport) int moveLayerUp(const char* layerName) {
        return ::Editor_obj::moveLayerUp(::String(layerName));
    }
    
    __declspec(dllexport) int moveLayerDown(const char* layerName) {
        return ::Editor_obj::moveLayerDown(::String(layerName));
    }
    
    __declspec(dllexport) int moveLayerUpByIndex(int index) {
        return ::Editor_obj::moveLayerUpByIndex(index);
    }
    
    __declspec(dllexport) int moveLayerDownByIndex(int index) {
        return ::Editor_obj::moveLayerDownByIndex(index);
    }
    
    // Entity definition management
    __declspec(dllexport) const char* createEntity(const char* entityName, int width, int height, const char* tilesetName) {
        return ::Editor_obj::createEntity(::String(entityName), width, height, ::String(tilesetName)).__s;
    }
    
    __declspec(dllexport) void setEntityRegion(const char* entityName, int x, int y, int width, int height) {
        ::Editor_obj::setEntityRegion(::String(entityName), x, y, width, height);
    }
    
    __declspec(dllexport) void getEntity(const char* entityName, EntityDataStruct* outData) {
        ::Editor_obj::getEntity(::String(entityName), outData);
    }
    
    __declspec(dllexport) void getEntityAt(int index, EntityDataStruct* outData) {
        ::Editor_obj::getEntityAt(index, outData);
    }
    
    __declspec(dllexport) int getEntityCount() {
        return ::Editor_obj::getEntityCount();
    }
    
    __declspec(dllexport) int setActiveEntity(const char* entityName) {
        return ::Editor_obj::setActiveEntity(::String(entityName));
    }

    __declspec(dllexport) void setLayerProperties(const char* layerName, LayerInfoStruct* properties) {
        ::Editor_obj::setLayerProperties(::String(layerName), properties);
    }

    __declspec(dllexport) void setLayerPropertiesAt(int index, LayerInfoStruct* properties) {
        ::Editor_obj::setLayerPropertiesAt(index, properties);
    }
}
')

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
    public static function getTextureData(path:String, outData:cpp.RawPointer<cpp.Void>):Void {
        if (app == null || !initialized) {
            log("Editor: Cannot get texture - engine not initialized");
            return;
        }
        
        try {
            // Load texture from resources
            var textureData = app.resources.getTexture(path, false);
            if (textureData == null) {
                log("Editor: Texture not found: " + path);
                return;
            }
            
            // Fill the struct using untyped C++ code
            var width = textureData.width;
            var height = textureData.height;
            var bpp = textureData.bytesPerPixel;
            var dataLength = textureData.bytes.length;
            var isTransparent = textureData.transparent ? 1 : 0;
            var bytes = textureData.bytes;
            
            untyped __cpp__("
                TextureDataStruct* outStruct = (TextureDataStruct*){0};
                outStruct->width = {1};
                outStruct->height = {2};
                outStruct->bytesPerPixel = {3};
                outStruct->dataLength = {4};
                outStruct->transparent = {5};
                // ArrayBufferViewImpl has a 'bytes' field of type haxe::io::Bytes
                // which has a 'b' field of type Array<unsigned char>
                ::Array<unsigned char> byteArray = {6}->bytes->b;
                outStruct->data = (unsigned char*)&(byteArray[0]);
            ", outData, width, height, bpp, dataLength, isTransparent, bytes);
            
            log("Editor: Loaded texture: " + path + " (" + width + "x" + height + ", " + bpp + " bpp)");
        } catch (e:Dynamic) {
            log("Editor: Error loading texture: " + e);
        }
    }
    
    /**
     * Get tileset information by name
     * @param tilesetName Name of the tileset (e.g., "devTiles")
     * @param outInfo Pointer to TilesetInfoStruct to fill
     * @return 1 if successful, 0 if tileset not found
     */
    @:keep
    public static function getTileset(tilesetName:String, outInfo:cpp.RawPointer<cpp.Void>):Int {
        if (app == null || !initialized) {
            log("Editor: Cannot get tileset - engine not initialized");
            return 0;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return 0;
        }
        
        try {
            var tilesetInfo = editorState.tilesetManager.getTilesetInfo(tilesetName);
            
            if (tilesetInfo == null) {
                log("Editor: Tileset not found: " + tilesetName);
                return 0;
            }
            
            // Fill the struct using untyped C++ code
            var name = tilesetInfo.name;
            var texturePath = tilesetInfo.texturePath;
            var tileSize = tilesetInfo.tileSize;
            var tilesPerRow = tilesetInfo.tilesPerRow;
            var tilesPerCol = tilesetInfo.tilesPerCol;
            var regionCount = tilesetInfo.regionCount;
            
            untyped __cpp__("
                TilesetInfoStruct* outStruct = (TilesetInfoStruct*){0};
                outStruct->name = {1}.utf8_str();
                outStruct->texturePath = {2}.utf8_str();
                outStruct->tileSize = {3};
                outStruct->tilesPerRow = {4};
                outStruct->tilesPerCol = {5};
                outStruct->regionCount = {6};
            ", outInfo, name, texturePath, tileSize, tilesPerRow, tilesPerCol, regionCount);
            
            log("Editor: Retrieved tileset: " + tilesetName + " (" + tilesPerRow + "x" + tilesPerCol + " tiles)");
            return 1;
            
        } catch (e:Dynamic) {
            log("Editor: Error getting tileset: " + e);
            return 0;
        }
    }

    @:keep
    public static function getTilesetAt(index:Int, outInfo:cpp.RawPointer<cpp.Void>):Int {
        if (app == null || !initialized) {
            log("Editor: Cannot get tileset - engine not initialized");
            return 0;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return 0;
        }
        
        try {
            var tilesetInfo = editorState.tilesetManager.getTilesetInfoAt(index);
            
            if (tilesetInfo == null) {
                log("Editor: Tileset not found at index: " + index);
                return 0;
            }
            
            // Fill the struct using untyped C++ code
            var name = tilesetInfo.name;
            var texturePath = tilesetInfo.texturePath;
            var tileSize = tilesetInfo.tileSize;
            var tilesPerRow = tilesetInfo.tilesPerRow;
            var tilesPerCol = tilesetInfo.tilesPerCol;
            var regionCount = tilesetInfo.regionCount;
            
            untyped __cpp__("
                TilesetInfoStruct* outStruct = (TilesetInfoStruct*){0};
                outStruct->name = {1}.utf8_str();
                outStruct->texturePath = {2}.utf8_str();
                outStruct->tileSize = {3};
                outStruct->tilesPerRow = {4};
                outStruct->tilesPerCol = {5};
                outStruct->regionCount = {6};
            ", outInfo, name, texturePath, tileSize, tilesPerRow, tilesPerCol, regionCount);
            
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
    
    /**
     * Create or update an entity definition
     * @param entityName Name of the entity
     * @param width Entity width in pixels
     * @param height Entity height in pixels
     * @param tilesetName Tileset to use for this entity
     */
    @:keep
    public static function createEntity(entityName:String, width:Int, height:Int, tilesetName:String):String {
        return editorState.createEntity(entityName, width, height, tilesetName);
    }
    
    /**
     * Set the atlas region for an entity definition
     * @param entityName Name of the entity
     * @param x Atlas region X position
     * @param y Atlas region Y position
     * @param width Atlas region width
     * @param height Atlas region height
     */
    @:keep
    public static function setEntityRegion(entityName:String, x:Int, y:Int, width:Int, height:Int):Void {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot set entity region - engine not initialized");
            return;
        }
        
        try {
            editorState.setEntityRegion(entityName, x, y, width, height);
        } catch (e:Dynamic) {
            log("Editor: Error setting entity region: " + e);
        }
    }
    
    /**
     * Get entity definition by name
     * @param entityName Name of the entity
     * @param outData Pointer to EntityDataStruct to fill
     */
    @:keep
    public static function getEntity(entityName:String, outData:cpp.RawPointer<cpp.Void>):Void {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot get entity - engine not initialized");
            return;
        }
        
        try {
            var entity = editorState.entityManager.getEntityDefinition(entityName);
            
            if (entity == null) {
                log("Editor: Entity not found: " + entityName);
                return;
            }
            
            // Fill the struct using untyped C++ code
            var name = entity.name;
            var width = entity.width;
            var height = entity.height;
            var tilesetName = entity.tilesetName;
            var regionX = entity.regionX;
            var regionY = entity.regionY;
            var regionWidth = entity.regionWidth;
            var regionHeight = entity.regionHeight;
            
            untyped __cpp__("EntityDataStruct* outStruct = (EntityDataStruct*){0};
                outStruct->name = {1}.utf8_str();
                outStruct->width = {2};
                outStruct->height = {3};
                outStruct->tilesetName = {4}.utf8_str();
                outStruct->regionX = {5};
                outStruct->regionY = {6};
                outStruct->regionWidth = {7};
                outStruct->regionHeight = {8};
            ", outData, name, width, height, tilesetName, regionX, regionY, regionWidth, regionHeight);
            
            log("Editor: Retrieved entity: " + entityName);
            
        } catch (e:Dynamic) {
            log("Editor: Error getting entity: " + e);
        }
    }
    
    /**
     * Get entity definition at specific index
     * @param index Index of the entity (0-based)
     * @param outData Pointer to EntityDataStruct to fill
     */
    @:keep
    public static function getEntityAt(index:Int, outData:cpp.RawPointer<cpp.Void>):Void {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot get entity - engine not initialized");
            return;
        }
        
        try {
            var entity = editorState.entityManager.getEntityDefinitionAt(index);
            
            if (entity == null) {
                log("Editor: Entity not found at index: " + index);
                return;
            }
            
            // Fill the struct using untyped C++ code
            var name = entity.name;
            var width = entity.width;
            var height = entity.height;
            var tilesetName = entity.tilesetName;
            var regionX = entity.regionX;
            var regionY = entity.regionY;
            var regionWidth = entity.regionWidth;
            var regionHeight = entity.regionHeight;
            
            untyped __cpp__("EntityDataStruct* outStruct = (EntityDataStruct*){0};
                outStruct->name = {1}.utf8_str();
                outStruct->width = {2};
                outStruct->height = {3};
                outStruct->tilesetName = {4}.utf8_str();
                outStruct->regionX = {5};
                outStruct->regionY = {6};
                outStruct->regionWidth = {7};
                outStruct->regionHeight = {8};
            ", outData, name, width, height, tilesetName, regionX, regionY, regionWidth, regionHeight);
            
            log("Editor: Retrieved entity at index " + index + ": " + name);
            
        } catch (e:Dynamic) {
            log("Editor: Error getting entity at index: " + e);
        }
    }
    
    /**
     * Get the count of entity definitions
     * @return Number of entity definitions
     */
    @:keep
    public static function getEntityCount():Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot get entity count - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.entityManager.getEntityDefinitionCount();
        } catch (e:Dynamic) {
            log("Editor: Error getting entity count: " + e);
            return 0;
        }
    }
    
    /**
     * Set the currently active entity for placement
     * @param entityName Name of the entity to make active
     * @return 1 if entity exists, 0 otherwise
     */
    @:keep
    public static function setActiveEntity(entityName:String):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot set active entity - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.setActiveEntity(entityName) ? 1 : 0;
        } catch (e:Dynamic) {
            log("Editor: Error setting active entity: " + e);
            return 0;
        }
    }
    
    // ===== LAYER MANAGEMENT =====
    
    /**
     * Create a new tilemap layer
     * @param layerName Name for the new layer
     * @param tilesetName Name of the tileset to use
     * @param index Position in the hierarchy (-1 to append at the end, 0 for first layer position)
     */
    @:keep
    public static function createTilemapLayer(layerName:String, tilesetName:String, index:Int = -1):Void {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot create tilemap layer - engine not initialized");
            return;
        }
        
        try {
            editorState.createTilemapLayer(layerName, tilesetName, index);
        } catch (e:Dynamic) {
            log("Editor: Error creating tilemap layer: " + e);
        }
    }
    
    /**
     * Create a new entity layer
     * @param layerName Name for the new layer
     */
    @:keep
    public static function createEntityLayer(layerName:String, tilesetName:String):Void {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot create entity layer - engine not initialized");
            return;
        }
        
        try {
            editorState.createEntityLayer(layerName, tilesetName);
        } catch (e:Dynamic) {
            log("Editor: Error creating entity layer: " + e);
        }
    }
    
    /**
     * Create a new folder layer
     * @param layerName Name for the new folder
     */
    @:keep
    public static function createFolderLayer(layerName:String):Void {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot create folder layer - engine not initialized");
            return;
        }
        
        try {
            editorState.createFolderLayer(layerName);
        } catch (e:Dynamic) {
            log("Editor: Error creating folder layer: " + e);
        }
    }
    
    /**
     * Set the active layer by name
     * @param layerName Name of the layer to make active
     * @return 1 if layer was found and set, 0 otherwise
     */
    @:keep
    public static function setActiveLayer(layerName:String):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot set active layer - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.setActiveLayer(layerName) ? 1 : 0;
        } catch (e:Dynamic) {
            log("Editor: Error setting active layer: " + e);
            return 0;
        }
    }
    
    /**
     * Set the active layer by index
     * @param index Index of the layer to make active
     * @return 1 if layer was found and set, 0 otherwise
     */
    @:keep
    public static function setActiveLayerAt(index:Int):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot set active layer - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.setActiveLayerAt(index) ? 1 : 0;
        } catch (e:Dynamic) {
            log("Editor: Error setting active layer by index: " + e);
            return 0;
        }
    }
    
    /**
     * Remove a layer by name
     * @param layerName Name of the layer to remove
     * @return 1 if layer was found and removed, 0 otherwise
     */
    @:keep
    public static function removeLayer(layerName:String):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot remove layer - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.removeLayer(layerName) ? 1 : 0;
        } catch (e:Dynamic) {
            log("Editor: Error removing layer: " + e);
            return 0;
        }
    }
    
    /**
     * Remove a layer by index
     * @param index Index of the layer to remove
     * @return 1 if layer was found and removed, 0 otherwise
     */
    @:keep
    public static function removeLayerByIndex(index:Int):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot remove layer - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.removeLayerByIndex(index) ? 1 : 0;
        } catch (e:Dynamic) {
            log("Editor: Error removing layer by index: " + e);
            return 0;
        }
    }
    
    /**
     * Move layer up in rendering order (earlier = behind)
     * @param layerName Name of the layer to move
     * @return 1 if layer was moved, 0 otherwise
     */
    @:keep
    public static function moveLayerUp(layerName:String):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot move layer - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.moveLayerUp(layerName) ? 1 : 0;
        } catch (e:Dynamic) {
            log("Editor: Error moving layer up: " + e);
            return 0;
        }
    }
    
    /**
     * Move layer down in rendering order (later = on top)
     * @param layerName Name of the layer to move
     * @return 1 if layer was moved, 0 otherwise
     */
    @:keep
    public static function moveLayerDown(layerName:String):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot move layer - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.moveLayerDown(layerName) ? 1 : 0;
        } catch (e:Dynamic) {
            log("Editor: Error moving layer down: " + e);
            return 0;
        }
    }
    
    /**
     * Move layer up by index
     * @param index Index of the layer to move
     * @return 1 if layer was moved, 0 otherwise
     */
    @:keep
    public static function moveLayerUpByIndex(index:Int):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot move layer - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.moveLayerUpByIndex(index) ? 1 : 0;
        } catch (e:Dynamic) {
            log("Editor: Error moving layer up by index: " + e);
            return 0;
        }
    }
    
    /**
     * Move layer down by index
     * @param index Index of the layer to move
     * @return 1 if layer was moved, 0 otherwise
     */
    @:keep
    public static function moveLayerDownByIndex(index:Int):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot move layer - engine not initialized");
            return 0;
        }
        
        try {
            return editorState.moveLayerDownByIndex(index) ? 1 : 0;
        } catch (e:Dynamic) {
            log("Editor: Error moving layer down by index: " + e);
            return 0;
        }
    }
    
    /**
     * Get the total number of layers
     * @return Number of layers
     */
    @:keep
    public static function getLayerCount():Int {
        if (app == null || !initialized || editorState == null) {
            return 0;
        }
        
        try {
            return editorState.getLayerCount();
        } catch (e:Dynamic) {
            log("Editor: Error getting layer count: " + e);
            return 0;
        }
    }
    
    /**
     * Get layer name at specific index
     * @param index Index of the layer (0-based)
     * @return Layer name or empty string if index out of bounds
     */
    @:keep
    public static function getLayerNameAt(index:Int):String {
        if (app == null || !initialized || editorState == null) {
            return "";
        }
        
        try {
            var layer = editorState.getLayerAt(index);
            return layer != null ? layer.id : "";
        } catch (e:Dynamic) {
            log("Editor: Error getting layer name at index: " + e);
            return "";
        }
    }
    
    /**
     * Get layer info at specific index
     * @param index Index of the layer (0-based)
     * @param outInfo Pointer to LayerInfoStruct to fill
     * @return 1 on success, 0 on failure
     */
    @:keep
    public static function getLayerInfoAt(index:Int, outInfo:cpp.RawPointer<cpp.Void>):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot get layer info - engine not initialized or editor state not loaded");
            return 0;
        }
        
        try {
            var layer = editorState.getLayerAt(index);
            if (layer == null) {
                log("Editor: Layer not found at index: " + index);
                return 0;
            }
            
            var name = layer.id;
            var type = 0; // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
            var tilesetName = "";
            var visible = layer.visible ? 1 : 0;
            
            // Determine layer type
            if (Std.isOfType(layer, layers.TilemapLayer)) {
                type = 0;
                var tilemapLayer:layers.TilemapLayer = cast layer;
                tilesetName = tilemapLayer.tileset.name;
            } else if (Std.isOfType(layer, layers.EntityLayer)) {
                type = 1;
            } else if (Std.isOfType(layer, layers.FolderLayer)) {
                type = 2;
            }
            
            untyped __cpp__("
                LayerInfoStruct* outStruct = (LayerInfoStruct*)({0});
                outStruct->name = {1}.utf8_str();
                outStruct->type = {2};
                outStruct->tilesetName = {3}.utf8_str();
                outStruct->visible = {4};
            ", outInfo, name, type, tilesetName, visible);
            
            return 1;
            
        } catch (e:Dynamic) {
            log("Editor: Error getting layer info at index: " + e);
            return 0;
        }
    }
    
    /**
     * Get layer info by name
     * @param layerName Name of the layer
     * @param outInfo Pointer to LayerInfoStruct to fill
     * @return 1 on success, 0 on failure
     */
    @:keep
    public static function getLayerInfo(layerName:String, outInfo:cpp.RawPointer<cpp.Void>):Int {
        if (app == null || !initialized || editorState == null) {
            log("Editor: Cannot get layer info - engine not initialized or editor state not loaded");
            return 0;
        }
        
        try {
            var layer = editorState.getLayerByName(layerName);
            if (layer == null) {
                log("Editor: Layer not found: " + layerName);
                return 0;
            }
            
            var name = layer.id;
            var type = 0; // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
            var tilesetName = "";
            var visible = layer.visible ? 1 : 0;
            
            // Determine layer type
            if (Std.isOfType(layer, layers.TilemapLayer)) {
                type = 0;
                var tilemapLayer:layers.TilemapLayer = cast layer;
                tilesetName = tilemapLayer.tileset.name;
            } else if (Std.isOfType(layer, layers.EntityLayer)) {
                type = 1;
            } else if (Std.isOfType(layer, layers.FolderLayer)) {
                type = 2;
            }
            
            untyped __cpp__("
                LayerInfoStruct* outStruct = (LayerInfoStruct*)({0});
                outStruct->name = {1}.utf8_str();
                outStruct->type = {2};
                outStruct->tilesetName = {3}.utf8_str();
                outStruct->visible = {4};
            ", outInfo, name, type, tilesetName, visible);
            
            return 1;
            
        } catch (e:Dynamic) {
            log("Editor: Error getting layer info: " + e);
            return 0;
        }
    }

	@:keep
	public static function setLayerProperties(layerName:String, properties:cpp.RawPointer<cpp.Void>):Void {
		if (app == null || !initialized || editorState == null) {
			log("Editor: Cannot set layer properties - engine not initialized");
			return;
		}
		try {
			
			var name:String = null;
			var type:Int = 0;
			var tilesetName:String = null;
			var visible:Int = 1;
			untyped __cpp__("
            LayerInfoStruct* inStruct = (LayerInfoStruct*)({0});
            {1} = ::String(inStruct->name);
            {2} = inStruct->type;
            {3} = ::String(inStruct->tilesetName);
            {4} = inStruct->visible;
        ", properties, name, type, tilesetName, visible);

			editorState.setLayerProperties(layerName, name, type, tilesetName, visible != 0);
			// Add more property assignments as needed
		} catch (e:Dynamic) {
			log("Editor: Error setting layer properties: " + e);
		}
	}

	@:keep
	public static function setLayerPropertiesAt(index:Int, properties:cpp.RawPointer<cpp.Void>):Void {
		if (app == null || !initialized || editorState == null) {
			log("Editor: Cannot set layer properties - engine not initialized");
			return;
		}
		try {
			
			// Read LayerInfoStruct fields from the pointer
			var name:String = null;
			var type:Int = 0;
			var tilesetName:String = null;
			var visible:Int = 1;
			untyped __cpp__("
            LayerInfoStruct* inStruct = (LayerInfoStruct*)({0});
            {1} = ::String(inStruct->name);
            {2} = inStruct->type;
            {3} = ::String(inStruct->tilesetName);
            {4} = inStruct->visible;
        ", properties, name, type, tilesetName, visible);

            editorState.setLayerPropertiesAt(index, name, type, tilesetName, visible != 0);
			
		} catch (e:Dynamic) {
			log("Editor: Error setting layer properties at index: " + e);
		}
	}
}
