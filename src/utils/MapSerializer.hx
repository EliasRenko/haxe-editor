package utils;

import layers.Layer;
import layers.TilemapLayer;
import layers.EntityLayer;
import Tileset;
import manager.TilesetManager;
import manager.EntityManager;
import utils.ImportContext;

/**
 * Handles importing and exporting map data to JSON format
 * Version 1.5 format adds pivotX/pivotY per entity
 */
class MapSerializer {
    
    /**
     * Export map data to JSON format
     * @param entities Array of all entities (layers)
     * @param tilesetManager Tileset manager instance
     * @param entityManager Entity manager instance
     * @param mapBounds Map bounds object {x, y, width, height}
     * @param tileSize Default tile size
     * @param filePath Absolute path to save the JSON file
     * @return Number of tiles exported, or -1 on error
     */
    public static function exportToJSON(
        entities:Array<Dynamic>,
        tilesetManager:TilesetManager,
        entityManager:EntityManager,
        mapBounds:Dynamic,
        tileSizeX:Int,
        tileSizeY:Int,
        filePath:String
    ):Int {
        var layersData:Array<Dynamic> = [];
        var totalTileCount = 0;
        
        // Iterate through all layers and export both tilemap and entity layers
        for (entity in entities) {
            if (!Std.isOfType(entity, Layer)) continue;
            var layer:Layer = cast entity;
            
            if (Std.isOfType(layer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast layer;
                var tileset = tilesetManager.tilesets.get(tilemapLayer.tileset.name);
                
                if (tileset == null) continue;
                
                var layerTiles:Array<Dynamic> = [];
                
                // Get all tiles from this layer's batch
                for (tileId in 0...1000) { // MAX_TILES
                    var tile = tilemapLayer.managedTileBatch.getTile(tileId);
                    
                    if (tile != null) {
                        // Convert world position back to grid coordinates
                        var gridX = Std.int(tile.x / tileSizeX);
                        var gridY = Std.int(tile.y / tileSizeY);
                        
                        // Get tile region (atlas index)
                        var region = tile.regionId;
                        
                        layerTiles.push({
                            gridX: gridX,
                            gridY: gridY,
                            region: region
                        });
                    }
                }
                
                // Only add layer if it has tiles
                if (layerTiles.length > 0) {
                    layersData.push({
                        type: "tilemap",
                        name: tilemapLayer.id,
                        tilesetName: tilemapLayer.tileset.name,
                        tileSize: tilemapLayer.tileSize,
                        visible: tilemapLayer.visible,
                        tiles: layerTiles,
                        tileCount: layerTiles.length
                    });
                    totalTileCount += layerTiles.length;
                }
            } else if (Std.isOfType(layer, EntityLayer)) {
                var entityLayer:EntityLayer = cast layer;
                var batchesData:Array<Dynamic> = [];
                var totalEntities = 0;

                // Export each batch separately with its own list of entities
                for (entry in entityLayer.batches) {
                    var batchEntities:Array<Dynamic> = [];
                    for (entityId in entry.entities.keys()) {
                        var entityData = entry.entities.get(entityId);
                        batchEntities.push({
                            name: entityData.name,
                            x: entityData.x,
                            y: entityData.y,
                            pivotX: entityData.pivotX,
                            pivotY: entityData.pivotY
                        });
                    }
                    if (batchEntities.length > 0) {
                        batchesData.push({
                            tilesetName: entry.tileset.name,
                            entities: batchEntities,
                            count: batchEntities.length
                        });
                        totalEntities += batchEntities.length;
                    }
                }

                // Only add layer if it has any batches with entities
                if (batchesData.length > 0) {
                    layersData.push({
                        type: "entity",
                        name: entityLayer.id,
                        visible: entityLayer.visible,
                        batches: batchesData,
                        entityCount: totalEntities
                    });
                }
            }
        }
        
        // Collect tileset info
        var tilesetsArray:Array<Dynamic> = [];
        for (tilesetName in tilesetManager.tilesets.keys()) {
            var tileset = tilesetManager.tilesets.get(tilesetName);
            tilesetsArray.push({
                name: tileset.name,
                texturePath: tileset.texturePath
            });
        }
        
        // Collect entity definitions
        var entitiesArray:Array<Dynamic> = [];
        for (entityName in entityManager.entityDefinitions.keys()) {
            var entityDef = entityManager.getEntityDefinition(entityName);
            entitiesArray.push({
                name: entityDef.name,
                width: entityDef.width,
                height: entityDef.height,
                tilesetName: entityDef.tilesetName,
                regionX: entityDef.regionX,
                regionY: entityDef.regionY,
                regionWidth: entityDef.regionWidth,
                regionHeight: entityDef.regionHeight
            });
        }
        
        // Create JSON structure
        var data = {
            version: "1.5",
            tilesets: tilesetsArray,
            entityDefinitions: entitiesArray,
            currentTileset: tilesetManager.currentTilesetName,
            mapBounds: {
                x: mapBounds.x,
                y: mapBounds.y,
                width: mapBounds.width,
                height: mapBounds.height,
                tileSizeX: tileSizeX,
                tileSizeY: tileSizeY,
                gridWidth: Std.int(mapBounds.width / tileSizeX),
                gridHeight: Std.int(mapBounds.height / tileSizeY)
            },
            layers: layersData,
            tileCount: totalTileCount
        };
        
        // Convert to JSON string with pretty formatting
        var jsonString = haxe.Json.stringify(data, null, "  ");
        
        // Write to file
        try {
            sys.io.File.saveContent(filePath, jsonString);
            trace("Exported " + totalTileCount + " tiles in " + layersData.length + " layers to: " + filePath);
            return totalTileCount;
        } catch (e:Dynamic) {
            trace("Error exporting JSON: " + e);
            return -1;
        }
    }
    
    /**
     * Import map data from JSON format
     * @param filePath Absolute path to the JSON file
     * @param context Import context containing all necessary callbacks and managers
     * @return Number of tiles/entities imported, or -1 on error
     */
    public static function importFromJSON(filePath:String, context:ImportContext):Int {
        var tileSizeMap:Map<String, Int> = new Map();
        try {
            // Read JSON file
            var jsonString = sys.io.File.getContent(filePath);
            var data:Dynamic = haxe.Json.parse(jsonString);
            
            // Clear existing layers via callback
            context.clearLayers();
            
            // Load tilesets first
            if (data.tilesets != null) {
                var tilesetsArray:Array<Dynamic> = data.tilesets;
                for (tilesetData in tilesetsArray) {
                    var name:String = tilesetData.name;
                    var path:String = tilesetData.texturePath;
                    // Old-format files stored tileSize on the tileset; keep as fallback
                    if (tilesetData.tileSize != null) tileSizeMap.set(name, Std.int(tilesetData.tileSize));
                    
                    // Only load if not already loaded
                    if (!context.tilesetManager.exists(name)) {
                        context.createTileset(path, name);
                        trace("Loaded tileset from JSON: " + name);
                    }
                }
            }
            
            // Load entity definitions
            if (data.entityDefinitions != null) {
                var entitiesArray:Array<Dynamic> = data.entityDefinitions;
                for (entityData in entitiesArray) {
                    var name:String = entityData.name;
                    var width:Int = entityData.width;
                    var height:Int = entityData.height;
                    var tilesetName:String = entityData.tilesetName;
                    var regionX:Int = entityData.regionX;
                    var regionY:Int = entityData.regionY;
                    var regionWidth:Int = entityData.regionWidth;
                    var regionHeight:Int = entityData.regionHeight;
                    
                    context.createEntity(name, width, height, tilesetName);
                    context.setEntityRegionPixels(name, regionX, regionY, regionWidth, regionHeight);
                    trace("Loaded entity definition from JSON: " + name);
                }
            }
            
            // Set current tileset
            if (data.currentTileset != null) {
                var currentName:String = data.currentTileset;
                if (context.tilesetManager.exists(currentName)) {
                    context.setCurrentTileset(currentName);
                }
            }
            
            // Tile size used for recomputing world positions from grid coords (defaults, overridden by mapBounds)
            var tsx:Int = (data.mapBounds != null && data.mapBounds.tileSizeX != null) ? Std.int(data.mapBounds.tileSizeX) : 64;
            var tsy:Int = (data.mapBounds != null && data.mapBounds.tileSizeY != null) ? Std.int(data.mapBounds.tileSizeY) : 64;

            // Update map bounds
            if (data.mapBounds != null) {
                context.updateMapBounds(
                    data.mapBounds.x,
                    data.mapBounds.y,
                    data.mapBounds.width,
                    data.mapBounds.height
                );
                // Restore tile size
                context.setTileSize(tsx, tsy);
            }
            
            // Create layers and place tiles/entities
            var importedCount = 0;
            var layersData:Array<Dynamic> = data.layers;
            
            if (layersData != null) {
                for (layerData in layersData) {
                    var layerType:String = layerData.type != null ? layerData.type : "tilemap";
                    var layerName:String = layerData.name != null ? layerData.name : "Layer_" + layerData.tilesetName;
                    
                    if (layerType == "tilemap") {
                        var tilesetName:String = layerData.tilesetName;
                        var tileset:Tileset = context.tilesetManager.tilesets.get(tilesetName);
                        
                        if (tileset == null) {
                            trace("Skipping layer with unknown tileset: " + tilesetName);
                            continue;
                        }
                        
                        // Create a new tilemap layer via callback
                        // New format: tileSize is on the layer; old format: fall back to tileSizeMap (stored on tileset)
                        var layerTileSize:Int = layerData.tileSize != null ? Std.int(layerData.tileSize)
                            : tileSizeMap.exists(tilesetName) ? tileSizeMap.get(tilesetName) : 64;
                        var tilemapLayer = context.createTilemapLayer(layerName, tilesetName, -1, layerTileSize);
                        
                        if (tilemapLayer != null) {
                            // Set visibility
                            if (layerData.visible != null) {
                                tilemapLayer.visible = layerData.visible;
                            }
                            
                            // Add tiles
                            if (layerData.tiles != null) {
                                var tiles:Array<Dynamic> = layerData.tiles;
                                
                                for (tileData in tiles) {
                                    var region:Int = tileData.region;
                                    var gridX:Int = tileData.gridX;
                                    var gridY:Int = tileData.gridY;
                                    var gridKey = gridX + "_" + gridY;
                                    
                                    // Compute world position from grid coords and tile size
                                    var x:Float = gridX * tsx;
                                    var y:Float = gridY * tsy;
                                    
                                    // Add tile using the layer's batch
                                    var tileId = tilemapLayer.managedTileBatch.addTile(x, y, tilemapLayer.tileSize, tilemapLayer.tileSize, region);
                                    
                                    if (tileId >= 0) {
                                        tilemapLayer.tileGrid.set(gridKey, tileId);
                                        importedCount++;
                                    }
                                }
                                
                                // Upload all tile data to GPU after adding all tiles
                                if (tilemapLayer.managedTileBatch.needsBufferUpdate) {
                                    tilemapLayer.managedTileBatch.updateBuffers(context.renderer);
                                }
                            }
                        }
                    } else if (layerType == "entity") {
                        // Create a new entity layer via callback (now takes only name)
                        var entityLayer = context.createEntityLayer(layerName);
                        
                        if (entityLayer != null) {
                            // Set visibility
                            if (layerData.visible != null) {
                                entityLayer.visible = layerData.visible;
                            }
                            
                            // Add entities
                            if (layerData.batches != null) {
                                var batches:Array<Dynamic> = layerData.batches;
                                
                                for (batchData in batches) {
                                    var tsName:String = batchData.tilesetName;
                                    var tileset:Tileset = context.tilesetManager.tilesets.get(tsName);
                                    if (tileset == null) continue;

                                    var programInfo = context.renderer.getProgramInfo("texture");
                                    
                                    // iterate entities within this batch
                                    var batchEntities:Array<Dynamic> = batchData.entities;
                                    for (entityData in batchEntities) {
                                        var entityName:String = entityData.name;
                                        var x:Float = entityData.x;
                                        var y:Float = entityData.y;
                                        var pivotX:Float = entityData.pivotX != null ? entityData.pivotX : 0.0;
                                        var pivotY:Float = entityData.pivotY != null ? entityData.pivotY : 0.0;
                                        var entityDef = context.entityManager.getEntityDefinition(entityName);
                                        if (entityDef == null) continue;
                                        entityLayer.placeEntity(entityDef, tileset, x, y, context.renderer, programInfo, pivotX, pivotY);
                                        importedCount++;
                                    }
                                }
                            } else if (layerData.entities != null) {
                                // legacy flat list support
                                var entities:Array<Dynamic> = layerData.entities;
                                var programInfo = context.renderer.getProgramInfo("texture");
                                for (entityData in entities) {
                                    var entityName:String = entityData.name;
                                    var x:Float = entityData.x;
                                    var y:Float = entityData.y;
                                    var pivotX:Float = entityData.pivotX != null ? entityData.pivotX : 0.0;
                                    var pivotY:Float = entityData.pivotY != null ? entityData.pivotY : 0.0;
                                    var tsName:String = Std.is(entityData.tilesetName,String) ? entityData.tilesetName : null;
                                    var entityDef = context.entityManager.getEntityDefinition(entityName);
                                    if (entityDef == null) continue;
                                    var lookupName = tsName != null ? tsName : entityDef.tilesetName;
                                    var tileset:Tileset = context.tilesetManager.tilesets.get(lookupName);
                                    if (tileset == null) continue;
                                    entityLayer.placeEntity(entityDef, tileset, x, y, context.renderer, programInfo, pivotX, pivotY);
                                    importedCount++;
                                }
                            }
                            
                            // Upload all entity data batches to GPU after adding all entities
                            for (eentry in entityLayer.batches) {
                                if (eentry.batch.needsBufferUpdate) {
                                    eentry.batch.updateBuffers(context.renderer);
                                }
                            }
                        }
                    }
                }
            }
            
            return importedCount;
            
        } catch (e:Dynamic) {
            trace("Error importing JSON: " + e);
            return -1;
        }
    }
}
