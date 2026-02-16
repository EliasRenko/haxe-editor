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

typedef struct {
    unsigned char* data;
    int width;
    int height;
    int bytesPerPixel;
    int dataLength;
    int transparent;
} TextureDataStruct;

typedef struct {
    const char* name;
    const char* texturePath;
    int tileSize;
    int tilesPerRow;
    int tilesPerCol;
    int regionCount;
} TilesetInfoStruct;

typedef struct {
    const char* name;
    int type;                // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
    const char* tilesetName; // For TilemapLayer only (null for others)
    int visible;             // 0 = hidden, 1 = visible
} LayerInfoStruct;

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
    
    // Tilemap import/export
    __declspec(dllexport) int exportMap(const char* filePath);
    __declspec(dllexport) int importMap(const char* filePath);
    
    // Tileset management
    __declspec(dllexport) int getTileset(const char* tilesetName, TilesetInfoStruct* outInfo);
    __declspec(dllexport) int getTilesetAt(int index, TilesetInfoStruct* outInfo);
    __declspec(dllexport) int getTilesetCount();

    __declspec(dllexport) void setTileset(const char* texturePath, const char* tilesetName, int tileSize);
    __declspec(dllexport) int setActiveTileset(const char* tilesetName);
    __declspec(dllexport) void setActiveTile(int tileRegionId);
    
    // Layer management
    __declspec(dllexport) void createTilemapLayer(const char* layerName, const char* tilesetName);
    __declspec(dllexport) void createEntityLayer(const char* layerName);
    __declspec(dllexport) void createFolderLayer(const char* layerName);

    __declspec(dllexport) int getLayerInfo(const char* layerName, LayerInfoStruct* outInfo);
    __declspec(dllexport) int getLayerInfoAt(int index, LayerInfoStruct* outInfo);
    __declspec(dllexport) int getLayerCount();

    __declspec(dllexport) int setActiveLayer(const char* layerName);
    __declspec(dllexport) int setActiveLayerAt(int index);
    __declspec(dllexport) int removeLayer(const char* layerName);
    __declspec(dllexport) int removeLayerByIndex(int index);
    __declspec(dllexport) const char* getLayerNameAt(int index);
}

#endif // EDITOR_NATIVE_H
