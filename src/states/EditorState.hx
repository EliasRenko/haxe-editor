package states;

import layers.ITilesLayer;
import Log.LogCategory;
import State;
import App;
import Renderer;
import display.Grid;
import display.ManagedTileBatch;
import display.MapFrame;
import display.LineBatch;
import layers.Layer;
import layers.TilemapLayer;
import layers.EntityLayer;
import layers.FolderLayer;
import manager.TilesetManager;
import manager.EntityManager;
import utils.MapSerializer;

class EditorState extends State {
    
    private var grid:Grid;
    private var tileBatch:ManagedTileBatch;
    private var mapFrame:MapFrame;
    private var worldAxes:LineBatch;
    
    // Options
    public var showWorldAxes:Bool = true; // Show X/Y axes at origin (0,0)
    public var deleteOutOfBoundsTilesOnResize:Bool = true; // Auto-delete tiles when shrinking frame

    // Managers
    public var tilesetManager:TilesetManager = new TilesetManager();
    public var entityManager:EntityManager = new EntityManager();
    
    // Tile editor settings
    private var tileSize:Int = 32; // Size of each tile in pixels
    private var tileRegions:Array<Int> = []; // Available tile regions (for backward compatibility)
    
    // Layer management (layers are stored in entities array)
    private var activeLayer:Layer = null;
    //public var selectedTileRegion:Int = 0;
    
    // Map bounds (defines the editable area)
    private var mapX:Float = 0;
    private var mapY:Float = 0;
    private var mapWidth:Float = 1024; // 32x32 tiles
    private var mapHeight:Float = 1024;
    
    // Resize state
    private var resizeMode:String = null; // "top", "bottom", "left", "right", or null
    private var resizeDragStart:{x:Float, y:Float} = null;
    private var resizeOriginalBounds:{x:Float, y:Float, width:Float, height:Float} = null;
    private var minMapSize:Float = 320.0; // 10 tiles minimum (10 * 32px)
    
    public function new(app:App) {
        super("EditorState", app);
    }
    
    override public function init():Void {
        super.init();
        
        // Setup camera for 2D orthographic view with center-based zoom
        camera.ortho = true;
        
        // Initialize camera to center of screen for proper centered projection
        var windowWidth = app.window.size.x;
        var windowHeight = app.window.size.y;
        camera.x = windowWidth * 0.5;
        camera.y = windowHeight * 0.5;
        
        // Create infinite grid for visual reference
        var gridVertShader = app.resources.getText("shaders/grid.vert");
        var gridFragShader = app.resources.getText("shaders/grid.frag");
        var gridProgramInfo = app.renderer.createProgramInfo("grid", gridVertShader, gridFragShader);
        
        grid = new Grid(gridProgramInfo, 5000.0); // 5000 unit quad
        grid.gridSize = 128.0; // 128 pixel large grid
        grid.subGridSize = 32.0; // 32 pixel small grid
        grid.setGridColor(0.2, 0.4, 0.6); // Blue-ish grid lines
        grid.setBackgroundColor(0.05, 0.05, 0.1); // Dark blue background
        grid.fadeDistance = 3000.0;
        grid.z = 0.0;
        grid.depthTest = false;
        grid.init(app.renderer);
        
        // Clip grid to map bounds
        grid.setBounds(mapX, mapY, mapX + mapWidth, mapY + mapHeight);
        
        // Setup map frame
        setupMapFrame(app.renderer);
        
        // Setup world axes
        setupWorldAxes(app.renderer);

        // Create default programInfo
        var textureVertShader = app.resources.getText("shaders/texture.vert");
        var textureFragShader = app.resources.getText("shaders/texture.frag");
        app.renderer.createProgramInfo("texture", textureVertShader, textureFragShader);
    }

    // CHECKED!
    public function createTileset(texturePath:String, tilesetName:String, tileSize:Int):String {
        if (!app.resources.cached(texturePath)) {
            app.log.info(LogCategory.APP, "Loading texture: " + texturePath);
            app.resources.loadTexture(texturePath, false);
        }

        if (tilesetManager.exists(tilesetName)) {
            var error:String = "Tileset with the name " + tilesetName + " already exists";
            app.log.info(LogCategory.APP, error);
            return error;
        }
        
        var tileTexture:Texture = app.renderer.uploadTexture(app.resources.getTexture(texturePath, false));
        tilesetManager.setTileset(tileTexture, tilesetName, texturePath, tileSize);

        return null;
    }
    
    // ===== ENTITY DEFINITION MANAGEMENT =====
    
    // CHECKED!
    public function createEntity(entityName:String, width:Int, height:Int, tilesetName:String):String {
        if (!tilesetManager.exists(tilesetName)) {
            var error:String = "Cannot create entity. Tileset with the name " + tilesetName + " does not exist";
            app.log.info(LogCategory.APP, error);
            return error;
        }

        if (entityManager.exists(entityName)) {
            var error:String = "Entity with the name " + entityName + " already exists";
            app.log.info(LogCategory.APP, error);
            return error;
        }

        entityManager.setEntity(entityName, width, height, tilesetName);

        return null;
    }
    
