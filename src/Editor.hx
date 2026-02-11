package;

import states.EditorState;
import math.Vec2;

@:headerCode('#include "editor_native.h"')
@:headerInclude("haxe/io/Bytes.h")
@:cppFileCode('
#include <SDL3/SDL_log.h>

bool hxcpp_initialized = false;
CustomCallback g_callback = nullptr;

// SDL log output function that forwards to C# callback
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
    
    __declspec(dllexport) void shutdownEngine() {
        ::Editor_obj::engineShutdown();
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
    
    __declspec(dllexport) int getTileset(const char* tilesetName, TilesetInfoStruct* outInfo) {
        return ::Editor_obj::getTileset(::String(tilesetName), outInfo);
    }
    
    __declspec(dllexport) void setSelectedTile(int tileRegionId) {
        ::Editor_obj::setSelectedTile(tileRegionId);
    }
    
    __declspec(dllexport) int exportMap(const char* filePath) {
        return ::Editor_obj::exportMap(::String(filePath));
    }
    
    __declspec(dllexport) int importMap(const char* filePath) {
        return ::Editor_obj::importMap(::String(filePath));
    }
    
    __declspec(dllexport) void setupTilemap(const char* texturePath, const char* tilesetName, int tileSize) {
        ::Editor_obj::setupTilemap(::String(texturePath), ::String(tilesetName), tileSize);
    }
    
    __declspec(dllexport) int getTilesetCount() {
        return ::Editor_obj::getTilesetCount();
    }
    
    __declspec(dllexport) const char* getTilesetNameAt(int index) {
        return ::Editor_obj::getTilesetNameAt(index).__s;
    }
    
    __declspec(dllexport) int setCurrentTileset(const char* tilesetName) {
        return ::Editor_obj::setCurrentTileset(::String(tilesetName));
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
     * Shutdown the engine
     */
    @:keep
    public static function engineShutdown():Void {
        log("Editor: Shutting down engine...");
        if (app != null) {
            app.release();
            app = null;
            initialized = false;
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
            var tilesetInfo = editorState.getTilesetInfo(tilesetName);
            
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
    
    /**
     * Set the selected tile region for drawing
     * @param tileRegionId The region ID to select (0-based index into tile regions array)
     */
    @:keep
    public static function setSelectedTile(tileRegionId:Int):Void {
        if (app == null || !initialized) {
            log("Editor: Cannot set selected tile - engine not initialized");
            return;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return;
        }
        
        try {
            editorState.setSelectedTileRegion(tileRegionId);
            log("Editor: Selected tile region: " + tileRegionId);
        } catch (e:Dynamic) {
            log("Editor: Error setting selected tile: " + e);
        }
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
    
    /**
     * Setup/load a tileset
     * @param texturePath Resource path to the texture
     * @param tilesetName Unique name for this tileset
     * @param tileSize Size of each tile in pixels
     */
    @:keep
    public static function setupTilemap(texturePath:String, tilesetName:String, tileSize:Int):Void {
        if (app == null || !initialized) {
            log("Editor: Cannot setup tilemap - engine not initialized");
            return;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return;
        }
        
        try {
            editorState.setupTilemap(texturePath, tilesetName, tileSize);
            log("Editor: Setup tilemap: " + tilesetName);
        } catch (e:Dynamic) {
            log("Editor: Error setting up tilemap: " + e);
        }
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
            return editorState.getTilesetCount();
        } catch (e:Dynamic) {
            log("Editor: Error getting tileset count: " + e);
            return 0;
        }
    }
    
    /**
     * Get tileset name at specific index
     * @param index Index of the tileset (0-based)
     * @return Tileset name or empty string if index out of bounds
     */
    @:keep
    public static function getTilesetNameAt(index:Int):String {
        if (app == null || !initialized) {
            log("Editor: Cannot get tileset name - engine not initialized");
            return "";
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return "";
        }
        
        try {
            return editorState.getTilesetNameAt(index);
        } catch (e:Dynamic) {
            log("Editor: Error getting tileset name at index " + index + ": " + e);
            return "";
        }
    }
    
    /**
     * Set the current active tileset for drawing
     * @param tilesetName Name of the tileset to make active
     * @return 1 if tileset was found and set, 0 otherwise
     */
    @:keep
    public static function setCurrentTileset(tilesetName:String):Int {
        if (app == null || !initialized) {
            log("Editor: Cannot set tileset - engine not initialized");
            return 0;
        }
        
        if (editorState == null) {
            log("Editor: EditorState not loaded");
            return 0;
        }
        
        try {
            var result = editorState.setCurrentTileset(tilesetName);
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
}
