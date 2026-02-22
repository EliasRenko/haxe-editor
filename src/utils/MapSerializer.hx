package utils;

import layers.Layer;
import layers.TilemapLayer;
import layers.EntityLayer;
import manager.TilesetManager;
import manager.EntityManager;
import utils.ImportContext;

/**
 * Handles importing and exporting map data to JSON format
 * Version 1.3 format supports both tilemap and entity layers
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
        tileSize:Int,
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
                        var gridX = Std.int(tile.x / tileset.tileSize);
                        var gridY = Std.int(tile.y / tileset.tileSize);
                        
                        // Get tile region (atlas index)
                        var region = tile.regionId;
                        
                        layerTiles.push({
                            gridX: gridX,
                            gridY: gridY,
                            x: tile.x,
                            y: tile.y,
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
                        visible: tilemapLayer.visible,
                        tiles: layerTiles,
                        tileCount: layerTiles.length
                    });
                    totalTileCount += layerTiles.length;
                }
            } else if (Std.isOfType(layer, EntityLayer)) {
                var entityLayer:EntityLayer = cast layer;
                var layerEntities:Array<Dynamic> = [];
                
                // Export all entities from this layer
                for (entityId in entityLayer.entities.keys()) {
                    var entityData = entityLayer.entities.get(entityId);
                    layerEntities.push({
                        name: entityData.name,
                        x: entityData.x,
                        y: entityData.y
                    });
                }
                
                // Only add layer if it has entities
                if (layerEntities.length > 0) {
                    layersData.push({
                        type: "entity",
                        name: entityLayer.id,
                        tilesetName: entityLayer.tileset.name,
                        visible: entityLayer.visible,
                        entities: layerEntities,
                        entityCount: layerEntities.length
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
                texturePath: tileset.texturePath,
                tileSize: tileset.tileSize
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
            version: "1.3",
            tilesets: tilesetsArray,
            entityDefinitions: entitiesArray,
            currentTileset: tilesetManager.currentTilesetName,
            mapBounds: {
                x: mapBounds.x,
                y: mapBounds.y,
                width: mapBounds.width,
                height: mapBounds.height,
                gridWidth: Std.int(mapBounds.width / tileSize),
                gridHeight: Std.int(mapBounds.height / tileSize)
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
                    var size:Int = tilesetData.tileSize;
                    
                    // Only load if not already loaded
                    if (!context.tilesetManager.exists(name)) {
                        context.createTileset(path, name, size);
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
                var tileset = context.tilesetManager.tilesets.get(currentName);
                if (tileset != null) {
                    context.setCurrentTileset(currentName, tileset.tileSize);
                }
            }
            
            // Update map bounds
            if (data.mapBounds != null) {
                context.updateMapBounds(
                    data.mapBounds.x,
                    data.mapBounds.y,
                    data.mapBounds.width,
                    data.mapBounds.height
                );
            }
            
            // Create layers and place tiles/entities
            var importedCount = 0;
            var layersData:Array<Dynamic> = data.layers;
            
            if (layersData != null) {
                for (layerData in layersData) {
                    var layerType:String = layerData.type != null ? layerData.type : "tilemap";
                    var layerName:String = layerData.name != null ? layerData.name : "Layer_" + layerData.tilesetName;
                    var tilesetName:String = layerData.tilesetName;
                    var tileset = context.tilesetManager.tilesets.get(tilesetName);
                    
                    if (tileset == null) {
                        trace("Skipping layer with unknown tileset: " + tilesetName);
                        continue;
                    }
                    
                    if (layerType == "tilemap") {
                        // Create a new tilemap layer via callback
                        var tilemapLayer = context.createTilemapLayer(layerName, tilesetName, -1);
                        
                        if (tilemapLayer != null) {
                            // Set visibility
                            if (layerData.visible != null) {
                                tilemapLayer.visible = layerData.visible;
                            }
                            
                            // Add tiles
                            if (layerData.tiles != null) {
                                var tiles:Array<Dynamic> = layerData.tiles;
                                
                                for (tileData in tiles) {
                                    var x:Float = tileData.x;
                                    var y:Float = tileData.y;
                                    var region:Int = tileData.region;
                                    var gridX:Int = tileData.gridX;
                                    var gridY:Int = tileData.gridY;
                                    var gridKey = gridX + "_" + gridY;
                                    
                                    // Add tile using the layer's batch
                                    var tileId = tilemapLayer.managedTileBatch.addTile(x, y, tileset.tileSize, tileset.tileSize, region);
                                    
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
                        // Create a new entity layer via callback
                        var entityLayer = context.createEntityLayer(layerName, tilesetName);
                        
                        if (entityLayer != null) {
                            // Set visibility
                            if (layerData.visible != null) {
                                entityLayer.visible = layerData.visible;
                            }
                            
                            // Add entities
                            if (layerData.entities != null) {
                                var entities:Array<Dynamic> = layerData.entities;
                                
                                for (entityData in entities) {
                                    var entityName:String = entityData.name;
                                    var x:Float = entityData.x;
                                    var y:Float = entityData.y;
                                    
                                    // Get entity definition
                                    var entityDef = context.entityManager.getEntityDefinition(entityName);
                                    if (entityDef != null) {
                                        // Add entity to the layer
                                        entityLayer.addEntity(
                                            entityDef.name,
                                            x,
                                            y,
                                            entityDef.width,
                                            entityDef.height,
                                            entityDef.regionX,
                                            entityDef.regionY,
                                            entityDef.regionWidth,
                                            entityDef.regionHeight
                                        );
                                        importedCount++;
                                    }
                                }
                                
                                // Upload all entity data to GPU after adding all entities
                                if (entityLayer.managedTileBatch.needsBufferUpdate) {
                                    entityLayer.managedTileBatch.updateBuffers(context.renderer);
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