    public function setEntityRegion(entityName:String, x:Int, y:Int, width:Int, height:Int):Void {
        entityManager.setEntityRegion(tilesetManager, entityName, x, y, width, height);

        
    }

    public function setEntityRegionPixels(entityName:String, x:Int, y:Int, width:Int, height:Int):Void {
        var entity = entityManager.getEntityDefinition(entityName);
        if (entity == null) {
            trace("Cannot set region: entity not found: " + entityName);
            return;
        }
        
        // Set pixel coordinates directly (no conversion)
        entity.regionX = x;
        entity.regionY = y;
        entity.regionWidth = width;
        entity.regionHeight = height;
    }
    
    /**
     * Set the currently active entity for placement
     * @param entityName Name of the entity to make active
     * @return True if entity exists, false otherwise
     */
    public function setActiveEntity(entityName:String):Bool {
        if (!entityManager.exists(entityName)) {
            trace("Cannot set active entity: entity not found: " + entityName);
            return false;
        }
        
        entityManager.selectedEntityName = entityName;
        trace("Active entity set to: " + entityName);
        return true;
    }
    
    /**
     * Setup the map frame (visual boundary)
     */
    private function setupMapFrame(renderer:Renderer):Void {
        // Load line shader for frame rendering
        var lineVertShader = app.resources.getText("shaders/line.vert");
        var lineFragShader = app.resources.getText("shaders/line.frag");
        
        var lineProgramInfo = renderer.createProgramInfo("line", lineVertShader, lineFragShader);
        
        mapFrame = new MapFrame(lineProgramInfo, mapX, mapY, mapWidth, mapHeight);
        mapFrame.init(renderer);
        
        // MapFrame renders its own LineBatch internally
        // No need to add it as an entity
    }
    
    /**
     * Setup infinite world axes at origin (0,0)
     * Red = X axis (horizontal), Green = Y axis (vertical)
     */
    private function setupWorldAxes(renderer:Renderer):Void {
        
        var lineProgramInfo = app.renderer.getProgramInfo("line");
        if (lineProgramInfo == null) {
            return;
        }
        
        worldAxes = new LineBatch(lineProgramInfo, true);
        worldAxes.depthTest = false;
        worldAxes.visible = showWorldAxes;
        
        // Initialize first (creates buffers)
        worldAxes.init(renderer);
        
        // THEN add the lines
        var axisLength = 10000.0;
        var z = 0.05;
        
        // X axis - Red
        var redColor = [1.0, 0.0, 0.0, 1.0];
        worldAxes.addLine(-axisLength, 0, z, axisLength, 0, z, redColor, redColor);
        
        // Y axis - Green
        var greenColor = [0.0, 1.0, 0.0, 1.0];
        worldAxes.addLine(0, -axisLength, z, 0, axisLength, z, greenColor, greenColor);
        
        // Upload the vertex data to GPU immediately
        worldAxes.updateBuffers(renderer);
        
        // Add to entity system for rendering
        //worldAxesEntity = new DisplayEntity(worldAxes, "worldAxes");
        //addEntity(worldAxesEntity);
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Handle mouse input for tile placement/removal
        handleTileInput();
    }
    
    /**
     * Handle mouse input for placing and removing tiles, and resizing the map frame
     */
    private function handleTileInput():Void {
        var mouse = app.input.mouse;

        // Get mouse screen position from C# (assumed to be in screen coordinates)
        var screenX = mouse.x;
        var screenY = mouse.y;

        // Convert screen position to world position using camera
        var worldPos = screenToWorld(screenX, screenY);

        // Handle resize drag (if in resize mode)
        if (resizeMode != null) {
            if (mouse.check(1)) {
                // Continue dragging
                handleResizeDrag(worldPos.x, worldPos.y);
            } else {
                // Released mouse - end resize
                resizeMode = null;
                resizeDragStart = null;
                resizeOriginalBounds = null;
            }
            return; // Skip tile placement while resizing
        }

        // Left click - check for resize handle first, then place tile
        if (mouse.pressed(1)) { // Button just pressed
            // Check if clicking on a resize handle
            var handle = getHandleAt(worldPos.x, worldPos.y);
            if (handle != null) {
                // Start resize
                resizeMode = handle;
                resizeDragStart = {x: worldPos.x, y: worldPos.y};
                resizeOriginalBounds = {
                    x: mapX,
                    y: mapY,
                    width: mapWidth,
                    height: mapHeight
                };
                return;
            }
        }

		if (activeLayer != null && Std.isOfType(activeLayer, EntityLayer)) {
            if (mouse.pressed(1)) {
                placeEntityAt(worldPos.x, worldPos.y);
            } else if (mouse.pressed(3)) {
                removeEntityAt(worldPos.x, worldPos.y);
            }
		}

        if (activeLayer != null && Std.isOfType(activeLayer, TilemapLayer)) {
            if (mouse.check(1)) {
                placeTileAt(worldPos.x, worldPos.y);
            } else if (mouse.check(3)) {
                removeTileAt(worldPos.x, worldPos.y);
            }
        }
    }
    
