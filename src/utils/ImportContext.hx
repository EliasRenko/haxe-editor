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
    var createTileset:(String, String, Int)->Void;
    var createEntity:(String, Int, Int, String)->String;
    var setEntityRegionPixels:(String, Int, Int, Int, Int)->Void;
    var setCurrentTileset:(String, Int)->Void;
    var updateMapBounds:(Float, Float, Float, Float)->Void;
    var createTilemapLayer:(String, String, Int)->TilemapLayer;
    var createEntityLayer:(String, String)->EntityLayer;
}
