package states;

import Log.LogCategory;
import State;
import App;
import Renderer;
import display.Grid;
import display.ManagedTileBatch;
import display.MapFrame;
import display.LineBatch;
import entity.DisplayEntity;
import layers.Layer;
import layers.TilemapLayer;
import layers.EntityLayer;
import layers.FolderLayer;
import Tileset;

/**
 * Editor state with infinite grid and editable tilemap
 * Allows placing and removing tiles with mouse clicks
 */
class EditorState extends State {
    
    private var grid:Grid;
    private var tileBatch:ManagedTileBatch;
    private var tileBatchEntity:DisplayEntity;
    private var mapFrame:MapFrame;
    private var worldAxes:LineBatch;
    private var worldAxesEntity:DisplayEntity;
    
    // Visual options
    public var showWorldAxes:Bool = true; // Show X/Y axes at origin (0,0)
    
    // Tileset management
    private var tilesets:Map<String, Tileset> = new Map<String, Tileset>();
    private var currentTilesetName:String = "devTiles"; // Currently active tileset
    
    // Tile editor settings
    private var tileSize:Int = 32; // Size of each tile in pixels
    private var selectedTileRegion:Int = 0; // Currently selected tile to place
    private var tileRegions:Array<Int> = []; // Available tile regions (for backward compatibility)
    
    // Layer management
    private var layers:Array<Layer> = [];
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
        
        var gridEntity = new DisplayEntity(grid, "grid");
        addEntity(gridEntity);
        
        // No default tilemap - use setupTilemap() or importFromJSON() to load tilesets
        
        // Setup map frame
        setupMapFrame(renderer);
        
