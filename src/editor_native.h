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
    const char* projectFilePath; // null / empty if map is not linked to a project
    const char* projectId;       // null / empty if map is not linked to a project
    const char* projectName;     // null / empty if map is not linked to a project
} MapProps;

typedef struct {
    const char* filePath;
    const char* projectId;
    const char* projectName;
    const char* projectDir;
    int defaultTileSizeX;
    int defaultTileSizeY;
} ProjectProps;

typedef void (__cdecl *CustomCallback)(const char* priority, const char* category, const char* message);
typedef void (__cdecl *EntitySelectionChangedCallback)(); // fired when selection changes

extern "C" {
    extern bool hxcpp_initialized;
    extern CustomCallback g_callback;
    
    __declspec(dllexport) const char* HxcppInit();
    
    // Lifecycle functions
    __declspec(dllexport) bool init();
    __declspec(dllexport) bool initWithCallback(CustomCallback callback);
    __declspec(dllexport) void release();
    __declspec(dllexport) bool isRunning();
    __declspec(dllexport) void updateFrame(float deltaTime);
    __declspec(dllexport) void render();
    __declspec(dllexport) void swapBuffers();

    __declspec(dllexport) int newEditorState();
    __declspec(dllexport) bool setActiveState(int index);
    __declspec(dllexport) bool releaseState(int index);

    // Window management functions
    __declspec(dllexport) void* getWindowHandle();
    __declspec(dllexport) int getWindowWidth();
    __declspec(dllexport) int getWindowHeight();
    __declspec(dllexport) void setWindowSize(int width, int height);
    __declspec(dllexport) void setWindowPosition(int x, int y);

    // Input handling
    __declspec(dllexport) void onMouseMotion(int x, int y);
    __declspec(dllexport) void onMouseButtonDown(int x, int y, int button);
    __declspec(dllexport) void onMouseButtonUp(int x, int y, int button);
    __declspec(dllexport) void onKeyboardDown(int keyCode);
    __declspec(dllexport) void onKeyboardUp(int keyCode);
    __declspec(dllexport) void onMouseWheel(float x, float y, float delta);

    // Project management
    __declspec(dllexport) bool exportProject(const char* filePath, const char* projectName);
    __declspec(dllexport) bool importProject(const char* filePath);
    __declspec(dllexport) bool getProjectProps(ProjectProps* outProps);
    __declspec(dllexport) bool editProject(ProjectProps* inProps);
    __declspec(dllexport) bool copyResources(const char* filePath, const char* subfolder);
    //__declspec(dllexport) bool closeProject();
    
    // Map management
    __declspec(dllexport) bool exportMap(const char* filePath);
    __declspec(dllexport) int importMap(const char* filePath);
    __declspec(dllexport) bool getMapProps(MapProps* outInfo);
    __declspec(dllexport) bool setMapProps(MapProps* info);

    // Texture management
    __declspec(dllexport) void getTextureData(const char* path, TextureDataStruct* outData);
    
    // Tileset management
    __declspec(dllexport) bool createTileset(const char* texturePath, const char* name);
    __declspec(dllexport) bool deleteTileset(const char* name);
    __declspec(dllexport) bool getTileset(const char* tilesetName, TilesetInfoStruct* outInfo);
    __declspec(dllexport) bool getTilesetAt(int index, TilesetInfoStruct* outInfo);
    __declspec(dllexport) int getTilesetCount();
    __declspec(dllexport) bool setActiveTileset(const char* tilesetName);
    __declspec(dllexport) int getActiveTile();
    __declspec(dllexport) void setActiveTile(int tileRegionId);

    // Entity definition management
    __declspec(dllexport) bool createEntityDef(const char* entityName, EntityDataStruct* data);
    __declspec(dllexport) bool editEntityDef(const char* entityName, EntityDataStruct* data);
    __declspec(dllexport) bool deleteEntityDef(const char* entityName);
    __declspec(dllexport) bool getEntityDef(const char* entityName, EntityDataStruct* outData);
    __declspec(dllexport) bool getEntityDefAt(int index, EntityDataStruct* outData);
    __declspec(dllexport) int getEntityDefCount();
    __declspec(dllexport) bool setActiveEntityDef(const char* entityName);

    // Entity instances managment
    __declspec(dllexport) void setEntitySelectionChangedCallback(EntitySelectionChangedCallback callback);
    __declspec(dllexport) int getEntitySelectionCount();
    __declspec(dllexport) bool getEntitySelectionInfo(int index, EntityStruct* outData);
    __declspec(dllexport) bool selectEntityByUID(const char* uid);
    __declspec(dllexport) bool selectEntityInLayerByUID(const char* layerName, const char* uid);
    __declspec(dllexport) void deselectEntity();

    // Layer management
    __declspec(dllexport) bool createTilemapLayer(const char* layerName, const char* tilesetName, int tileSize, int index);
    __declspec(dllexport) void createEntityLayer(const char* layerName);
    __declspec(dllexport) void createFolderLayer(const char* layerName);

    __declspec(dllexport) int getLayerCount();
    __declspec(dllexport) bool getLayerInfo(const char* layerName, LayerInfoStruct* outInfo);
    __declspec(dllexport) bool getLayerInfoAt(int index, LayerInfoStruct* outInfo);

    __declspec(dllexport) bool replaceLayerTileset(const char* layerName, const char* newTilesetName);

    __declspec(dllexport) bool setActiveLayer(const char* layerName);
    __declspec(dllexport) bool setActiveLayerAt(int index);
    __declspec(dllexport) bool setLayerProperties(const char* layerName, LayerInfoStruct* properties);
    __declspec(dllexport) bool setLayerPropertiesAt(int index, LayerInfoStruct* properties);
    __declspec(dllexport) bool removeLayer(const char* layerName);
    __declspec(dllexport) bool removeLayerByIndex(int index);

    __declspec(dllexport) bool moveLayerUp(const char* layerName);
    __declspec(dllexport) bool moveLayerDown(const char* layerName);
    __declspec(dllexport) bool moveLayerTo(const char* layerName, int newIndex);
    __declspec(dllexport) bool moveLayerUpByIndex(int index);
    __declspec(dllexport) bool moveLayerDownByIndex(int index);

    // Batch management (for entity layers only)
    __declspec(dllexport) int getEntityLayerBatchCount(const char* layerName);
    __declspec(dllexport) int getEntityLayerBatchCountAt(int index);
    __declspec(dllexport) const char* getEntityLayerBatchTilesetName(const char* layerName, int batchIndex);
    __declspec(dllexport) int getEntityLayerInstanceCount(const char* layerName, int batchIndex);
    __declspec(dllexport) int getEntityLayerInstanceAt(const char* layerName, int batchIndex, int instanceIndex, EntityStruct* outData);

    // batch movement
    __declspec(dllexport) bool moveEntityLayerBatchUp(const char* layerName, int batchIndex);
    __declspec(dllexport) bool moveEntityLayerBatchDown(const char* layerName, int batchIndex);
    __declspec(dllexport) bool moveEntityLayerBatchTo(const char* layerName, int batchIndex, int newIndex);
    __declspec(dllexport) bool moveEntityLayerBatchUpByIndex(int layerIndex, int batchIndex);
    __declspec(dllexport) bool moveEntityLayerBatchDownByIndex(int layerIndex, int batchIndex);
    __declspec(dllexport) bool moveEntityLayerBatchToByIndex(int layerIndex, int batchIndex, int newIndex);
    
    __declspec(dllexport) void setToolType(int toolType);
    __declspec(dllexport) int getToolType();

    __declspec(dllexport) void toggleLabels(bool enable);
}

#endif // EDITOR_NATIVE_H
