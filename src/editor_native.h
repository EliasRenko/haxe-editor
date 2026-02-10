#ifndef EDITOR_NATIVE_H
#define EDITOR_NATIVE_H

#include <hx/Thread.h>
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <stdio.h>

// Callback typedefs for C# to receive messages and events (MUST be outside extern "C")
typedef void (__cdecl *CustomCallback)(const char* message);
typedef void (__cdecl *MouseDownButtonCallback)(double x, double y, int button);

// Texture data structure for passing to C#
typedef struct {
    unsigned char* data;      // Pointer to pixel data
    int width;                // Texture width in pixels
    int height;               // Texture height in pixels
    int bytesPerPixel;        // Bytes per pixel (1, 3, or 4)
    int dataLength;           // Total size of data array
    int transparent;          // 1 if has transparency, 0 otherwise
} TextureDataStruct;

// Tileset information structure for passing to C#
typedef struct {
    const char* name;         // Tileset name
    const char* texturePath;  // Resource path to texture
    int tileSize;             // Size of each tile in pixels
    int tilesPerRow;          // Number of tiles per row in atlas
    int tilesPerCol;          // Number of tiles per column in atlas
    int regionCount;          // Total number of tile regions
} TilesetInfoStruct;

extern "C" {
    // Global state (declared in Editor.hx @:cppFileCode)
    extern bool hxcpp_initialized;
    extern CustomCallback g_callback;
    
    __declspec(dllexport) const char* HxcppInit();

    __declspec(dllexport) void setCallback(CustomCallback callback);
    
    // Engine lifecycle functions
    __declspec(dllexport) int init();
    __declspec(dllexport) int initWithCallback(CustomCallback callback);
    __declspec(dllexport) void updateFrame(float deltaTime);
    __declspec(dllexport) void render();
    __declspec(dllexport) void swapBuffers();
    __declspec(dllexport) void shutdownEngine();
    __declspec(dllexport) void release();
    __declspec(dllexport) void loadState(int stateIndex);
    __declspec(dllexport) int isRunning();
    __declspec(dllexport) int getWindowWidth();
    __declspec(dllexport) int getWindowHeight();
    __declspec(dllexport) void setWindowSize(int width, int height);
    __declspec(dllexport) void* getWindowHandle();
    __declspec(dllexport) void setWindowPosition(int x, int y);
    __declspec(dllexport) void setWindowSizeAndBorderless(int width, int height);

    // Mouse input handling
    __declspec(dllexport) void onMouseMotion(int x, int y);
    __declspec(dllexport) void onMouseButtonDown(int x, int y, int button);
    __declspec(dllexport) void onMouseButtonUp(int x, int y, int button);
    __declspec(dllexport) void onKeyboardDown(int keyCode);
    __declspec(dllexport) void onKeyboardUp(int keyCode);
    
    // Texture data retrieval
    __declspec(dllexport) void getTextureData(const char* path, TextureDataStruct* outData);
    
    // Tileset information retrieval
    __declspec(dllexport) int getTileset(const char* tilesetName, TilesetInfoStruct* outInfo);
    
    // Tile selection
    __declspec(dllexport) void setSelectedTile(int tileRegionId);
}

#endif // EDITOR_NATIVE_H
