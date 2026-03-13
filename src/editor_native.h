#ifndef EDITOR_NATIVE_H
#define EDITOR_NATIVE_H

#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <stdio.h>

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
    float pivotX; /* default normalised pivot X (0=left, 0.5=centre, 1=right) */
    float pivotY; /* default normalised pivot Y (0=top,  0.5=centre, 1=bottom) */
} EntityDataStruct;

typedef struct {
    const char* name;
    int type;                // 0 = TilemapLayer, 1 = EntityLayer, 2 = FolderLayer
    const char* tilesetName; // For TilemapLayer only (null for others)
    int tileSize;            // For TilemapLayer only (0 for others)
    int visible;             // 0 = hidden, 1 = visible
    bool silhouette;          // 0 = no silhouette, 1 = silhouette enabled
    int silhouetteColor;  // RGBA color for silhouette 
} LayerInfoStruct;

typedef struct EntityStruct {
    const char* uid;
    const char* name;
    int width;
    int height;
    int x;
    int y;
} EntityStruct;

typedef struct {
    const char* idd;
    const char* name;
    int worldx;
    int worldy;
    int width;
    int height;
    int tileSizeX;
    int tileSizeY;
    int bgColor;
    int gridColor;
} MapProps;

typedef void (__cdecl *CustomCallback)(const char* priority, const char* category, const char* message);
typedef void (__cdecl *EntitySelectionChangedCallback)(); // fired when selection changes

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
    __declspec(dllexport) int loadState(int stateId);
    __declspec(dllexport) int setActiveState(int index);
    __declspec(dllexport) int releaseState(int index);
    __declspec(dllexport) int isRunning();

    // Window management functions
    __declspec(dllexport) int getWindowWidth();
    __declspec(dllexport) int getWindowHeight();
    __declspec(dllexport) void setWindowSize(int width, int height);
    __declspec(dllexport) void* getWindowHandle();
    __declspec(dllexport) void setWindowPosition(int x, int y);

    // Input handling
    __declspec(dllexport) void onMouseMotion(int x, int y);
    __declspec(dllexport) void onMouseButtonDown(int x, int y, int button);
    __declspec(dllexport) void onMouseButtonUp(int x, int y, int button);
    __declspec(dllexport) void onKeyboardDown(int keyCode);
    __declspec(dllexport) void onKeyboardUp(int keyCode);

    __declspec(dllexport) int newEditorState();

    // Texture data retrieval
    __declspec(dllexport) void getTextureData(const char* path, TextureDataStruct* outData);
    
    // Tilemap import/export
    __declspec(dllexport) int exportMap(const char* filePath);
    __declspec(dllexport) int importMap(const char* filePath);
    
    // Tileset management
    __declspec(dllexport) const char* createTileset(const char* texturePath, const char* tilesetName);

    __declspec(dllexport) int getTileset(const char* tilesetName, TilesetInfoStruct* outInfo);
    __declspec(dllexport) int getTilesetAt(int index, TilesetInfoStruct* outInfo);
    __declspec(dllexport) int getActiveTile();
    __declspec(dllexport) int getTilesetCount();

    __declspec(dllexport) int setActiveTileset(const char* tilesetName);
    __declspec(dllexport) void setActiveTile(int tileRegionId);
    
    // Entity definition management
    // Removes a tileset by name. Also removes every TilemapLayer using it and every entity
    // batch in EntityLayers that references it. Returns null on success, error string on failure.
    __declspec(dllexport) const char* deleteTileset(const char* name);

    __declspec(dllexport) const char* createEntityDef(const char* entityName, EntityDataStruct* data);
    __declspec(dllexport) const char* editEntityDef(const char* entityName, EntityDataStruct* data);
    __declspec(dllexport) const char* deleteEntityDef(const char* entityName);

    __declspec(dllexport) const char* getEntityDef(const char* entityName, EntityDataStruct* outData);
    __declspec(dllexport) const char* getEntityDefAt(int index, EntityDataStruct* outData);
    __declspec(dllexport) int getEntityDefCount();

    __declspec(dllexport) int setActiveEntityDef(const char* entityName);

    // Layer management
    __declspec(dllexport) void createTilemapLayer(const char* layerName, const char* tilesetName, int tileSize, int index);
    __declspec(dllexport) void createEntityLayer(const char* layerName);
    __declspec(dllexport) void createFolderLayer(const char* layerName);

    __declspec(dllexport) int getLayerInfoAt(int index, LayerInfoStruct* outInfo);
    __declspec(dllexport) int getLayerCount();

    __declspec(dllexport) int getLayerInfo(const char* layerName, LayerInfoStruct* outInfo);
    __declspec(dllexport) void replaceLayerTileset(const char* layerName, const char* newTilesetName);

    __declspec(dllexport) int setActiveLayer(const char* layerName);
    __declspec(dllexport) int setActiveLayerAt(int index);
    __declspec(dllexport) void setLayerProperties(const char* layerName, LayerInfoStruct* properties);
    __declspec(dllexport) void setLayerPropertiesAt(int index, LayerInfoStruct* properties);
    __declspec(dllexport) int removeLayer(const char* layerName);
    __declspec(dllexport) int removeLayerByIndex(int index);

    // batch accessors for entity layers
    __declspec(dllexport) int getEntityLayerBatchCount(const char* layerName);
    __declspec(dllexport) int getEntityLayerBatchCountAt(int index);
    __declspec(dllexport) const char* getEntityLayerBatchTilesetName(const char* layerName, int batchIndex);

    // entity instance accessors (batchIndex = -1 for all batches)
    __declspec(dllexport) int getEntityLayerInstanceCount(const char* layerName, int batchIndex);
    __declspec(dllexport) int getEntityLayerInstanceAt(const char* layerName, int batchIndex, int instanceIndex, EntityStruct* outData);

    // batch movement
    __declspec(dllexport) int moveEntityLayerBatchUp(const char* layerName, int batchIndex);
    __declspec(dllexport) int moveEntityLayerBatchDown(const char* layerName, int batchIndex);
    __declspec(dllexport) int moveEntityLayerBatchTo(const char* layerName, int batchIndex, int newIndex);
    __declspec(dllexport) int moveEntityLayerBatchUpByIndex(int layerIndex, int batchIndex);
    __declspec(dllexport) int moveEntityLayerBatchDownByIndex(int layerIndex, int batchIndex);
    __declspec(dllexport) int moveEntityLayerBatchToByIndex(int layerIndex, int batchIndex, int newIndex);
    
    __declspec(dllexport) int moveLayerUp(const char* layerName);
    __declspec(dllexport) int moveLayerDown(const char* layerName);
    __declspec(dllexport) int moveLayerTo(const char* layerName, int newIndex);
    __declspec(dllexport) int moveLayerUpByIndex(int index);
    __declspec(dllexport) int moveLayerDownByIndex(int index);

    // map
    __declspec(dllexport) const char* getMapProps(MapProps* outInfo);
    __declspec(dllexport) const char* setMapProps(MapProps* info);

    // tool
    __declspec(dllexport) void setToolType(int toolType);
    __declspec(dllexport) int getToolType();

    // entity selection
    __declspec(dllexport) void setEntitySelectionChangedCallback(EntitySelectionChangedCallback callback);
    __declspec(dllexport) int getEntitySelectionCount();
    __declspec(dllexport) int getEntitySelectionInfo(int index, EntityStruct* outData);
    __declspec(dllexport) int selectEntityByUID(const char* uid);
    __declspec(dllexport) int selectEntityInLayerByUID(const char* layerName, const char* uid);
}

#endif // EDITOR_NATIVE_H
