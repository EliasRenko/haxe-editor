package states;

import State;
import App;
import Renderer;
import ProgramInfo;
import display.Grid;
import display.ManagedTileBatch;
import display.MapFrame;
import entity.DisplayEntity;

/**
 * Editor state with infinite grid and editable tilemap
 * Allows placing and removing tiles with mouse clicks
 */
class EditorState extends State {
    
    private var grid:Grid;
    private var tileBatch:ManagedTileBatch;
    private var tileBatchEntity:DisplayEntity;
    private var mapFrame:MapFrame;
    
    // Tile editor settings
    private var tileSize:Int = 32; // Size of each tile in pixels
    private var selectedTileRegion:Int = 0; // Currently selected tile to place
    private var tileRegions:Array<Int> = []; // Available tile regions
    
    // Grid-based tile storage index (faster lookups than iterating ManagedTileBatch)
    // Key format: "gridX_gridY" -> tileId in ManagedTileBatch
    private var tileGrid:Map<String, Int> = new Map<String, Int>();
    
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
        
        var gridEntity = new DisplayEntity(grid, "grid");
        addEntity(gridEntity);
        
        // Setup tilemap
        setupTilemap(renderer);
        
        // Setup map frame
        setupMapFrame(renderer);
    }
    
    /**
     * Setup the editable tilemap
     */
    private function setupTilemap(renderer:Renderer):Void {

        // Load tile atlas texture
        var tileTextureData = app.resources.getTexture("textures/devTiles.tga");
        var tileTexture = renderer.uploadTexture(tileTextureData);
        
        // Create texture shader for tiles
        var textureVertShader = app.resources.getText("shaders/texture.vert");
        var textureFragShader = app.resources.getText("shaders/texture.frag");
        var textureProgramInfo = renderer.createProgramInfo("texture", textureVertShader, textureFragShader);
        
        // Create managed tile batch
        tileBatch = new ManagedTileBatch(textureProgramInfo, tileTexture);
        tileBatch.depthTest = false;
        tileBatch.init(renderer);
        
        // Define tile regions in the atlas (assuming 32x32 tiles in a grid)
        var tilesPerRow = Std.int(tileTextureData.width / tileSize);
        var tilesPerCol = Std.int(tileTextureData.height / tileSize);
        
        for (row in 0...tilesPerCol) {
            for (col in 0...tilesPerRow) {
                var regionId = tileBatch.defineRegion(
                    col * tileSize,  // atlasX
                    row * tileSize,  // atlasY
                    tileSize,        // width
                    tileSize         // height
                );
                tileRegions.push(regionId);
            }
        }
        
        // Create entity for tile batch
        tileBatchEntity = new DisplayEntity(tileBatch, "tilemap");
        addEntity(tileBatchEntity);
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
        // Snap to grid (tiles are positioned by top-left corner)
        var tileX = Std.int(Math.floor(worldX / tileSize) * tileSize);
        var tileY = Std.int(Math.floor(worldY / tileSize) * tileSize);
        
        // Check if tile is within map bounds
        if (tileX < mapX || tileX >= mapX + mapWidth || 
            tileY < mapY || tileY >= mapY + mapHeight) {
            // Tile is outside map bounds
            return;
        }
        
        // Convert to grid coordinates
        var gridX = Std.int(tileX / tileSize);
        var gridY = Std.int(tileY / tileSize);
        var gridKey = gridX + "_" + gridY;
        
        // Check if tile already exists at this grid position (O(1) lookup!)
        if (tileGrid.exists(gridKey)) {
            // Tile already exists at this position, don't add another
            return;
        }
        
        // Add tile to batch
        var tileId = tileBatch.addTile(tileX, tileY, tileSize, tileSize, tileRegions[selectedTileRegion]);
        
        if (tileId >= 0) {
            // Store in grid index for fast lookups
            tileGrid.set(gridKey, tileId);
            
            // Mark buffers as needing update
            tileBatch.needsBufferUpdate = true;
        }
    }
    
    /**
     * Remove tile at world position
     */
    private function removeTileAt(worldX:Float, worldY:Float):Void {
        // Snap to grid
        var tileX = Math.floor(worldX / tileSize) * tileSize;
        var tileY = Math.floor(worldY / tileSize) * tileSize;
        
        // Check if position is within map bounds
        if (tileX < mapX || tileX >= mapX + mapWidth || 
            tileY < mapY || tileY >= mapY + mapHeight) {
            // Position is outside map bounds
            return;
        }
        
        // Convert to grid coordinates
        var gridX = Std.int(tileX / tileSize);
        var gridY = Std.int(tileY / tileSize);
        var gridKey = gridX + "_" + gridY;
        
        // Fast lookup in grid index (O(1) instead of O(n)!)
        if (tileGrid.exists(gridKey)) {
            var tileId = tileGrid.get(gridKey);
            tileBatch.removeTile(tileId);
            tileGrid.remove(gridKey); // Remove from grid index
            tileBatch.needsBufferUpdate = true;
        }
    }
    
    /**
     * Count tiles that are outside the current map bounds
     */
    private function countTilesOutsideBounds():Int {
        var count = 0;
        for (tileId in 0...1000) { // MAX_TILES
            var tile = tileBatch.getTile(tileId);
            if (tile != null) {
                if (tile.x < mapX || tile.x >= mapX + mapWidth || 
                    tile.y < mapY || tile.y >= mapY + mapHeight) {
                    count++;
                }
            }
        }
        return count;
    }
    
    /**
     * Remove all tiles that are outside the current map bounds
     * Useful when shrinking the map to clean up orphaned tiles
     */
    public function cleanupTilesOutsideBounds():Int {
        var removed = 0;
        var keysToRemove:Array<String> = [];
        
        // Iterate through grid index to find out-of-bounds tiles
        for (gridKey in tileGrid.keys()) {
            var tileId = tileGrid.get(gridKey);
            var tile = tileBatch.getTile(tileId);
            if (tile != null) {
                if (tile.x < mapX || tile.x >= mapX + mapWidth || 
                    tile.y < mapY || tile.y >= mapY + mapHeight) {
                    tileBatch.removeTile(tileId);
                    keysToRemove.push(gridKey);
                    removed++;
                }
            }
        }
        
        // Remove from grid index
        for (key in keysToRemove) {
            tileGrid.remove(key);
        }
        
        if (removed > 0) {
            tileBatch.needsBufferUpdate = true;
        }
        return removed;
    }
    
    private var renderCount:Int = 0;
    
    override public function render(renderer:Renderer):Void {
        // WORKAROUND: Call render() directly due to C++ virtual method dispatch issue
        if (grid != null && grid.visible) {
            grid.render(camera.getMatrix());
        }
        
        // Render tilemap
        if (tileBatch != null && tileBatch.visible) {
            tileBatch.render(camera.getMatrix());
        }
        
        // Update map frame (sets uniforms) - actual drawing happens in super.render() via entity
        if (mapFrame != null && mapFrame.visible) {
            var lineBatch = mapFrame.getLineBatch();
            if (lineBatch.needsBufferUpdate) {
                lineBatch.updateBuffers(renderer);
            }
            lineBatch.render(camera.getMatrix());
        }
        
        super.render(renderer);
        renderCount++;
    }
    
    override public function release():Void {
        super.release();
    }
}
