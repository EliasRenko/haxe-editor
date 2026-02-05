package;

import math.Vec2;

@:headerCode('#include "editor_native.h"')
@:cppFileCode('
#include <SDL3/SDL_log.h>

// Alias for cleaner code
using Engine = ::Editor_obj;

// Global state
bool hxcpp_initialized = false;

// Callbacks
EngineCallback g_callback = nullptr;

// SDL log output function that forwards to C# callback
void SDLCALL CustomLogOutput(void* userdata, int category, SDL_LogPriority priority, const char* message) {
    if (g_callback != nullptr) {
        // Format: [PRIORITY] message
        const char* priorityStr = "INFO";
        switch (priority) {
            case SDL_LOG_PRIORITY_VERBOSE: priorityStr = "VERBOSE"; break;
            case SDL_LOG_PRIORITY_DEBUG: priorityStr = "DEBUG"; break;
            case SDL_LOG_PRIORITY_INFO: priorityStr = "INFO"; break;
            case SDL_LOG_PRIORITY_WARN: priorityStr = "WARN"; break;
            case SDL_LOG_PRIORITY_ERROR: priorityStr = "ERROR"; break;
            case SDL_LOG_PRIORITY_CRITICAL: priorityStr = "CRITICAL"; break;
        }
        
        char buffer[1024];
        snprintf(buffer, sizeof(buffer), "[%s] %s", priorityStr, message);
        g_callback(buffer);
    }
}

extern "C" {
    // Set callback function for C# to receive messages
    __declspec(dllexport) void setCallback(EngineCallback callback) {
        g_callback = callback;
        if (callback != nullptr) {
            // Hook SDL log output to forward to C# callback
            SDL_SetLogOutputFunction(CustomLogOutput, nullptr);
        }
    }
    
    // Haxe runtime initialization
    __declspec(dllexport) const char* HxcppInit() {
        if (hxcpp_initialized) {
            return NULL;  // Already initialized
        }
        
        const char* err = hx::Init();
        if (err == NULL) {
            hxcpp_initialized = true;
        }
        return err;  // Returns NULL on success, error message on failure
    }
    
    // Engine API
    __declspec(dllexport) int init() {
        // Ensure runtime is initialized first
        if (!hxcpp_initialized) {
            const char* err = hx::Init();
            if (err != NULL) return 0;
            hxcpp_initialized = true;
        }
        
        // Use NativeAttach to properly set up the thread
        hx::NativeAttach attach;
        return Engine::init();
    }
    
    __declspec(dllexport) int initWithCallback(EngineCallback callback) {
        // Set callback first
        setCallback(callback);
        
        // Then initialize
        return init();
    }
    
    __declspec(dllexport) void updateFrame(float deltaTime) {
        Engine::updateFrame(deltaTime);
    }
    
    __declspec(dllexport) void render() {
        Engine::render();
    }
    
    __declspec(dllexport) void swapBuffers() {
        Engine::swapBuffers();
    }
    
    __declspec(dllexport) void shutdownEngine() {
        Engine::engineShutdown();
    }
    
    __declspec(dllexport) void release() {
        Engine::release();
    }
    
    __declspec(dllexport) void loadState(int stateIndex) {
        Engine::loadState(stateIndex);
    }
    
    __declspec(dllexport) int isRunning() {
        return Engine::engineIsRunning();
    }
    
    __declspec(dllexport) int getWindowWidth() {
        return Engine::engineGetWindowWidth();
    }
    
    __declspec(dllexport) int getWindowHeight() {
        return Engine::engineGetWindowHeight();
    }
    
    __declspec(dllexport) void setWindowSize(int width, int height) {
        Engine::engineSetWindowSize(width, height);
    }
    
    __declspec(dllexport) void* getWindowHandle() {
        return Engine::getWindowHandle();
    }
    
    __declspec(dllexport) void setWindowPosition(int x, int y) {
        Engine::setWindowPosition(x, y);
    }
    
    __declspec(dllexport) void setWindowSizeAndBorderless(int width, int height) {
        Engine::engineSetWindowSizeAndBorderless(width, height);
    }
    
    __declspec(dllexport) void onMouseButtonDown(int x, int y, int button) {
        Engine::onMouseButtonDown(x, y, button);
    }

    __declspec(dllexport) void onMouseButtonUp(int x, int y, int button) {
        Engine::onMouseButtonUp(x, y, button);
    }

    __declspec(dllexport) void onKeyboardDown(int keyCode) {
        Engine::onKeyboardDown(keyCode);
    }

    __declspec(dllexport) void onKeyboardUp(int keyCode) {
        Engine::onKeyboardUp(keyCode);
    }
    
    __declspec(dllexport) void importFont(const char* fontPath, float fontSize) {
        Engine::importFont(fontPath, fontSize);
    }
    
    __declspec(dllexport) void rebakeFont(float fontSize, int atlasWidth, int atlasHeight, int firstChar, int numChars) {
        Engine::rebakeFont(fontSize, atlasWidth, atlasHeight, firstChar, numChars);
    }
    
    __declspec(dllexport) void exportFont(const char* outputPath) {
        Engine::exportFont(outputPath);
    }
    
    __declspec(dllexport) void loadFont(const char* outputName) {
        Engine::loadFont(outputName);
    }
}
')

class Editor {
    
    // Store app instance
    private static var app:App = null;
    private static var initialized:Bool = false;
    
    /**
     * DLL Main - called when DLL mode is active
     */
    public static function main():Void {
        trace("Haxe BMFG DLL loaded - ready for API calls");
        trace("Available exports: EngineInit, EngineUpdate, EngineRender, etc.");
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
            app.addState(new FontBakerState(app));
            app.log.info(1, "FontBakerState loaded");
            
            initialized = true;
            log("Engine initialized successfully");

            return 1;
        } catch (e:Dynamic) {
            log("Editor: Init error: " + e);
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
                    app.addState(new FontBakerState(app));
                    log("Editor: FontBakerState loaded");
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
     * Import a TTF font - loads, bakes to RAM texture, and displays without exporting to disk
     * @param fontPath Path to the TTF font file
     * @param fontSize Font size in pixels
     */
    @:keep
    public static function importFont(fontPath:String, fontSize:Float):Void {
        if (app == null || !initialized) {
            log("Editor: Cannot import font - engine not initialized");
            return;
        }
        
        try {
            log('Importing font: $fontPath at ${fontSize}px (RAM only, no export)');
            
            // Get the FontBakerState
            var state = app.currentState;
            if (state != null && Std.isOfType(state, FontBakerState)) {
                var fontState:FontBakerState = cast state;
                fontState.importFont(fontPath, fontSize);
            } else {
                log("Editor: Current state is not FontBakerState");
            }
        } catch (e:Dynamic) {
            log("Editor: Import font error: " + e);
        }
    }
    
    /**
     * Export a font - bakes TTF to texture atlas and saves JSON + TGA files to disk
     * @param fontPath Path to the TTF font file
     * @param fontSize Font size in pixels
     */
    @:keep
    public static function exportFont(outputPath:String):Void {
        if (app == null || !initialized) {
            log("Editor: Cannot export font - engine not initialized");
            return;
        }
        
        try {
            log('Exporting currently imported font to: $outputPath');
            
            // Get the FontBakerState
            var state = app.currentState;
            if (state != null && Std.isOfType(state, FontBakerState)) {
                var fontState:FontBakerState = cast state;
                fontState.exportFont(outputPath);
            } else {
                log("Editor: Current state is not FontBakerState");
            }
        } catch (e:Dynamic) {
            log("Editor: Export font error: " + e);
        }
    }
    
    /**
     * Rebake the currently loaded font with new settings
     * @param fontSize Font size in pixels
     * @param atlasWidth Atlas texture width
     * @param atlasHeight Atlas texture height
     * @param firstChar First character to bake
     * @param numChars Number of characters to bake
     */
    @:keep
    public static function rebakeFont(fontSize:Float, atlasWidth:Int, atlasHeight:Int, firstChar:Int, numChars:Int):Void {
        if (app == null || !initialized) {
            log("Editor: Cannot rebake font - engine not initialized");
            return;
        }
        
        try {
            log('Rebaking font: size=$fontSize, atlas=${atlasWidth}x${atlasHeight}, chars=$firstChar-${firstChar + numChars - 1}');
            
            // Get the FontBakerState
            var state = app.currentState;
            if (state != null && Std.isOfType(state, FontBakerState)) {
                var fontState:FontBakerState = cast state;
                fontState.rebakeFont(fontSize, atlasWidth, atlasHeight, firstChar, numChars);
            } else {
                log("Editor: Current state is not FontBakerState");
            }
        } catch (e:Dynamic) {
            log("Editor: Rebake font error: " + e);
        }
    }
    
    /**
     * Load a previously exported font and display it
     * @param outputName Output name (without extension) of the baked font files
     */
    @:keep
    public static function loadFont(outputName:String):Void {
        if (app == null || !initialized) {
            log("Editor: Cannot load font - engine not initialized");
            return;
        }
        
        try {
            log('Loading font: $outputName');
            
            // Get the FontBakerState
            var state = app.currentState;
            if (state != null && Std.isOfType(state, FontBakerState)) {
                var fontState:FontBakerState = cast state;
                fontState.loadFont(outputName);
            } else {
                log("Editor: Current state is not FontBakerState");
            }
        } catch (e:Dynamic) {
            log("Editor: Load font error: " + e);
        }
    }
}