    /**
     * Check if world position is over a resize handle
     * Returns: "top", "bottom", "left", "right", or null
     */
    private function getHandleAt(worldX:Float, worldY:Float):String {
        if (mapFrame == null) return null;
        
        // Check each handle
        var handles = [
            {name: "top", bounds: mapFrame.getTopHandle()},
            {name: "bottom", bounds: mapFrame.getBottomHandle()},
            {name: "left", bounds: mapFrame.getLeftHandle()},
            {name: "right", bounds: mapFrame.getRightHandle()}
        ];
        
        for (handle in handles) {
            var b = handle.bounds;
            if (worldX >= b.x && worldX <= b.x + b.width &&
                worldY >= b.y && worldY <= b.y + b.height) {
                return handle.name;
            }
        }
        
        return null;
    }
    
    /**
     * Handle resize dragging with constraints
     */
    private function handleResizeDrag(worldX:Float, worldY:Float):Void {
        if (resizeMode == null || resizeDragStart == null || resizeOriginalBounds == null) return;
        
        var deltaX = worldX - resizeDragStart.x;
        var deltaY = worldY - resizeDragStart.y;
        
        // Snap delta to grid (32px increments)
        deltaX = Math.round(deltaX / tileSize) * tileSize;
        deltaY = Math.round(deltaY / tileSize) * tileSize;
        
        var newX = resizeOriginalBounds.x;
        var newY = resizeOriginalBounds.y;
        var newWidth = resizeOriginalBounds.width;
        var newHeight = resizeOriginalBounds.height;
        
        switch (resizeMode) {
            case "top":
                // Move top edge up/down (changes Y and height)
                newY = resizeOriginalBounds.y + deltaY;
                newHeight = resizeOriginalBounds.height - deltaY;
                
            case "bottom":
                // Move bottom edge up/down (changes height only)
                newHeight = resizeOriginalBounds.height + deltaY;
                
            case "left":
                // Move left edge left/right (changes X and width)
                newX = resizeOriginalBounds.x + deltaX;
                newWidth = resizeOriginalBounds.width - deltaX;
                
            case "right":
                // Move right edge left/right (changes width only)
                newWidth = resizeOriginalBounds.width + deltaX;
        }
        
        // Apply minimum size constraint
        if (newWidth < minMapSize) {
            if (resizeMode == "left") {
                // Adjust X to maintain right edge position
                newX = newX + (newWidth - minMapSize);
            }
            newWidth = minMapSize;
        }
        if (newHeight < minMapSize) {
            if (resizeMode == "top") {
                // Adjust Y to maintain bottom edge position
                newY = newY + (newHeight - minMapSize);
            }
            newHeight = minMapSize;
        }
        
        // Update map bounds
        mapX = newX;
        mapY = newY;
        mapWidth = newWidth;
        mapHeight = newHeight;
        
        // Update frame visual
        if (mapFrame != null) {
            mapFrame.setBounds(mapX, mapY, mapWidth, mapHeight);
        }
        
        // Update grid bounds to match map frame
        if (grid != null) {
            grid.setBounds(mapX, mapY, mapX + mapWidth, mapY + mapHeight);
        }
        
        // Optionally delete tiles outside new bounds
        if (deleteOutOfBoundsTilesOnResize) {
            cleanupTilesOutsideBounds();
        }
    }
    
    /**
     * Convert screen coordinates to world coordinates
     */
    private function screenToWorld(screenX:Float, screenY:Float):{x:Float, y:Float} {
        // Centered ortho projection: zoom happens around configurable zoom center
        var windowWidth = app.window.size.x;
        var windowHeight = app.window.size.y;
        
        // Get zoom center (defaults to screen center if not set)
        var zoomCenterX = camera.zoomCenterX != null ? camera.zoomCenterX : windowWidth * 0.5;
        var zoomCenterY = camera.zoomCenterY != null ? camera.zoomCenterY : windowHeight * 0.5;
        
        var worldX = (screenX - zoomCenterX) / camera.zoom + zoomCenterX + camera.x;
        var worldY = (screenY - zoomCenterY) / camera.zoom + zoomCenterY + camera.y;

        return {x: worldX, y: worldY};
    }
    
    /**
     * Place an entity at world position
     */
    private function placeEntityAt(worldX:Float, worldY:Float):Void {
        // Check if active layer is an entity layer
        if (activeLayer == null || !Std.isOfType(activeLayer, EntityLayer)) {
            return;
        }
        
        // Check if we have a selected entity
        if (entityManager.selectedEntityName == "" || !entityManager.exists(entityManager.selectedEntityName)) {
            return;
        }
        
        var entityLayer:EntityLayer = cast activeLayer;
        var entityDef = entityManager.getEntityDefinition(entityManager.selectedEntityName);
        
        // Check if position is within map bounds
        if (worldX < mapX || worldX >= mapX + mapWidth || 
            worldY < mapY || worldY >= mapY + mapHeight) {
            return;
        }
        
        // Add entity as a tile in the batch
        var entityId = entityLayer.addEntity(
            entityDef.name,
            worldX,
            worldY,
            entityDef.width,
            entityDef.height,
            entityDef.regionX,
            entityDef.regionY,
            entityDef.regionWidth,
            entityDef.regionHeight
        );
    }
    