        // Setup world axes
        setupWorldAxes(renderer);
    }
    
    /**
     * Set the currently selected tile region for drawing
     * @param regionId The region ID to select (0-based index)
     */
    public function setSelectedTileRegion(regionId:Int):Void {
        if (regionId >= 0 && regionId < tileRegions.length) {
            selectedTileRegion = regionId;
            trace("Selected tile region: " + regionId + " of " + tileRegions.length);
        } else {
            trace("Invalid tile region ID: " + regionId + " (valid range: 0-" + (tileRegions.length - 1) + ")");
        }
    }
    
    /**
     * Get tileset information by name (for external access)
     * @param tilesetName Name of the tileset
     * @return Tileset data or null if not found
     */
    public function getTilesetInfo(tilesetName:String):Null<{name:String, texturePath:String, tileSize:Int, tilesPerRow:Int, tilesPerCol:Int, regionCount:Int}> {
        var tileset = tilesets.get(tilesetName);
        if (tileset == null) {
            return null;
        }
        
        return {
            name: tileset.name,
            texturePath: tileset.texturePath,
            tileSize: tileset.tileSize,
            tilesPerRow: tileset.tilesPerRow,
            tilesPerCol: tileset.tilesPerCol,
            regionCount: tileset.tileRegions.length
        };
    }
    
    /**
     * Get the count of loaded tilesets
     * @return Number of tilesets
     */
    public function getTilesetCount():Int {
        var count = 0;
        for (_ in tilesets.keys()) {
            count++;
        }
        return count;
    }
    
    /**
     * Get tileset name at specific index
     * @param index Index of the tileset (0-based)
     * @return Tileset name or empty string if index out of bounds
     */
    public function getTilesetNameAt(index:Int):String {
        if (index < 0) return "";
        
        var i = 0;
        for (name in tilesets.keys()) {
            if (i == index) {
                return name;
            }
            i++;
        }
        return ""; // Index out of bounds
    }

    /**
     * Set the current active tileset for drawing context
     * This updates the tile regions and tile size used for drawing operations
     * Note: This is called automatically when setting an active TilemapLayer
     * @param tilesetName Name of the tileset to make active
     * @return True if tileset was found and set, false otherwise
     */
    public function setCurrentTileset(tilesetName:String):Bool {
        var tileset = tilesets.get(tilesetName);
        if (tileset == null) {
            trace("Tileset not found: " + tilesetName);
            return false;
        }
        
        // Update current tileset drawing context
        currentTilesetName = tilesetName;
        tileRegions = tileset.tileRegions;
        tileSize = tileset.tileSize;
        
        // Note: tileBatch and tileBatchEntity are kept for backward compatibility
        // but are no longer used directly (each layer has its own batch)
        tileBatch = tileset.tileBatch;
        tileBatchEntity = tileset.entity;
        
        app.logDebug(LogCategory.APP,"Active tileset context set to: " + tilesetName);
        return true;
    }

    /**
     * Delete a tileset by name
     * Cleans up the ManagedTileBatch and removes the entity from the rendering system
     * @param tilesetName Name of the tileset to delete
     * @return True if tileset was found and deleted, false otherwise
     */
    public function deleteTileset(tilesetName:String):Bool {
        var tileset = tilesets.get(tilesetName);
        if (tileset == null) {
            app.logDebug(LogCategory.APP,"Tileset not found: " + tilesetName);
            return false;
        }
        
        // Clear all tiles from the batch
        tileset.tileBatch.clear();
        
        // Remove entity from rendering system
        // Note: State class's entities array - we need to remove it
        if (entities != null && tileset.entity != null) {
            entities.remove(tileset.entity);
        }
        
        // Remove from tilesets collection
        tilesets.remove(tilesetName);
        
        // If this was the current tileset, clear the references
        if (tilesetName == currentTilesetName) {
            tileBatch = null;
            tileBatchEntity = null;
            tileRegions = [];
            currentTilesetName = "";
            trace("Warning: Deleted the current active tileset. You may need to set a new active tileset.");
        }
        
        trace("Deleted tileset: " + tilesetName);
        return true;
    }
    
    /**
     * Setup a tileset and add it to the collection
     * @param texturePath Resource path to the texture (e.g., "textures/devTiles.tga")
     * @param tilesetName Unique name for this tileset
     * @param tileSize Size of each tile in pixels
     */
    public function setupTileset(texturePath:String, tilesetName:String, tileSize:Int):Void {
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
        
        // Create managed tile batch for this tileset
        var batch = new ManagedTileBatch(textureProgramInfo, tileTexture);
        batch.depthTest = false;
        batch.init(renderer);
        
        // Calculate atlas dimensions
        var tilesPerRow = Std.int(tileTextureData.width / tileSize);
        var tilesPerCol = Std.int(tileTextureData.height / tileSize);
        
        // Define tile regions in the atlas
        var regions:Array<Int> = [];
        for (row in 0...tilesPerCol) {
            for (col in 0...tilesPerRow) {
                var regionId = batch.defineRegion(
                    col * tileSize,  // atlasX
                    row * tileSize,  // atlasY
                    tileSize,        // width
                    tileSize         // height
                );
                regions.push(regionId);
            }
        }
        
        // Create entity for tile batch
        var entity = new DisplayEntity(batch, "tilemap_" + tilesetName);
        addEntity(entity);
        
        // Create tileset structure
        var tileset:Tileset = {
            name: tilesetName,
            texturePath: texturePath,
            textureId: tileTexture,
            tileSize: tileSize,
            tilesPerRow: tilesPerRow,
            tilesPerCol: tilesPerCol,
            tileRegions: regions,
            tileBatch: batch,
            entity: entity
        };
        
        // Store in collection
        tilesets.set(tilesetName, tileset);
        
        // Update current tileset references (for backward compatibility)
        if (tilesetName == currentTilesetName) {
            tileBatch = batch;
            tileBatchEntity = entity;
            tileRegions = regions;
            this.tileSize = tileSize;
        }
        
        trace("Loaded tileset: " + tilesetName + " (" + tilesPerRow + "x" + tilesPerCol + " tiles)");
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
        
        // Add the lineBatch as an entity so it gets rendered automatically
        var lineBatchEntity = new DisplayEntity(mapFrame.getLineBatch(), "mapFrame");
        addEntity(lineBatchEntity);
    }
    
    /**
     * Setup infinite world axes at origin (0,0)
     * Red = X axis (horizontal), Green = Y axis (vertical)
     */
    private function setupWorldAxes(renderer:Renderer):Void {
        trace("[AXES DEBUG] Setting up world axes...");
        
        var lineProgramInfo = app.renderer.getProgramInfo("line");
        if (lineProgramInfo == null) {
            trace("[AXES DEBUG] ERROR: line program info is null!");
            return;
        }
        trace("[AXES DEBUG] Got line program info: " + lineProgramInfo);
        
        worldAxes = new LineBatch(lineProgramInfo, true);
        worldAxes.depthTest = false;
        worldAxes.visible = showWorldAxes;
        trace("[AXES DEBUG] Created LineBatch, visible=" + worldAxes.visible);
        
        // Initialize first (creates buffers)
        worldAxes.init(renderer);
        trace("[AXES DEBUG] After init: VBO=" + worldAxes.vbo + ", EBO=" + worldAxes.ebo);
        
        // THEN add the lines
        var axisLength = 10000.0;
        var z = 0.05;
        
        // X axis - Red
        var redColor = [1.0, 0.0, 0.0, 1.0];
        worldAxes.addLine(-axisLength, 0, z, axisLength, 0, z, redColor, redColor);
        trace("[AXES DEBUG] Added X axis line (red)");
        
        // Y axis - Green
        var greenColor = [0.0, 1.0, 0.0, 1.0];
        worldAxes.addLine(0, -axisLength, z, 0, axisLength, z, greenColor, greenColor);
        trace("[AXES DEBUG] Added Y axis line (green)");
        
        
        // Upload the vertex data to GPU immediately
        worldAxes.updateBuffers(renderer);
        trace("[AXES DEBUG] Called updateBuffers, needsBufferUpdate now=" + worldAxes.needsBufferUpdate);
        
        // Add to entity system for rendering
        worldAxesEntity = new DisplayEntity(worldAxes, "worldAxes");
        addEntity(worldAxesEntity);
        trace("[AXES DEBUG] Added worldAxes entity to render system");
    }
    
    private var updateCount:Int = 0;
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Handle mouse input for tile placement/removal
        handleTileInput();
        
        if (updateCount < 3) {
            trace("EditorState: update() frame " + updateCount);
            updateCount++;
        }
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
        
        // Left click to place tile (continuous while holding)
        if (mouse.check(1)) { // Button 1 = left
            placeTileAt(worldPos.x, worldPos.y);
        }

        // Right click to remove tile (continuous while holding)
        if (mouse.check(3)) { // Button 3 = right
            removeTileAt(worldPos.x, worldPos.y);
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
     * Place a tile at world position (snaps to grid)
     */
    private function placeTileAt(worldX:Float, worldY:Float):Void {
        // Check if active layer is a tilemap layer
        if (activeLayer == null || !Std.isOfType(activeLayer, TilemapLayer)) {
            return;
        }
        
        var tilemapLayer:TilemapLayer = cast activeLayer;
        trace("Placing tile on layer: " + tilemapLayer.name + ", tileset: " + tilemapLayer.tilesetName);
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
        
        // Add tile to batch using layer's tileset regions
        var tileId = tilemapLayer.tileBatch.addTile(tileX, tileY, layerTileset.tileSize, layerTileset.tileSize, layerTileset.tileRegions[selectedTileRegion]);
        
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
        for (layer in layers) {
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
     * Add a layer to the layer list (internal use)
     */
    private function addLayer(layer:Layer):Void {
        if (layer != null) {
            layers.push(layer);
            
            // If this is the first layer, make it active
            if (activeLayer == null) {
                activeLayer = layer;
                
                // Auto-switch tileset if it's a tilemap layer
                if (Std.isOfType(layer, TilemapLayer)) {
                    var tilemapLayer:TilemapLayer = cast layer;
                    setCurrentTileset(tilemapLayer.tilesetName);
                }
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
        
        if (layers.remove(layer)) {
            // Remove entity from rendering system if it's a tilemap layer
            if (Std.isOfType(layer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast layer;
                if (tilemapLayer.entity != null && entities != null) {
                    entities.remove(tilemapLayer.entity);
                }
            }
            
            // If we removed the active layer, set a new one
            if (activeLayer == layer) {
                activeLayer = layers.length > 0 ? layers[0] : null;
                
                // Update tileset if new active layer is a tilemap
                if (activeLayer != null && Std.isOfType(activeLayer, TilemapLayer)) {
                    var tilemapLayer:TilemapLayer = cast activeLayer;
                    setCurrentTileset(tilemapLayer.tilesetName);
                }
            }
            
            layer.release();
            return true;
        }
        return false;
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
        
        if (layers.remove(layer)) {
            // Remove entity from rendering system if it's a tilemap layer
            if (Std.isOfType(layer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast layer;
                if (tilemapLayer.entity != null && entities != null) {
                    entities.remove(tilemapLayer.entity);
                }
            }
            
            // If we removed the active layer, set a new one
            if (activeLayer == layer) {
                activeLayer = layers.length > 0 ? layers[0] : null;
                
                // Update tileset if new active layer is a tilemap
                if (activeLayer != null && Std.isOfType(activeLayer, TilemapLayer)) {
                    var tilemapLayer:TilemapLayer = cast activeLayer;
                    setCurrentTileset(tilemapLayer.tilesetName);
                }
            }
            
            layer.release();
            return true;
        }
        return false;
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
            return setCurrentTileset(tilemapLayer.tilesetName);
        }
        
        return true;
    }
    
    /**
     * Set the active layer by index
     * @param index Index of the layer to make active
     * @return True if layer was found and set, false otherwise
     */
    public function setActiveLayerByIndex(index:Int):Bool {
        var layer = getLayerAt(index);
        if (layer == null) {
            trace("Layer not found at index: " + index);
            return false;
        }
        
        activeLayer = layer;
        
        // If it's a tilemap layer, automatically switch to its tileset
        if (Std.isOfType(layer, TilemapLayer)) {
            var tilemapLayer:TilemapLayer = cast layer;
            return setCurrentTileset(tilemapLayer.tilesetName);
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
     * Get the active layer name
     * @return Name of the active layer, or empty string if none
     */
    public function getActiveLayerName():String {
        return activeLayer != null ? activeLayer.name : "";
    }
    
    /**
     * Get the active layer index
     * @return Index of the active layer, or -1 if none
     */
    public function getActiveLayerIndex():Int {
        if (activeLayer == null) return -1;
        
        for (i in 0...layers.length) {
            if (layers[i] == activeLayer) {
                return i;
            }
        }
        return -1;
    }
    
    /**
     * Get layer by name
     */
    public function getLayerByName(name:String):Layer {
        for (layer in layers) {
            if (layer.name == name) {
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
        return null;
    }
    
    /**
     * Get the number of layers
     */
    public function getLayerCount():Int {
        return layers.length;
    }
    
    /**
     * Get layer at index
     */
    public function getLayerAt(index:Int):Layer {
        if (index >= 0 && index < layers.length) {
            return layers[index];
        }
        return null;
    }
    
    /**
     * Create a new tilemap layer using a tileset
     */
    public function createTilemapLayer(name:String, tilesetName:String):TilemapLayer {
        var tileset = tilesets.get(tilesetName);
        if (tileset == null) {
            trace("Cannot create tilemap layer: tileset not found: " + tilesetName);
            return null;
        }
        
        // Create a new tile batch for this layer
        var batch = new ManagedTileBatch(tileset.tileBatch.programInfo, tileset.textureId);
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
        
        // Create entity for the batch
        var entity = new DisplayEntity(batch, "layer_" + name);
        addEntity(entity);
        
        // Create the layer with tileset reference
        var layer = new TilemapLayer(name, tileset, batch, entity);
        addLayer(layer);
        
        trace("Created tilemap layer: " + name + " with tileset: " + tilesetName);
        return layer;
    }
    
    /**
     * Create a new entity layer
     */
    public function createEntityLayer(name:String):EntityLayer {
        var layer = new EntityLayer(name);
        addLayer(layer);
        trace("Created entity layer: " + name);
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
        
        // Iterate through all layers and export tilemap layers
        for (layer in this.layers) {
            if (Std.isOfType(layer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast layer;
                var tileset = tilesets.get(tilemapLayer.tilesetName);
                
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
                        tilesetName: tilemapLayer.tilesetName,
                        tiles: layerTiles,
                        tileCount: layerTiles.length
                    });
                    totalTileCount += layerTiles.length;
                }
            }
        }
        
        // Collect tileset info
        var tilesetsArray:Array<Dynamic> = [];
        for (tilesetName in tilesets.keys()) {
            var tileset = tilesets.get(tilesetName);
            tilesetsArray.push({
                name: tileset.name,
                texturePath: tileset.texturePath,
                tileSize: tileset.tileSize
            });
        }
        
        // Create JSON structure
        var data = {
            version: "1.2",
            tilesets: tilesetsArray,
            currentTileset: currentTilesetName,
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
            for (layer in layers) {
                if (layer != null) {
                    layer.release();
                }
            }
            layers = [];
            activeLayer = null;
            
            // Load tilesets first
            if (data.tilesets != null) {
                var tilesetsArray:Array<Dynamic> = data.tilesets;
                for (tilesetData in tilesetsArray) {
                    var name:String = tilesetData.name;
                    var path:String = tilesetData.texturePath;
                    var size:Int = tilesetData.tileSize;
                    
                    // Only load if not already loaded
                    if (!tilesets.exists(name)) {
                        setupTileset(path, name, size);
                        trace("Loaded tileset from JSON: " + name);
                    }
                }
            }
            
            // Set current tileset
            if (data.currentTileset != null) {
                var currentName:String = data.currentTileset;
                var tileset = tilesets.get(currentName);
                if (tileset != null) {
                    currentTilesetName = currentName;
                    tileBatch = tileset.tileBatch;
                    tileBatchEntity = tileset.entity;
                    tileRegions = tileset.tileRegions;
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
            
            // Create layers and place tiles
            var importedCount = 0;
            var layersData:Array<Dynamic> = data.layers;
            
            if (layersData != null) {
                for (layerData in layersData) {
                    var tilesetName:String = layerData.tilesetName;
                    var tileset = tilesets.get(tilesetName);
                    
                    if (tileset == null) {
                        trace("Skipping layer with unknown tileset: " + tilesetName);
                        continue;
                    }
                    
                    // Create a new tilemap layer for this tileset
                    var tilemapLayer = createTilemapLayer("Layer_" + tilesetName, tilesetName);
                    
                    if (tilemapLayer != null && layerData.tiles != null) {
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
                                tilemapLayer.tileBatch.needsBufferUpdate = true;
                                importedCount++;
                            }
                        }
                    }
                }
            }
            
            trace("Imported " + importedCount + " tiles from " + layersData.length + " layers: " + filePath);
            return importedCount;
            
        } catch (e:Dynamic) {
            trace("Error importing JSON: " + e);
            return -1;
        }
    }
    
    private var renderCount:Int = 0;
    
    override public function render(renderer:Renderer):Void {
        // WORKAROUND: Call render() directly due to C++ virtual method dispatch issue
        if (grid != null && grid.visible) {
            grid.render(camera.getMatrix());
        }
        
        // Render all layers in order
        for (layer in layers) {
            if (layer != null) {
                layer.render(camera.getMatrix(), renderer);
            }
        }
        
        // Update map frame (sets uniforms) - actual drawing happens in super.render() via entity
        if (mapFrame != null && mapFrame.visible) {
            var lineBatch = mapFrame.getLineBatch();
            if (lineBatch.needsBufferUpdate) {
                lineBatch.updateBuffers(renderer);
            }
            lineBatch.render(camera.getMatrix());
        }
        
        // Entity system handles worldAxes rendering automatically
        // Just update visibility flag
        if (worldAxes != null) {
            worldAxes.visible = showWorldAxes;
        }
        
        super.render(renderer);
        renderCount++;
    }
    
    override public function release():Void {
        // Release all layers
        for (layer in layers) {
            if (layer != null) {
                layer.release();
            }
        }
        layers = [];
        activeLayer = null;
        
        super.release();
    }
}
