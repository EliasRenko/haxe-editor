package utils;

import Renderer;
import layers.TilemapLayer;
import layers.EntityLayer;
import manager.TilesetManager;
import manager.EntityManager;

/**
 * Context object for import operations
 * Contains callbacks and managers needed during import
 */
typedef ImportContext = {
    var renderer:Renderer;
    var tilesetManager:TilesetManager;
    var entityManager:EntityManager;
    var clearLayers:Void->Void;
    var createTileset:(String, String)->Void;
    var createEntityFull:(String, Int, Int, String, Int, Int, Int, Int, Float, Float)->String;
    var setCurrentTileset:(String)->Void;
    var updateMapBounds:(Float, Float, Float, Float)->Void;
    var setTileSize:(Int, Int)->Void;
    var createTilemapLayer:(String, String, Int, Int)->TilemapLayer;
    // now only name is required; tilesets are handled per-entity during placement
    var createEntityLayer:(String)->EntityLayer;
}