    /**
     * Remove entity at world position
     */
    private function removeEntityAt(worldX:Float, worldY:Float):Void {
        // Check if active layer is an entity layer
        if (activeLayer == null || !Std.isOfType(activeLayer, EntityLayer)) {
            return;
        }
        
        var entityLayer:EntityLayer = cast activeLayer;
        
        // Find entity at this position
        var entityId = entityLayer.getEntityAt(worldX, worldY, 16.0);
        
        if (entityId >= 0) {
            entityLayer.removeEntity(entityId);
            trace("Removed entity ID: " + entityId + " at (" + worldX + ", " + worldY + ")");
        }
    }

    public function getActiveTile():Int {
        if (activeLayer == null || !Std.isOfType(activeLayer, TilemapLayer)) {
            trace("Cannot set active tile region: no active tilemap layer");
            return 0;
        }

        var tilemapLayer:TilemapLayer = cast activeLayer;
        return tilemapLayer.selectedTileRegion - 1;
    }

    public function setActiveTile(regionId:Int):Void {
        // C# sends 0-based indices, but Haxe region IDs start from 1

        if (activeLayer == null || !Std.isOfType(activeLayer, TilemapLayer)) {
            trace("Cannot set active tile region: no active tilemap layer");
            return;
        }

        var tilemapLayer:TilemapLayer = cast activeLayer;
        tilemapLayer.selectedTileRegion = regionId + 1;
        //trace("Selected tile region: " + tilemapLayer.selectedTileRegion + " (from C# index: " + regionId + ")");
    }
    
    /**
     * Place a tile at world position (snaps to grid)
     */
    private function placeTileAt(worldX:Float, worldY:Float):Void {
        // Check if active layer is a tilemap layer
        if (activeLayer == null || !Std.isOfType(activeLayer, TilemapLayer)) {
            return;
        }
        
        var tilemapLayer:TilemapLayer = cast activeLayer;
        trace("Placing tile on layer: " + tilemapLayer.id + ", tileset: " + tilemapLayer.tileset.name);
        var layerTileset = tilemapLayer.tileset;
        
        // Snap to grid (tiles are positioned by top-left corner)
        var tileX = Std.int(Math.floor(worldX / layerTileset.tileSize) * layerTileset.tileSize);
        var tileY = Std.int(Math.floor(worldY / layerTileset.tileSize) * layerTileset.tileSize);
        
        // Check if tile is within map bounds
        if (tileX < mapX || tileX >= mapX + mapWidth || 
            tileY < mapY || tileY >= mapY + mapHeight) {
            // Tile is outside map bounds
            return;
        }
        
        // Convert to grid coordinates
        var gridX = Std.int(tileX / layerTileset.tileSize);
        var gridY = Std.int(tileY / layerTileset.tileSize);
        var gridKey = gridX + "_" + gridY;
        
        // Check if tile already exists at this grid position (O(1) lookup!)
        if (tilemapLayer.tileGrid.exists(gridKey)) {
            // Tile already exists at this position, don't add another
            return;
        }
        
        // Add tile to batch using selected region ID
        var tileId = tilemapLayer.managedTileBatch.addTile(tileX, tileY, layerTileset.tileSize, layerTileset.tileSize, tilemapLayer.selectedTileRegion);
        
        if (tileId >= 0) {
            // Store in grid index for fast lookups
            tilemapLayer.tileGrid.set(gridKey, tileId);
            
            // Mark buffers as needing update
            tilemapLayer.managedTileBatch.needsBufferUpdate = true;
        }
    }
    
    /**
     * Remove tile at world position
     */
    private function removeTileAt(worldX:Float, worldY:Float):Void {
        // Check if active layer is a tilemap layer
        if (activeLayer == null || !Std.isOfType(activeLayer, TilemapLayer)) {
            return;
        }
        
        var tilemapLayer:TilemapLayer = cast activeLayer;
        var layerTileset = tilemapLayer.tileset;
        
        // Snap to grid
        var tileX = Math.floor(worldX / layerTileset.tileSize) * layerTileset.tileSize;
        var tileY = Math.floor(worldY / layerTileset.tileSize) * layerTileset.tileSize;
        
        // Check if position is within map bounds
        if (tileX < mapX || tileX >= mapX + mapWidth || 
            tileY < mapY || tileY >= mapY + mapHeight) {
            // Position is outside map bounds
            return;
        }
        
        // Convert to grid coordinates
        var gridX = Std.int(tileX / layerTileset.tileSize);
        var gridY = Std.int(tileY / layerTileset.tileSize);
        var gridKey = gridX + "_" + gridY;
        
        // Fast lookup in grid index (O(1) instead of O(n)!)
        if (tilemapLayer.tileGrid.exists(gridKey)) {
            var tileId = tilemapLayer.tileGrid.get(gridKey);
            tilemapLayer.managedTileBatch.removeTile(tileId);
            tilemapLayer.tileGrid.remove(gridKey); // Remove from grid index
            tilemapLayer.managedTileBatch.needsBufferUpdate = true;
        }
    }
    
