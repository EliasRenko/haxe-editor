#ifndef EDITOR_NATIVE_H
#define EDITOR_NATIVE_H

//#include <hx/Thread.h>
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <stdio.h>

typedef void (__cdecl *CustomCallback)(const char* message);

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
    int width;
    int height;
    const char* tilesetName;
    int regionX;
    int regionY;
    int regionWidth;
    int regionHeight;
} EntityDataStruct;

typedef struct {
    const char* name;
    int type;                // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
    const char* tilesetName; // For TilemapLayer only (null for others)
    int visible;             // 0 = hidden, 1 = visible
    bool silhouette;          // 0 = no silhouette, 1 = silhouette enabled
    int silhouetteColor;  // RGBA color for silhouette 
} LayerInfoStruct;

extern "C" {
    extern bool hxcpp_initialized;
    extern CustomCallback g_callback;
    
    __declspec(dllexport) const char* HxcppInit();

    //__declspec(dllexport) void setCallback(CustomCallback callback);
    
    // Engine lifecycle functions
    __declspec(dllexport) int init();
    __declspec(dllexport) int initWithCallback(CustomCallback callback);
    __declspec(dllexport) void updateFrame(float deltaTime);
    __declspec(dllexport) void render();
    __declspec(dllexport) void swapBuffers();
    __declspec(dllexport) void release();
    __declspec(dllexport) void loadState(int stateIndex);
    __declspec(dllexport) int isRunning();

    // Window management functions
    __declspec(dllexport) int getWindowWidth();
    __declspec(dllexport) int getWindowHeight();
    __declspec(dllexport) void setWindowSize(int width, int height);
    __declspec(dllexport) void* getWindowHandle();
    __declspec(dllexport) void setWindowPosition(int x, int y);
    __declspec(dllexport) void setWindowSizeAndBorderless(int width, int height);

    // Input handling
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
    __declspec(dllexport) int getActiveTile();
    __declspec(dllexport) int getTilesetCount();

    __declspec(dllexport) const char* createTileset(const char* texturePath, const char* tilesetName, int tileSize);
    __declspec(dllexport) int setActiveTileset(const char* tilesetName);
    __declspec(dllexport) void setActiveTile(int tileRegionId);
    
    // Entity management
    __declspec(dllexport) void getEntity(const char* entityName, EntityDataStruct* outData);
    __declspec(dllexport) void getEntityAt(int index, EntityDataStruct* outData);
    __declspec(dllexport) int getEntityCount();

    __declspec(dllexport) const char* createEntity(const char* entityName, int width, int height, const char* tilesetName);
    __declspec(dllexport) int setActiveEntity(const char* entityName);
    __declspec(dllexport) void setEntityRegion(const char* entityName, int x, int y, int width, int height);

    // Layer management
    __declspec(dllexport) void createTilemapLayer(const char* layerName, const char* tilesetName, int index);
    __declspec(dllexport) void createEntityLayer(const char* layerName, const char* tilesetName);
    __declspec(dllexport) void createFolderLayer(const char* layerName);

    __declspec(dllexport) int getLayerInfo(const char* layerName, LayerInfoStruct* outInfo);
    __declspec(dllexport) int getLayerInfoAt(int index, LayerInfoStruct* outInfo);
    __declspec(dllexport) int getLayerCount();

    __declspec(dllexport) int setActiveLayer(const char* layerName);
    __declspec(dllexport) int setActiveLayerAt(int index);
    __declspec(dllexport) int removeLayer(const char* layerName);
    __declspec(dllexport) int removeLayerByIndex(int index);
    __declspec(dllexport) const char* getLayerNameAt(int index);
    
    __declspec(dllexport) int moveLayerUp(const char* layerName);
    __declspec(dllexport) int moveLayerDown(const char* layerName);
    __declspec(dllexport) int moveLayerUpByIndex(int index);
    __declspec(dllexport) int moveLayerDownByIndex(int index);

    __declspec(dllexport) void setLayerProperties(const char* layerName, LayerInfoStruct* properties);
    __declspec(dllexport) void setLayerPropertiesAt(int index, LayerInfoStruct* properties);

    __declspec(dllexport) void replaceLayerTileset(const char* layerName, const char* newTilesetName);

    
}

#endif // EDITOR_NATIVE_H
