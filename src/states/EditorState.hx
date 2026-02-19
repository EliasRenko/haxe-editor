package states;

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
import Tileset;
import EntityDefinition;
import manager.TilesetManager;
import manager.EntityManager;

class EditorState extends State {
    
    private var grid:Grid;
    private var tileBatch:ManagedTileBatch;
    private var mapFrame:MapFrame;
    private var worldAxes:LineBatch;
    
    // Visual options
    public var showWorldAxes:Bool = true; // Show X/Y axes at origin (0,0)
    
    // Tileset management
    //private var tilesets:Map<String, Tileset> = new Map<String, Tileset>();
    public var tilesetManager:TilesetManager = new TilesetManager();
    public var entityManager:EntityManager = new EntityManager();
    // Entity definition management
    //private var entityDefinitions:Map<String, EntityDefinition> = new Map<String, EntityDefinition>();
    //private var selectedEntityName:String = ""; // Currently selected entity for placement
    
    // Tile editor settings
    private var tileSize:Int = 32; // Size of each tile in pixels
    private var selectedTileRegion:Int = 0; // Currently selected tile region ID (matches C# tile selection)
    private var tileRegions:Array<Int> = []; // Available tile regions (for backward compatibility)
    
    // Layer management (layers are stored in entities array)
    private var activeLayer:Layer = null;
    
    // Resize behavior options
    public var deleteOutOfBoundsTilesOnResize:Bool = true; // Auto-delete tiles when shrinking frame
    
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
        
        // Get renderer
        var renderer = app.renderer;
        
        // Create infinite grid for visual reference
        var gridVertShader = app.resources.getText("shaders/grid.vert");
        var gridFragShader = app.resources.getText("shaders/grid.frag");
        var gridProgramInfo = renderer.createProgramInfo("grid", gridVertShader, gridFragShader);
        
        grid = new Grid(gridProgramInfo, 5000.0); // 5000 unit quad
        grid.gridSize = 128.0; // 128 pixel large grid
        grid.subGridSize = 32.0; // 32 pixel small grid
        grid.setGridColor(0.2, 0.4, 0.6); // Blue-ish grid lines
        grid.setBackgroundColor(0.05, 0.05, 0.1); // Dark blue background
        grid.fadeDistance = 3000.0;
        grid.z = 0.0;
        grid.depthTest = false;
        grid.init(renderer);
        
        // Clip grid to map bounds
        grid.setBounds(mapX, mapY, mapX + mapWidth, mapY + mapHeight);
        
        //var gridEntity = new DisplayEntity(grid, "grid");
        //addEntity(gridEntity);
        
        // No default tilemap - use setupTilemap() or importFromJSON() to load tilesets
        
        // Setup map frame
        setupMapFrame(renderer);
        