    /**
     * Remove all tiles that are outside the current map bounds
     * Useful when shrinking the map to clean up orphaned tiles
     */
    public function cleanupTilesOutsideBounds():Int {
        var removed = 0;
        
        // Iterate through all tilemap layers
        for (entity in entities) {
            if (!Std.isOfType(entity, Layer)) continue;
            var layer:Layer = cast entity;
            if (Std.isOfType(layer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast layer;
                var keysToRemove:Array<String> = [];
                
                // Iterate through grid index to find out-of-bounds tiles
                for (gridKey in tilemapLayer.tileGrid.keys()) {
                    var tileId = tilemapLayer.tileGrid.get(gridKey);
                    var tile = tilemapLayer.managedTileBatch.getTile(tileId);
                    if (tile != null) {
                        if (tile.x < mapX || tile.x >= mapX + mapWidth || 
                            tile.y < mapY || tile.y >= mapY + mapHeight) {
                            tilemapLayer.managedTileBatch.removeTile(tileId);
                            keysToRemove.push(gridKey);
                            removed++;
                        }
                    }
                }
                
                // Remove from grid index
                for (key in keysToRemove) {
                    tilemapLayer.tileGrid.remove(key);
                }
                
                if (keysToRemove.length > 0) {
                    tilemapLayer.managedTileBatch.needsBufferUpdate = true;
                }
            }
        }
        
        return removed;
    }
    
    // ===== LAYER MANAGEMENT =====
    
    /**
     * Add a layer to the entity system (internal use)
     */
    private function addLayer(layer:Layer):Void {
        if (layer != null) {
            addEntity(layer);
            
            // If this is the first layer, make it active
            if (activeLayer == null) {
                activeLayer = layer;
                
                // Auto-switch tileset if it's a tilemap layer
                if (Std.isOfType(layer, TilemapLayer)) {
                    var tilemapLayer:TilemapLayer = cast layer;
                    tilesetManager.setActiveTileset(tilemapLayer.tileset.name);
                }
            }
        }
    }
    
    /**
     * Add a layer at a specific position in the entity system
     * @param layer The layer to add
     * @param index Position to insert (-1 to append at end, 0 for first layer position)
     */
    private function addLayerAtIndex(layer:Layer, index:Int):Void {
        if (layer == null) return;
        
        layer.state = this;
        
        // If index is -1 or out of bounds, append to end
        if (index < 0 || index >= entities.length) {
            entities.push(layer);
        } else {
            // Find the actual entity index for the Nth layer
            var layerCount = 0;
            var insertIndex = 0;
            
            for (i in 0...entities.length) {
                if (Std.isOfType(entities[i], Layer)) {
                    if (layerCount == index) {
                        insertIndex = i;
                        break;
                    }
                    layerCount++;
                }
                insertIndex = i + 1; // Insert after last checked entity
            }
            
            entities.insert(insertIndex, layer);
        }
        
        // If this is the first layer, make it active
        if (activeLayer == null) {
            activeLayer = layer;
            
            // Auto-switch tileset if it's a tilemap layer
            if (Std.isOfType(layer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast layer;
                tilesetManager.setActiveTileset(tilemapLayer.tileset.name);
            }
        }
    }
    
    /**
     * Remove a layer from the layer list by name
     * @param layerName Name of the layer to remove
     * @return True if layer was found and removed, false otherwise
     */
    public function removeLayer(layerName:String):Bool {
        var layer = getLayerByName(layerName);
        if (layer == null) {
            trace("Layer not found: " + layerName);
            return false;
        }
        
        removeEntity(layer);
        layer.cleanup(null);
        
        // If we removed the active layer, set a new one
        if (activeLayer == layer) {
            activeLayer = getFirstLayer();
            
            // Update tileset if new active layer is a tilemap
            if (activeLayer != null && Std.isOfType(activeLayer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast activeLayer;
                tilesetManager.setActiveTileset(tilemapLayer.tileset.name);
            }
        }
        
        return true;
    }
    
    /**
     * Remove a layer from the layer list by index
     * @param index Index of the layer to remove
     * @return True if layer was found and removed, false otherwise
     */
    public function removeLayerByIndex(index:Int):Bool {
        var layer = getLayerAt(index);
        if (layer == null) {
            trace("Layer not found at index: " + index);
            return false;
        }
        
        removeEntity(layer);
        layer.cleanup(null);
        
        // If we removed the active layer, set a new one
        if (activeLayer == layer) {
            activeLayer = getFirstLayer();
            
            // Update tileset if new active layer is a tilemap
            if (activeLayer != null && Std.isOfType(activeLayer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast activeLayer;
                tilesetManager.setActiveTileset(tilemapLayer.tileset.name);
            }
        }
        
        return true;
    }
    
    /**
     * Set the active layer by name
     * Automatically switches to the layer's tileset if it's a TilemapLayer
     * @param layerName Name of the layer to make active
     * @return True if layer was found and set, false otherwise
     */
    public function setActiveLayer(layerName:String):Bool {
        var layer = getLayerByName(layerName);
        if (layer == null) {
            trace("Layer not found: " + layerName);
            return false;
        }
        
        activeLayer = layer;
        
        // If it's a tilemap layer, automatically switch to its tileset
        if (Std.isOfType(layer, TilemapLayer)) {
            var tilemapLayer:TilemapLayer = cast layer;
            return tilesetManager.setActiveTileset(tilemapLayer.tileset.name);
        }
        
        return true;
    }
    
    /**
     * Set the active layer by index
     * @param index Index of the layer to make active
     * @return True if layer was found and set, false otherwise
     */
    public function setActiveLayerAt(index:Int):Bool {
        var layer = getLayerAt(index);
        if (layer == null) {
            trace("Layer not found at index: " + index);
            return false;
        }
        
        activeLayer = layer;
        
        // If it's a tilemap layer, automatically switch to its tileset
        if (Std.isOfType(layer, TilemapLayer)) {
            var tilemapLayer:TilemapLayer = cast layer;
            return tilesetManager.setActiveTileset(tilemapLayer.tileset.name);
        }
        
        return true;
    }
    
    /**
     * Get the active layer
     */
    public function getActiveLayer():Layer {
        return activeLayer;
    }
    
    /**
     * Get layer by name
     */
    public function getLayerByName(name:String):Layer {
        for (entity in entities) {
            if (Std.isOfType(entity, Layer)) {
                var layer:Layer = cast entity;
                if (layer.id == name) {
                    return layer;
                }
                
                // Search in folder layers
                if (Std.isOfType(layer, FolderLayer)) {
                    var folder:FolderLayer = cast layer;
                    var found = folder.findLayerByName(name);
                    if (found != null) {
                        return found;
                    }
                }
            }
        }
        return null;
    }
    
    /**
     * Get the number of layers
     */
    public function getLayerCount():Int {
        var count = 0;
        for (entity in entities) {
            if (Std.isOfType(entity, Layer)) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * Get layer at index (from layers only, not all entities)
     */
    public function getLayerAt(index:Int):Layer {
        var i = 0;
        for (entity in entities) {
            if (Std.isOfType(entity, Layer)) {
                if (i == index) {
                    return cast entity;
                }
                i++;
            }
        }
        return null;
    }
    
    /**
     * Get the first layer (helper for setting activeLayer)
     */
    private function getFirstLayer():Layer {
        for (entity in entities) {
            if (Std.isOfType(entity, Layer)) {
                return cast entity;
            }
        }
        return null;
    }
    
    /**
     * Move layer up in rendering order (earlier in the list = rendered first/behind)
     * @param layerName Name of the layer to move
     * @return True if layer was moved, false otherwise
     */
    public function moveLayerUp(layerName:String):Bool {
        var layer = getLayerByName(layerName);
        if (layer == null) {
            trace("Layer not found: " + layerName);
            return false;
        }
        
        // Find the layer's position in entities array
        var currentIndex = -1;
        for (i in 0...entities.length) {
            if (entities[i] == layer) {
                currentIndex = i;
                break;
            }
        }
        
        if (currentIndex <= 0) {
            trace("Layer is already at the top or not found");
            return false;
        }
        
        // Find the previous Layer entity (skip non-layer entities like grid, mapFrame)
        var targetIndex = -1;
        for (i in 0...currentIndex) {
            var prevIndex = currentIndex - 1 - i;
            if (Std.isOfType(entities[prevIndex], Layer)) {
                targetIndex = prevIndex;
                break;
            }
        }
        
        if (targetIndex == -1) {
            trace("No layer above to swap with");
            return false;
        }
        
        // Swap positions
        var temp = entities[currentIndex];
        entities[currentIndex] = entities[targetIndex];
        entities[targetIndex] = temp;
        
        return true;
    }
    
    /**
     * Move layer down in rendering order (later in the list = rendered last/on top)
     * @param layerName Name of the layer to move
     * @return True if layer was moved, false otherwise
     */
    public function moveLayerDown(layerName:String):Bool {
        var layer = getLayerByName(layerName);
        if (layer == null) {
            trace("Layer not found: " + layerName);
            return false;
        }
        
        // Find the layer's position in entities array
        var currentIndex = -1;
        for (i in 0...entities.length) {
            if (entities[i] == layer) {
                currentIndex = i;
                break;
            }
        }
        
        if (currentIndex == -1 || currentIndex >= entities.length - 1) {
            trace("Layer is already at the bottom or not found");
            return false;
        }
        
        // Find the next Layer entity (skip non-layer entities)
        var targetIndex = -1;
        for (i in (currentIndex + 1)...entities.length) {
            if (Std.isOfType(entities[i], Layer)) {
                targetIndex = i;
                break;
            }
        }
        
        if (targetIndex == -1) {
            trace("No layer below to swap with");
            return false;
        }
        
        // Swap positions
        var temp = entities[currentIndex];
        entities[currentIndex] = entities[targetIndex];
        entities[targetIndex] = temp;
        
        return true;
    }
    
    /**
     * Move layer up by index
     * @param index Index of the layer to move (layer index, not entity index)
     * @return True if layer was moved, false otherwise
     */
    public function moveLayerUpByIndex(index:Int):Bool {
        var layer = getLayerAt(index);
        if (layer == null) {
            return false;
        }
        return moveLayerUp(layer.id);
    }
    
    /**
     * Move layer down by index
     * @param index Index of the layer to move (layer index, not entity index)
     * @return True if layer was moved, false otherwise
     */
    public function moveLayerDownByIndex(index:Int):Bool {
        var layer = getLayerAt(index);
        if (layer == null) {
            return false;
        }
        return moveLayerDown(layer.id);
    }
    
    /**
     * Create a new tilemap layer using a tileset
     * @param name Name for the new layer
     * @param tilesetName Name of the tileset to use
     * @param index Position in the hierarchy (-1 to append at the end, 0 for first layer position)
     */
    public function createTilemapLayer(name:String, tilesetName:String, index:Int = -1):TilemapLayer {
        //TODO:FIX THIS
        var tileset = tilesetManager.tilesets.get(tilesetName);
        if (tileset == null) {
            trace("Cannot create tilemap layer: tileset not found: " + tilesetName);
            return null;
        }
        
        // Get texture program
        var textureProgramInfo = app.renderer.getProgramInfo("texture");
        
        // Create a new tile batch for this layer
        var batch = new ManagedTileBatch(textureProgramInfo, tileset.textureId);
        batch.debugName = "TilemapLayer:" + name;
        batch.depthTest = false;
        batch.init(app.renderer);
        
        // Define tile regions in the batch (same as tileset)
        for (row in 0...tileset.tilesPerCol) {
            for (col in 0...tileset.tilesPerRow) {
                batch.defineRegion(
                    col * tileset.tileSize,  // atlasX
                    row * tileset.tileSize,  // atlasY
                    tileset.tileSize,        // width
                    tileset.tileSize         // height
                );
            }
        }
        
        // Create the layer with tileset reference
        var layer = new TilemapLayer(name, tileset, batch);
        addLayerAtIndex(layer, index);
        
        trace("Created tilemap layer: " + name + " with tileset: " + tilesetName + " at index: " + index);
        return layer;
    }
    
    /**
     * Create a new entity layer
     */
    public function createEntityLayer(name:String, tilesetName:String):EntityLayer {
        //TODO:FIX THIS
        var tileset = tilesetManager.tilesets.get(tilesetName);
        if (tileset == null) {
            trace("Cannot create entity layer: tileset '" + tilesetName + "' not found");
            return null;
        }
        
        var textureProgramInfo = app.renderer.getProgramInfo("texture");
        if (textureProgramInfo == null) {
            trace("Cannot create entity layer: texture program not found");
            return null;
        }
        
        var entityBatch = new ManagedTileBatch(textureProgramInfo, tileset.textureId);
        entityBatch.debugName = "EntityLayer:" + name;
        entityBatch.depthTest = false; // Disable depth testing for 2D rendering
        entityBatch.visible = true; // Ensure batch is visible
        entityBatch.init(app.renderer);
        
        var layer = new EntityLayer(name, tileset, entityBatch);
        addLayer(layer);
        trace("Created entity layer: " + name + " with tileset: " + tilesetName);
        return layer;
    }
    
    /**
     * Create a new folder layer
     */
    public function createFolderLayer(name:String):FolderLayer {
        var layer = new FolderLayer(name);
        addLayer(layer);
        trace("Created folder layer: " + name);
        return layer;
    }

    public function replaceLayerTileset(layerName:String, newTilesetName:String):Void {
        var layer = getLayerByName(layerName);
        if (layer == null) {
            trace("Layer not found: " + layerName);
            return;
        }
        
        if (!Std.isOfType(layer, TilemapLayer)) {
            trace("Layer is not a tilemap layer: " + layerName);
            return;
        }
        
        var tilemapLayer:ITilesLayer = cast layer;
        var newTileset = tilesetManager.tilesets.get(newTilesetName);
        
        if (newTileset == null) {
            trace("New tileset not found: " + newTilesetName);
            return;
        }
        
        // Update the layer's tileset reference
        tilemapLayer.tileset = newTileset;
        
        // Update the tile batch's texture ID to match the new tileset
        tilemapLayer.managedTileBatch.setTexture(newTileset.textureId);
        
        // Redefine tile regions in the batch based on the new tileset
        tilemapLayer.redefineRegions(newTileset);
        
        // Mark buffers as needing update to reflect changes
        tilemapLayer.managedTileBatch.needsBufferUpdate = true;
        
        trace("Replaced tileset for layer: " + layerName + " with new tileset: " + newTilesetName);
    }

    
    /**
     * Export tilemap data to JSON format
     * @param filePath Absolute path where to save the JSON file
     * @return Number of tiles exported
     */
    public function exportToJSON(filePath:String):Int {
        var mapBounds = {
            x: mapX,
            y: mapY,
            width: mapWidth,
            height: mapHeight
        };
        
        return MapSerializer.exportToJSON(
            this.entities,
            tilesetManager,
            entityManager,
            mapBounds,
            tileSize,
            filePath
        );
    }

    public function setLayerProperties(layerName:String, name:String, type:Int, tilesetName:String, visible:Bool, silhouette:Bool, silhouetteColor:Int):Void {
        var layer = getLayerByName(layerName);
        if (layer != null) {
            layer.id = name;
            layer.visible = visible;
            layer.silhouette = silhouette;
            layer.silhouetteColor.hexValue = silhouetteColor;
        }
    }

    public function setLayerPropertiesAt(index:Int, name:String, type:Int, tilesetName:String, visible:Bool, silhouette:Bool, silhouetteColor:Int):Void {
        var layer = getLayerAt(index);
        if (layer != null) {
            
            layer.id = name;
            layer.visible = visible;
            layer.silhouette = silhouette;
            layer.silhouetteColor.hexValue = silhouetteColor;
        }
    }
    
    /**
     * Import tilemap data from JSON format
     * Automatically loads tilesets and places tiles
     * @param filePath Absolute path to the JSON file
     * @return Number of tiles imported, or -1 on error
     */
    public function importFromJSON(filePath:String):Int {
        // Create import context with all necessary callbacks
        var context:utils.ImportContext = {
            renderer: app.renderer,
            tilesetManager: tilesetManager,
            entityManager: entityManager,
            clearLayers: clearLayers,
            createTileset: createTileset,
            createEntity: createEntity,
            setEntityRegionPixels: setEntityRegionPixels,
            setCurrentTileset: setCurrentTileset,
            updateMapBounds: updateMapBounds,
            createTilemapLayer: createTilemapLayer,
            createEntityLayer: createEntityLayer
        };
        
        return MapSerializer.importFromJSON(filePath, context);
    }
    
    // Helper functions for import context
    
    private function clearLayers():Void {
        var layersToRemove:Array<Layer> = [];
        for (entity in entities) {
            if (Std.isOfType(entity, Layer)) {
                layersToRemove.push(cast entity);
            }
        }
        // Remove layers - don't call cleanup as it will try to remove from entities array
        // Just clear their data and remove from array manually
        for (layer in layersToRemove) {
            // Clear layer data without calling full cleanup
            if (Std.isOfType(layer, TilemapLayer)) {
                var tl:TilemapLayer = cast layer;
                if (tl.managedTileBatch != null) tl.managedTileBatch.clear();
                if (tl.tileGrid != null) tl.tileGrid.clear();
            } else if (Std.isOfType(layer, EntityLayer)) {
                var el:EntityLayer = cast layer;
                if (el.managedTileBatch != null) el.managedTileBatch.clear();
                if (el.entities != null) el.entities.clear();
            }
            entities.remove(layer);
        }
        activeLayer = null;
    }
    
    private function setCurrentTileset(name:String, size:Int):Void {
        tilesetManager.currentTilesetName = name;
        tileSize = size;
    }
    
    private function updateMapBounds(x:Float, y:Float, width:Float, height:Float):Void {
        mapX = x;
        mapY = y;
        mapWidth = width;
        mapHeight = height;
        
        // Update visuals
        if (mapFrame != null) {
            mapFrame.setBounds(mapX, mapY, mapWidth, mapHeight);
        }
        if (grid != null) {
            grid.setBounds(mapX, mapY, mapX + mapWidth, mapY + mapHeight);
        }
    }
    
    override public function render(renderer:Renderer):Void {
        if (!active) return;

        var size = app.window.size;
        camera.renderMatrix(size.x, size.y);
        var viewProjectionMatrix = camera.getMatrix();

        renderDisplayObject(renderer, viewProjectionMatrix, grid);
        renderDisplayObject(renderer, viewProjectionMatrix, mapFrame.getLineBatch());
        
        // Update world axes visibility
        if (worldAxes != null) {
            worldAxes.visible = showWorldAxes;
        }

        renderDisplayObject(renderer, viewProjectionMatrix, worldAxes);

        // Render entities from last to first (Photoshop-style: top of list renders on top)
        // This makes layer order intuitive - first layer in list = bottom, last layer = top
        var i = entities.length - 1;
        while (i >= 0) {
            var entity = entities[i];
            if (entity != null && entity.active && entity.visible) {
                entity.render(renderer, viewProjectionMatrix);
            }
            i--;
        }
    }
    
    override public function release():Void {
        // Layers are entities and will be cleaned up by super.release()
        activeLayer = null;
        
        super.release();
    }
}