        // Setup world axes
        setupWorldAxes(renderer);
    }

    public function setTileset(texturePath:String, tilesetName:String, tileSize:Int):Void {
        var renderer = app.renderer;
        
        // Load tile atlas texture - check if already loaded, if not load it first
        if (!app.resources.cached(texturePath)) {
            app.logDebug(LogCategory.APP,"Texture not cached, loading: " + texturePath);
            app.resources.loadTexture(texturePath, false);
        }
        
        var tileTextureData = app.resources.getTexture(texturePath, false);
        if (tileTextureData == null) {
            app.logDebug(LogCategory.APP,"Error: Could not load texture: " + texturePath);
            return;
        }
        
        var tileTexture = renderer.uploadTexture(tileTextureData);
        
        // Create texture shader for tiles (reuse if already exists)
        var textureProgramInfo = renderer.getProgramInfo("texture");
        if (textureProgramInfo == null) {
            var textureVertShader = app.resources.getText("shaders/texture.vert");
            var textureFragShader = app.resources.getText("shaders/texture.frag");
            textureProgramInfo = renderer.createProgramInfo("texture", textureVertShader, textureFragShader);
        }

        tilesetManager.setTileset(tileTexture, tilesetName, texturePath, tileSize);
    }
    
    /**
     * Set the currently selected tile region for drawing
     * @param regionId The region ID to select (0-based from C#, converted to 1-based for Haxe)
     */
    public function setActiveTileRegion(regionId:Int):Void {
        // C# sends 0-based indices, but Haxe region IDs start from 1
        selectedTileRegion = regionId + 1;
        trace("Selected tile region: " + selectedTileRegion + " (from C# index: " + regionId + ")");
    }
    
    // ===== ENTITY DEFINITION MANAGEMENT =====
    
    public function setEntity(entityName:String, width:Int, height:Int, tilesetName:String):Void {
        if (!tilesetManager.exists(tilesetName)) {
            trace("Cannot create entity: tileset not found: " + tilesetName);
            return;
        }

        entityManager.setEntity(entityName, width, height, tilesetName);
    }
    
    public function setEntityRegion(entityName:String, x:Int, y:Int, width:Int, height:Int):Void {
        var entity = entityManager.getEntityDefinition(entityName);
        if (entity == null) {
            trace("Cannot set region: entity not found: " + entityName);
            return;
        }
        
        // TODO: FIX THIS
        var tileset = tilesetManager.tilesets.get(entity.tilesetName);
        if (tileset == null) {
            trace("Cannot set region: tileset not found: " + entity.tilesetName);
            return;
        }
        
        // Convert tile indices to pixel coordinates
        entity.regionX = x * tileset.tileSize;
        entity.regionY = y * tileset.tileSize;
        entity.regionWidth = width * tileset.tileSize;
        entity.regionHeight = height * tileset.tileSize;
        
        trace("Set entity region for " + entityName + ": tile(" + x + "," + y + "," + width + "," + height + ") -> pixels(" + entity.regionX + "," + entity.regionY + "," + entity.regionWidth + "," + entity.regionHeight + ")");
    }
    
    /**
     * Set the atlas region for an entity definition in pixels (used for JSON import)
     * @param entityName Name of the entity
     * @param x Atlas region X position (in pixels)
     * @param y Atlas region Y position (in pixels)
     * @param width Atlas region width (in pixels)
     * @param height Atlas region height (in pixels)
     */
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
    
    private var updateCount:Int = 0;
    
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
        var tileId = tilemapLayer.tileBatch.addTile(tileX, tileY, layerTileset.tileSize, layerTileset.tileSize, selectedTileRegion);
        
        if (tileId >= 0) {
            // Store in grid index for fast lookups
            tilemapLayer.tileGrid.set(gridKey, tileId);
            
            // Mark buffers as needing update
            tilemapLayer.tileBatch.needsBufferUpdate = true;
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
            tilemapLayer.tileBatch.removeTile(tileId);
            tilemapLayer.tileGrid.remove(gridKey); // Remove from grid index
            tilemapLayer.tileBatch.needsBufferUpdate = true;
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
                    var tile = tilemapLayer.tileBatch.getTile(tileId);
                    if (tile != null) {
                        if (tile.x < mapX || tile.x >= mapX + mapWidth || 
                            tile.y < mapY || tile.y >= mapY + mapHeight) {
                            tilemapLayer.tileBatch.removeTile(tileId);
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
                    tilemapLayer.tileBatch.needsBufferUpdate = true;
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
        if (textureProgramInfo == null) {
            trace("Cannot create tilemap layer: texture program not found");
            return null;
        }
        
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
    
    /**
     * Export tilemap data to JSON format
     * @param filePath Absolute path where to save the JSON file
     * @return Number of tiles exported
     */
    public function exportToJSON(filePath:String):Int {
        var layersData:Array<Dynamic> = [];
        var totalTileCount = 0;
        
        // Iterate through all layers and export both tilemap and entity layers
        for (entity in this.entities) {
            if (!Std.isOfType(entity, Layer)) continue;
            var layer:Layer = cast entity;
            
            if (Std.isOfType(layer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast layer;
                //TODO:FIX THIS - 
                var tileset = tilesetManager.tilesets.get(tilemapLayer.tileset.name);
                
                if (tileset == null) continue;
                
                var layerTiles:Array<Dynamic> = [];
                
                // Get all tiles from this layer's batch
                for (tileId in 0...1000) { // MAX_TILES
                    var tile = tilemapLayer.tileBatch.getTile(tileId);
                    
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
            var entity = entityManager.getEntityDefinition(entityName);
            entitiesArray.push({
                name: entity.name,
                width: entity.width,
                height: entity.height,
                tilesetName: entity.tilesetName,
                regionX: entity.regionX,
                regionY: entity.regionY,
                regionWidth: entity.regionWidth,
                regionHeight: entity.regionHeight
            });
        }
        
        // Create JSON structure
        var data = {
            version: "1.3",
            tilesets: tilesetsArray,
            entityDefinitions: entitiesArray,
            currentTileset: tilesetManager.currentTilesetName,
            mapBounds: {
                x: mapX,
                y: mapY,
                width: mapWidth,
                height: mapHeight,
                gridWidth: Std.int(mapWidth / tileSize),
                gridHeight: Std.int(mapHeight / tileSize)
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
     * Import tilemap data from JSON format
     * Automatically loads tilesets and places tiles
     * @param filePath Absolute path to the JSON file
     * @return Number of tiles imported, or -1 on error
     */
    public function importFromJSON(filePath:String):Int {
        try {
            // Read JSON file
            var jsonString = sys.io.File.getContent(filePath);
            var data:Dynamic = haxe.Json.parse(jsonString);
            
            // Clear existing layers
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
                    if (tl.tileBatch != null) tl.tileBatch.clear();
                    if (tl.tileGrid != null) tl.tileGrid.clear();
                } else if (Std.isOfType(layer, EntityLayer)) {
                    var el:EntityLayer = cast layer;
                    if (el.entityBatch != null) el.entityBatch.clear();
                    if (el.entities != null) el.entities.clear();
                }
                entities.remove(layer);
            }
            activeLayer = null;
            
            // Load tilesets first
            if (data.tilesets != null) {
                var tilesetsArray:Array<Dynamic> = data.tilesets;
                for (tilesetData in tilesetsArray) {
                    var name:String = tilesetData.name;
                    var path:String = tilesetData.texturePath;
                    var size:Int = tilesetData.tileSize;
                    
                    // Only load if not already loaded
                    if (!tilesetManager.exists(name)) {
                        setTileset(path, name, size);
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
                    
                    setEntity(name, width, height, tilesetName);
                    // Use setEntityRegionPixels since JSON contains pixel values, not tile indices
                    setEntityRegionPixels(name, regionX, regionY, regionWidth, regionHeight);
                    trace("Loaded entity definition from JSON: " + name);
                }
            }
            
            // Set current tileset
            if (data.currentTileset != null) {
                var currentName:String = data.currentTileset;
                var tileset = tilesetManager.tilesets.get(currentName);
                if (tileset != null) {
                    tilesetManager.currentTilesetName = currentName;
                    tileSize = tileset.tileSize;
                }
            }
            
            // Update map bounds
            if (data.mapBounds != null) {
                mapX = data.mapBounds.x;
                mapY = data.mapBounds.y;
                mapWidth = data.mapBounds.width;
                mapHeight = data.mapBounds.height;
                
                // Update visuals
                if (mapFrame != null) {
                    mapFrame.setBounds(mapX, mapY, mapWidth, mapHeight);
                }
                if (grid != null) {
                    grid.setBounds(mapX, mapY, mapX + mapWidth, mapY + mapHeight);
                }
            }
            
            // Create layers and place tiles/entities
            var importedCount = 0;
            var layersData:Array<Dynamic> = data.layers;
            
            if (layersData != null) {
                for (layerData in layersData) {
                    var layerType:String = layerData.type != null ? layerData.type : "tilemap"; // Default to tilemap for old format
                    var layerName:String = layerData.name != null ? layerData.name : "Layer_" + layerData.tilesetName;
                    var tilesetName:String = layerData.tilesetName;
                    var tileset = tilesetManager.tilesets.get(tilesetName);
                    
                    if (tileset == null) {
                        trace("Skipping layer with unknown tileset: " + tilesetName);
                        continue;
                    }
                    
                    if (layerType == "tilemap") {
                        // Create a new tilemap layer
                        var tilemapLayer = createTilemapLayer(layerName, tilesetName, -1);
                        
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
                                    var tileId = tilemapLayer.tileBatch.addTile(x, y, tileset.tileSize, tileset.tileSize, region);
                                    
                                    if (tileId >= 0) {
                                        tilemapLayer.tileGrid.set(gridKey, tileId);
                                        importedCount++;
                                    }
                                }
                                
                                // Upload all tile data to GPU after adding all tiles
                                if (tilemapLayer.tileBatch.needsBufferUpdate) {
                                    tilemapLayer.tileBatch.updateBuffers(app.renderer);
                                }
                            }
                        }
                    } else if (layerType == "entity") {
                        // Create a new entity layer
                        var entityLayer = createEntityLayer(layerName, tilesetName);
                        
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
                                    var entityDef = entityManager.getEntityDefinition(entityName);
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
                                if (entityLayer.entityBatch.needsBufferUpdate) {
                                    entityLayer.entityBatch.updateBuffers(app.renderer);
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
    
    override public function render(renderer:Renderer):Void {
        if (!active) return;

        var size = app.window.size;
        camera.renderMatrix(size.x, size.y);
        var viewProjectionMatrix = camera.getMatrix();

        renderDisplayObject(renderer, viewProjectionMatrix, grid);
        renderDisplayObject(renderer, viewProjectionMatrix, mapFrame.getLineBatch());

        // Update map frame (sets uniforms)
        // if (mapFrame != null && mapFrame.visible) {
        //     var lineBatch = mapFrame.getLineBatch();
        //     if (lineBatch.needsBufferUpdate) {
        //         lineBatch.updateBuffers(renderer);
        //     }
        //     lineBatch.render(viewProjectionMatrix);
        // }
        
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
