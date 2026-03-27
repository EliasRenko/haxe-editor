package states;

import type.ToolType;
import Log.LogCategory;
import State;
import App;
import Renderer;
import display.Grid;
import display.ManagedTileBatch;
import display.MapFrame;
import display.LineBatch;
import display.Selection;
import layers.Layer;
import layers.TilemapLayer;
import layers.EntityLayer;
import layers.EntityLayer.Entity;
import display.BitmapFont;
import EditorTexture;
import layers.FolderLayer;
import manager.TilesetManager;
import manager.EntityManager;

class EditorState extends State {

    public var grid:Grid;
    private var tileBatch:ManagedTileBatch;
    private var mapFrame:MapFrame;
    private var worldAxes:LineBatch;
    private var quadtreeDebug:LineBatch;
    private var selection:Selection;
    /** Shared BitmapFont for entity name labels. */
    private var entityLabelFont:BitmapFont = null;
    private var _labelDebugFrames:Int = 0;

    /** Absolute path to the project this map belongs to, or null if standalone. */
    public var projectFilePath:Null<String> = null;
    /** Stable project UID for map/project binding, or null if standalone. */
    public var projectId:Null<String> = null;
    /** Display name of the project this map belongs to, or null if standalone. */
    public var projectName:Null<String> = null;

    // Options
    public var showWorldAxes:Bool = true; // Show X/Y axes at origin (0,0)
    public var showQuadtreeDebug:Bool = true; // Visualise EntityLayer quadtree cell bounds
    public var deleteOutOfBoundsTilesOnResize:Bool = true; // Auto-delete tiles when shrinking frame

    // Managers — owned at Editor level, assigned via Editor.initState() before first use.
    public var tilesetManager:TilesetManager;
    public var entityManager:EntityManager;
    
    // Tile editor settings
    public var tileSizeX:Int = 64; // Width of each tile in pixels
    public var tileSizeY:Int = 64; // Height of each tile in pixels
    //private var tileRegions:Array<Int> = []; // Available tile regions (for backward compatibility)
    
    // Layer management (layers are stored in entities array)
    private var activeLayer:Layer = null;
    //public var selectedTileRegion:Int = 0;
    
    // Map properties
    public var iid:String = "test_id";

    // Map bounds (defines the editable area)
    public var mapX:Float = 0;
    public var mapY:Float = 0;
    public var mapWidth:Float = 1024; // 32x32 tiles
    public var mapHeight:Float = 1024;
    
    // Resize state
    private var resizeMode:String = null; // "top", "bottom", "left", "right", or null
    private var resizeDragStart:{x:Float, y:Float} = null;
    private var resizeOriginalBounds:{x:Float, y:Float, width:Float, height:Float} = null;
    private var minMapSize:Float = 320.0; // 10 tiles minimum (10 * 32px)

    // Pan state (space or middle-mouse drag — Photoshop-style)
    private var _isPanning:Bool = false;
    private var _panLastX:Float = 0;
    private var _panLastY:Float = 0;

    // Zoom limits
    private static inline var ZOOM_MIN:Float = 0.1;
    private static inline var ZOOM_MAX:Float = 10.0;
    private static inline var ZOOM_STEP:Float = 0.1; // multiplier increment per wheel tick

    public var toolType:ToolType = ToolType.TILE_DRAW;

    // Selected entity list (supports future multi-select)
    public var selectedEntities:Array<Entity> = [];

    // Fired whenever the selection changes (added, cleared, etc.)
    public var onEntitySelectionChanged:()->Void = null;
    
    public function new(app:App, tilesetManager:TilesetManager, entityManager:EntityManager) {
        super("EditorState", app);
        this.tilesetManager = tilesetManager;
        this.entityManager = entityManager;
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
        grid.subGridSizeX = tileSizeX;
        grid.subGridSizeY = tileSizeY;
        grid.gridSizeX = tileSizeX * 4.0;
        grid.gridSizeY = tileSizeY * 4.0;
        //grid.setGridColor(0.2, 0.4, 0.6); // Blue-ish grid lines
        //grid.setBackgroundColor(0.05, 0.05, 0.1); // Dark blue background
        //grid.gridColor = new Color(0xFF336699); // Blue-ish grid lines
        //grid.backgroundColor = new Color(0xFF0D0D1A); // Dark blue background
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

        // Setup quadtree debug batch (non-persistent — repopulated every frame)
        var lineProgramInfo = app.renderer.getProgramInfo("line");
        if (lineProgramInfo != null) {
            quadtreeDebug = new LineBatch(lineProgramInfo, false);
            quadtreeDebug.depthTest = false;
            quadtreeDebug.init(app.renderer);

            selection = new Selection(lineProgramInfo);
            selection.init(app.renderer);
        }

        // Create default programInfo
        //var textureVertShader = app.resources.getText("shaders/texture.vert");
        var textureFragShader = app.resources.getText("shaders/texture.frag");
        app.renderer.createProgramInfo("texture", null, textureFragShader);

        // Load pre-baked entity label font (gohufont) for entity name labels
        app.log.info(LogCategory.APP, "[LabelFont] Loading entity label font...");
        try {
            var fontJson = app.resources.getText("fonts/gohufont.json");
            app.log.info(LogCategory.APP, "[LabelFont] JSON loaded, length=" + fontJson.length);
            var fontData = loaders.FontLoader.load(fontJson);
            app.log.info(LogCategory.APP, "[LabelFont] FontData parsed: " + Lambda.count(fontData.chars) + " chars, lineHeight=" + fontData.lineHeight);
            var fontTextureData = app.resources.getTexture("textures/gohufont.tga");
            app.log.info(LogCategory.APP, "[LabelFont] Texture data: " + fontTextureData.width + "x" + fontTextureData.height);
            var fontTexture = app.renderer.uploadTexture(fontTextureData);
            app.log.info(LogCategory.APP, "[LabelFont] Texture uploaded, id=" + fontTexture.id);
            var textProgramInfo = app.renderer.getProgramInfo("text");
            if (textProgramInfo == null) {
                //var tv = app.resources.getText("shaders/text.vert");
                var tf = app.resources.getText("shaders/text.frag");
                textProgramInfo = app.renderer.createProgramInfo("text", null, tf);
                app.log.info(LogCategory.APP, "[LabelFont] text program created");
            } else {
                app.log.info(LogCategory.APP, "[LabelFont] text program reused");
            }
            entityLabelFont = new BitmapFont(textProgramInfo, fontTexture, fontData);
            entityLabelFont.depthTest = false;
            entityLabelFont.uniforms.set("uColor", [1.0, 1.0, 1.0, 1.0]);
            entityLabelFont.init(app.renderer);
            app.log.info(LogCategory.APP, "[LabelFont] BitmapFont ready, regions=" + Lambda.count(entityLabelFont.atlasRegions));
        } catch(e:Dynamic) {
            app.log.info(LogCategory.APP, "[LabelFont] FAILED at init: " + e);
        }
    }

    // CHECKED!
    // public function createTileset(texturePath:String, tilesetName:String):String {
    //     var error:String = null;

    //     if (!app.resources.cached(texturePath)) {
    //         app.log.info(LogCategory.APP, "Loading texture: " + texturePath);
    //         app.resources.loadTexture(texturePath, false);
    //     }

    //     if (tilesetManager.exists(tilesetName)) {
    //         error = "Tileset with the name " + tilesetName + " already exists";
    //         app.log.info(LogCategory.APP, error);
    //         return error;
    //     }
        
    //     var glTexture:Texture = app.renderer.uploadTexture(app.resources.getTexture(texturePath, false));
    //     tilesetManager.setTileset(glTexture, tilesetName, texturePath);

    //     return null;
    // }
    
    // ===== ENTITY DEFINITION MANAGEMENT =====
    
    // CHECKED!
    public function createEntity(entityName:String, width:Int, height:Int, tilesetName:String):String {
        var error:String = null;
        
        if (!tilesetManager.exists(tilesetName)) {
            error = "Cannot create entity. Tileset with the name " + tilesetName + " does not exist";
            app.log.info(LogCategory.APP, error);
            return error;
        }

        if (entityManager.exists(entityName)) {
            error = "Entity with the name " + entityName + " already exists";
            app.log.info(LogCategory.APP, error);
            return error;
        }

        entityManager.setEntity(entityName, width, height, tilesetName);

        return null;
    }

    /**
     * Update every field of an existing entity definition and propagate the changes
     * to all placed entities across every EntityLayer.
     */
    public function editEntity(entityName:String, width:Int, height:Int, tilesetName:String,
                               regionX:Int, regionY:Int, regionWidth:Int, regionHeight:Int,
                               pivotX:Float, pivotY:Float):String {
        if (!entityManager.exists(entityName)) {
            var error = "Cannot edit entity '" + entityName + "': definition does not exist";
            app.log.info(LogCategory.APP, error);
            return error;
        }
        if (!tilesetManager.exists(tilesetName)) {
            var error = "Cannot edit entity '" + entityName + "': tileset '" + tilesetName + "' does not exist";
            app.log.info(LogCategory.APP, error);
            return error;
        }
        entityManager.setEntityFull(entityName, width, height, tilesetName,
                                    regionX, regionY, regionWidth, regionHeight,
                                    pivotX, pivotY);
        var def = entityManager.getEntityDefinition(entityName);
        var newTileset = tilesetManager.tilesets.get(tilesetName);
        var programInfo = app.renderer.getProgramInfo("texture");
        // Collect all EntityLayers recursively (including those nested in FolderLayers)
        var allEntityLayers:Array<EntityLayer> = [];
        collectEntityLayers(entities, allEntityLayers);
        for (entityLayer in allEntityLayers) {
            entityLayer.applyDefinitionUpdate(def, newTileset, app.renderer, programInfo);
        }
        return null;
    }

    /**
     * Remove all placed entities of the given definition from every EntityLayer,
     * then delete the definition itself from the EntityManager.
     */
    public function deleteEntityDef(entityName:String):String {
        if (!entityManager.exists(entityName)) {
            var error = "Cannot delete entity '" + entityName + "': definition does not exist";
            app.log.info(LogCategory.APP, error);
            return error;
        }
        var allEntityLayers:Array<EntityLayer> = [];
        collectEntityLayers(entities, allEntityLayers);
        for (entityLayer in allEntityLayers) {
            entityLayer.removeEntitiesByDefName(entityName);
        }
        entityManager.deleteEntityDefinition(entityName);
        return null;
    }

    /** Remove all placed entity instances with the given definition name from this
     *  state's layers, without touching the shared EntityManager. */
    public function removeEntityInstances(entityName:String):Void {
        var allEntityLayers:Array<EntityLayer> = [];
        collectEntityLayers(entities, allEntityLayers);
        for (entityLayer in allEntityLayers) {
            entityLayer.removeEntitiesByDefName(entityName);
        }
    }

    /** Recursively collect all EntityLayer instances from an entity array (includes FolderLayer children). */
    private function collectEntityLayers(source:Array<Dynamic>, result:Array<EntityLayer>):Void {
        for (entity in source) {
            if (Std.isOfType(entity, EntityLayer)) {
                result.push(cast entity);
            } else if (Std.isOfType(entity, FolderLayer)) {
                var folder:FolderLayer = cast entity;
                if (folder.children != null) collectEntityLayers(cast folder.children, result);
            }
        }
    }

    /** Recursively collect the names of all TilemapLayers bound to the given tileset (includes FolderLayer children). */
    private function collectTilemapLayerNamesByTileset(source:Array<Dynamic>, tilesetName:String, result:Array<String>):Void {
        for (entity in source) {
            if (Std.isOfType(entity, TilemapLayer)) {
                var tl:TilemapLayer = cast entity;
                if (tl.editorTexture != null && tl.editorTexture.name == tilesetName) result.push(tl.id);
            } else if (Std.isOfType(entity, FolderLayer)) {
                var folder:FolderLayer = cast entity;
                if (folder.children != null) collectTilemapLayerNamesByTileset(cast folder.children, tilesetName, result);
            }
        }
    }

    /**
     * Delete a tileset by name.
     * First removes every TilemapLayer that references it, then strips the
     * matching batch (and all its entity instances) from every EntityLayer,
     * and finally deletes the tileset itself from the manager.
     * Returns null on success or an error string on failure.
     */
    public function deleteTileset(tilesetName:String):String {
        if (!tilesetManager.exists(tilesetName)) {
            var error = "Cannot delete tileset '" + tilesetName + "': does not exist";
            app.log.info(LogCategory.APP, error);
            return error;
        }

        // 1. Remove every TilemapLayer that uses this tileset
        var tilemapNames:Array<String> = [];
        collectTilemapLayerNamesByTileset(entities, tilesetName, tilemapNames);
        for (name in tilemapNames) removeLayer(name);

        // 2. Mark tileset batches as missing in every EntityLayer (entities are kept and
        //    rendered as red silhouettes so the user knows where they were placed).
        var allEntityLayers:Array<EntityLayer> = [];
        collectEntityLayers(entities, allEntityLayers);
        for (entityLayer in allEntityLayers) {
            entityLayer.markTilesetMissing(tilesetName);
        }

        // 3. Delete the tileset itself
        tilesetManager.deleteTileset(tilesetName);
        return null;
    }

    /** Remove TilemapLayers referencing the given tileset from this state's layer tree,
     *  and mark entity batches for that tileset as missing — without deleting it from
     *  the shared TilesetManager. */
    public function removeTilesetReferences(tilesetName:String):Void {
        var tilemapNames:Array<String> = [];
        collectTilemapLayerNamesByTileset(entities, tilesetName, tilemapNames);
        for (name in tilemapNames) removeLayer(name);
        var allEntityLayers:Array<EntityLayer> = [];
        collectEntityLayers(entities, allEntityLayers);
        for (entityLayer in allEntityLayers) {
            entityLayer.markTilesetMissing(tilesetName);
        }
    }

    // /**
    //  * Create a brand-new entity definition from a full set of fields.
    //  * Fails if a definition with the same name already exists.
    //  */
    // public function createEntityFull(entityName:String, width:Int, height:Int, tilesetName:String,
    //                                  regionX:Int, regionY:Int, regionWidth:Int, regionHeight:Int,
    //                                  pivotX:Float, pivotY:Float):String {
    //     // tilesetName may be null/empty to create a definition with no tileset attached.
    //     // Non-null, non-empty names are validated to catch typos.
    //     if (tilesetName != null && tilesetName != "" && !tilesetManager.exists(tilesetName)) {
    //         var error = "Cannot create entity '" + entityName + "': tileset '" + tilesetName + "' does not exist";
    //         app.log.info(LogCategory.APP, error);
    //         return error;
    //     }
    //     if (entityManager.exists(entityName)) {
    //         var error = "Cannot create entity '" + entityName + "': definition already exists. Use editEntityDef to update it.";
    //         app.log.info(LogCategory.APP, error);
    //         return error;
    //     }
    //     // When there's no tileset, use the entity's own dimensions as the render region
    //     // so the red silhouette is sized correctly.
    //     var rX = regionX; var rY = regionY; var rW = regionWidth; var rH = regionHeight;
    //     if (tilesetName == null || tilesetName == "") { rX = 0; rY = 0; rW = width; rH = height; }
    //     entityManager.setEntityFull(entityName, width, height, tilesetName,
    //                                 rX, rY, rW, rH,
    //                                 pivotX, pivotY);
    //     return null;
    // }
    
    // CHECKED!
    public function setEntityRegion(entityName:String, x:Int, y:Int, width:Int, height:Int):Void {
        entityManager.setEntityRegion(entityName, x, y, width, height, tileSizeX);
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
        var lineFragShader = app.resources.getText("shaders/line.frag");
        
        var lineProgramInfo = renderer.createProgramInfo("line", null, lineFragShader);
        
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
    
    /**
     * Zoom the camera centred on the given screen-space cursor position.
     * @param mouseX  Cursor X in screen pixels
     * @param mouseY  Cursor Y in screen pixels
     * @param delta   Wheel delta: positive = zoom in, negative = zoom out
     */
    public function onMouseWheel(mouseX:Float, mouseY:Float, delta:Float):Void {
        var oldZoom = camera.zoom;
        var factor = 1.0 + ZOOM_STEP * Math.abs(delta);
        var newZoom = delta > 0 ? oldZoom * factor : oldZoom / factor;
        newZoom = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, newZoom));

        // Pin the world point under the cursor so it stays fixed on screen.
        // World point before zoom:
        //   wx = (mouseX - zoomCX) / oldZoom + zoomCX + camera.x
        // We want the same wx after zoom:
        //   wx = (mouseX - zoomCX) / newZoom + zoomCX + newCamX
        // Solving for newCamX:
        var zoomCX = camera.zoomCenterX != null ? camera.zoomCenterX : app.window.size.x * 0.5;
        var zoomCY = camera.zoomCenterY != null ? camera.zoomCenterY : app.window.size.y * 0.5;
        var wx = (mouseX - zoomCX) / oldZoom + zoomCX + camera.x;
        var wy = (mouseY - zoomCY) / oldZoom + zoomCY + camera.y;
        camera.zoom = newZoom;
        camera.x = wx - (mouseX - zoomCX) / newZoom - zoomCX;
        camera.y = wy - (mouseY - zoomCY) / newZoom - zoomCY;
    }

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Handle mouse input for tile placement/removal
        handleInput();
    }
    
    /**
     * Handle mouse input for placing and removing tiles, and resizing the map frame
     */
    private function handleInput():Void {
        var mouse = app.input.mouse;
        var keyboard = app.input.keyboard;

        // Get mouse screen position from C# (assumed to be in screen coordinates)
        var screenX = mouse.x;
        var screenY = mouse.y;

        // ── Photoshop-style pan: Space held OR middle mouse held ──────────────
        var panActive = keyboard.check(32) || mouse.check(2); // 32 = SPACE, 2 = middle button
        if (panActive) {
            if (_isPanning) {
                var dx = screenX - _panLastX;
                var dy = screenY - _panLastY;
                camera.x -= dx / camera.zoom;
                camera.y -= dy / camera.zoom;
            }
            _isPanning = true;
            _panLastX = screenX;
            _panLastY = screenY;
            return; // suppress all other interactions while panning
        } else {
            _isPanning = false;
        }

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

        if (activeLayer != null) {
            switch (toolType) {
                case ToolType.TILE_DRAW:
                    if (Std.isOfType(activeLayer, TilemapLayer) && mouse.check(1))
                        placeTileAt(worldPos.x, worldPos.y);
                    if (Std.isOfType(activeLayer, TilemapLayer) && mouse.pressed(3))
                        removeTileAt(worldPos.x, worldPos.y);
                case ToolType.ENTITY_ADD:
                    if (Std.isOfType(activeLayer, EntityLayer) && mouse.pressed(1))
                        placeEntityAt(worldPos.x, worldPos.y);
                    if (Std.isOfType(activeLayer, EntityLayer) && mouse.pressed(3))
                        removeEntityAt(worldPos.x, worldPos.y);
                case ToolType.ENTITY_SELECT:
                    if (Std.isOfType(activeLayer, EntityLayer) && mouse.pressed(1))
                        selectEntityAt(worldPos.x, worldPos.y);
                default:
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
        
        // Snap delta to grid
        deltaX = Math.round(deltaX / tileSizeX) * tileSizeX;
        deltaY = Math.round(deltaY / tileSizeY) * tileSizeY;
        
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
        
        // Update map bounds (also syncs EntityLayer quadtrees, grid, and mapFrame)
        updateMapBounds(newX, newY, newWidth, newHeight);
        
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
        
        // Add entity as a tile in the appropriate batch
        var textureProgramInfo = app.renderer.getProgramInfo("texture");
        if (textureProgramInfo == null) return;
        // Lookup tileset — null for no-tileset or missing-tileset entities (both routed to orphan batch)
        var editorTexture:EditorTexture = (entityDef.tilesetName != null && entityDef.tilesetName != "")
            ? tilesetManager.tilesets.get(entityDef.tilesetName) : null;
        // Find a fallback texture to back the GPU silhouette batch for orphan entities
        var fallbackTexture:EditorTexture = null;
        if (editorTexture == null) {
            for (ts in tilesetManager.tilesets) { fallbackTexture = ts; break; }
        }
        var entityId = entityLayer.placeEntity(entityDef, editorTexture, worldX, worldY, app.renderer, textureProgramInfo, null, null, null, fallbackTexture);
        app.log.info(LogCategory.APP, "[LabelFont] placeEntityAt: layerLabelFont=" + (entityLayer.labelFont != null) + " totalTiles=" + (entityLabelFont != null ? entityLabelFont.getTileCount() : -1));
    }
    
    /**
     * Remove entity at world position using the quadtree for accurate picking
     */
    private function removeEntityAt(worldX:Float, worldY:Float):Void {
        if (activeLayer == null || !Std.isOfType(activeLayer, EntityLayer)) return;

        var entityLayer:EntityLayer = cast activeLayer;
        var entityId = entityLayer.pickEntityAt(worldX, worldY);

        if (entityId != null) {
            entityLayer.removeEntity(entityId);
            trace("Removed entity ID=" + entityId + " at (" + worldX + ", " + worldY + ")");
        }
    }

    /**
     * Select (pick) an entity at world position using the quadtree + SAT and trace its data
     */
    public function selectEntityAt(worldX:Float, worldY:Float):String {
        if (activeLayer == null || !Std.isOfType(activeLayer, EntityLayer)) return null;

        var entityLayer:EntityLayer = cast activeLayer;
        var entityId:String = entityLayer.pickEntityAt(worldX, worldY);

        selectedEntities = [];

        if (entityId != null) {
            for (entry in entityLayer.batches) {
                if (entry.entities.exists(entityId)) {
                    var ent = entry.entities.get(entityId);
                    app.log.debug(LogCategory.APP, "Selected entity ID=" + entityId
                        + " name=" + ent.name
                        + " pos=(" + ent.x + ", " + ent.y + ")"
                        + " size=(" + ent.width + "x" + ent.height + ")"
                        + " tileset=" + (entry.editorTexture != null ? entry.editorTexture.name : "<orphan>"));
                    selectedEntities.push(ent);
                    break;
                }
            }
        } else {
            app.log.debug(LogCategory.APP, "No entity at (" + worldX + ", " + worldY + ")");
        }

        if (selection != null) selection.setSelections(selectedEntities);

        if (onEntitySelectionChanged != null)
            onEntitySelectionChanged();

        return entityId;
    }

    /**
     * Select an entity by its UID, searching across all EntityLayers.
     * Updates selectedEntities and fires onEntitySelectionChanged.
     * @return true if found, false otherwise.
     */
    public function selectEntityByUID(uid:String):Bool {
        selectedEntities = [];

        var allEntityLayers:Array<EntityLayer> = [];
        collectEntityLayers(entities, allEntityLayers);

        for (entityLayer in allEntityLayers) {
            for (entry in entityLayer.batches) {
                if (entry.entities.exists(uid)) {
                    var ent = entry.entities.get(uid);
                    app.log.debug(LogCategory.APP, "Selected entity by UID=" + uid
                        + " name=" + ent.name
                        + " pos=(" + ent.x + ", " + ent.y + ")"
                        + " size=(" + ent.width + "x" + ent.height + ")"
                        + " tileset=" + (entry.editorTexture != null ? entry.editorTexture.name : "<orphan>"));
                    selectedEntities.push(ent);
                    if (selection != null) selection.setSelections(selectedEntities);
                    if (onEntitySelectionChanged != null) onEntitySelectionChanged();
                    return true;
                }
            }
        }

        app.log.debug(LogCategory.APP, "selectEntityByUID: no entity with UID '" + uid + "' found");
        if (selection != null) selection.clear();
        if (onEntitySelectionChanged != null) onEntitySelectionChanged();
        return false;
    }

    /**
     * Select an entity by its UID, searching only within the named EntityLayer.
     * Updates selectedEntities and fires onEntitySelectionChanged.
     * @return true if found, false otherwise.
     */
    public function selectEntityInLayerByUID(layerName:String, uid:String):Bool {
        selectedEntities = [];

        var layer = getLayerByName(layerName);
        if (layer == null || !Std.isOfType(layer, EntityLayer)) {
            app.log.debug(LogCategory.APP, "selectEntityInLayerByUID: layer '" + layerName + "' not found or not an entity layer");
            if (selection != null) selection.clear();
            if (onEntitySelectionChanged != null) onEntitySelectionChanged();
            return false;
        }

        var entityLayer:EntityLayer = cast layer;
        for (entry in entityLayer.batches) {
            if (entry.entities.exists(uid)) {
                var ent = entry.entities.get(uid);
                app.log.debug(LogCategory.APP, "Selected entity in layer '" + layerName + "' by UID=" + uid
                    + " name=" + ent.name
                    + " pos=(" + ent.x + ", " + ent.y + ")"
                    + " size=(" + ent.width + "x" + ent.height + ")"
                    + " tileset=" + (entry.editorTexture != null ? entry.editorTexture.name : "<orphan>"));
                selectedEntities.push(ent);
                if (selection != null) selection.setSelections(selectedEntities);
                if (onEntitySelectionChanged != null) onEntitySelectionChanged();
                return true;
            }
        }

        app.log.debug(LogCategory.APP, "selectEntityInLayerByUID: no entity with UID '" + uid + "' in layer '" + layerName + "'");
        if (selection != null) selection.clear();
        if (onEntitySelectionChanged != null) onEntitySelectionChanged();
        return false;
    }

    /**
     * Clear the current entity selection.
     * Updates the selection overlay and fires onEntitySelectionChanged.
     */
    public function deselectEntity():Void {
        selectedEntities = [];
        if (selection != null) selection.clear();
        if (onEntitySelectionChanged != null) onEntitySelectionChanged();
    }

    public function getActiveTile():Int {
        if (activeLayer == null || !Std.isOfType(activeLayer, TilemapLayer)) {
            app.log.debug(LogCategory.APP,"Cannot set active tile region: no active tilemap layer");
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
        trace("Placing tile on layer: " + tilemapLayer.id + ", tileset: " + tilemapLayer.editorTexture.name);
        
        // Snap to grid (tiles are positioned by top-left corner)
        var tileX = Std.int(Math.floor(worldX / tileSizeX) * tileSizeX);
        var tileY = Std.int(Math.floor(worldY / tileSizeY) * tileSizeY);
        
        // Check if tile is within map bounds
        if (tileX < mapX || tileX >= mapX + mapWidth || 
            tileY < mapY || tileY >= mapY + mapHeight) {
            // Tile is outside map bounds
            return;
        }
        
        // Convert to grid coordinates
        var gridX = Std.int(tileX / tileSizeX);
        var gridY = Std.int(tileY / tileSizeY);
        var gridKey = gridX + "_" + gridY;
        
        // Check if tile already exists at this grid position (O(1) lookup!)
        if (tilemapLayer.tileGrid.exists(gridKey)) {
            // Tile already exists at this position, don't add another
            return;
        }
        
        // Add tile to batch using selected region ID
        var tileId = tilemapLayer.managedTileBatch.addTile(tileX, tileY, tilemapLayer.tileSize, tilemapLayer.tileSize, tilemapLayer.selectedTileRegion);
        
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
        //var layerTileset = tilemapLayer.tileset;
        
        // Snap to grid
        var tileX = Math.floor(worldX / tileSizeX) * tileSizeX;
        var tileY = Math.floor(worldY / tileSizeY) * tileSizeY;
        
        // Check if position is within map bounds
        if (tileX < mapX || tileX >= mapX + mapWidth || 
            tileY < mapY || tileY >= mapY + mapHeight) {
            // Position is outside map bounds
            return;
        }
        
        // Convert to grid coordinates
        var gridX = Std.int(tileX / tileSizeX);
        var gridY = Std.int(tileY / tileSizeY);
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

            // Initialise quadtree bounds for any new entity layer
            var el = Std.downcast(layer, EntityLayer);
            if (el != null) {
                el.setWorldBounds(mapX + mapWidth * 0.5, mapY + mapHeight * 0.5, mapWidth, mapHeight);
                el.labelFont = entityLabelFont;
                el.log = app.log;
                app.log.info(LogCategory.APP, "[LabelFont] addLayer '" + el.id + "': labelFont set, isNull=" + (entityLabelFont == null));
            }

            // If this is the first layer, make it active
            if (activeLayer == null) {
                activeLayer = layer;

                // Auto-switch tileset if it's a tilemap layer
                if (Std.isOfType(layer, TilemapLayer)) {
                    var tilemapLayer:TilemapLayer = cast layer;
                    tilesetManager.setActiveTileset(tilemapLayer.editorTexture.name);
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
        }

        // Initialise quadtree bounds for entity layers added at an index
        var elIdx = Std.downcast(layer, EntityLayer);
        if (elIdx != null) {
            elIdx.setWorldBounds(mapX + mapWidth * 0.5, mapY + mapHeight * 0.5, mapWidth, mapHeight);
            elIdx.labelFont = entityLabelFont;
            elIdx.log = app.log;
        }

        // Auto-switch tileset if it's a tilemap layer and this is the first/active layer
        if (activeLayer == layer && Std.isOfType(layer, TilemapLayer)) {
            var tilemapLayer:TilemapLayer = cast layer;
            tilesetManager.setActiveTileset(tilemapLayer.editorTexture.name);
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
                tilesetManager.setActiveTileset(tilemapLayer.editorTexture.name);
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
                tilesetManager.setActiveTileset(tilemapLayer.editorTexture.name);
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
            return tilesetManager.setActiveTileset(tilemapLayer.editorTexture.name);
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
            return tilesetManager.setActiveTileset(tilemapLayer.editorTexture.name);
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

	public function moveLayerTo(layerName:String, newIndex:Int):Bool {
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
		if (currentIndex == -1) {
			trace("Layer not found in entities array");
			return false;
		}
		// Count only Layer entities for bounds
		var layerCount = getLayerCount();
		if (newIndex < 0)
			newIndex = 0;
		if (newIndex >= layerCount)
			newIndex = layerCount - 1;
		// If already at position, nothing to do
		var currentLayerIndex = 0;
		for (i in 0...entities.length) {
			if (Std.isOfType(entities[i], Layer)) {
				if (entities[i] == layer)
					break;
				currentLayerIndex++;
			}
		}
		if (currentLayerIndex == newIndex)
			return true;
		// Remove from entities
		entities.remove(layer);
		// Find the actual entity index for the Nth layer
		var insertIndex = 0;
		var count = 0;
		for (i in 0...entities.length) {
			if (Std.isOfType(entities[i], Layer)) {
				if (count == newIndex) {
					insertIndex = i;
					break;
				}
				count++;
			}
			insertIndex = i + 1;
		}
		entities.insert(insertIndex, layer);
		return true;
	}
    
    
    /** move batch up within an entity layer identified by name */
    public function moveEntityLayerBatchUp(layerName:String, batchIndex:Int):Bool {
        var layer = getLayerByName(layerName);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return false;
        var el = cast(layer, layers.EntityLayer);
        var entry = el.getBatchEntryAt(batchIndex);
        if (entry == null) return false;
        return el.moveBatchUp(entry);
    }

    /** move batch down within an entity layer identified by name */
    public function moveEntityLayerBatchDown(layerName:String, batchIndex:Int):Bool {
        var layer = getLayerByName(layerName);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return false;
        var el = cast(layer, layers.EntityLayer);
        var entry = el.getBatchEntryAt(batchIndex);
        if (entry == null) return false;
        return el.moveBatchDown(entry);
    }

    /** relocate batch to new position in entity layer identified by name */
    public function moveEntityLayerBatchTo(layerName:String, batchIndex:Int, newIndex:Int):Bool {
        var layer = getLayerByName(layerName);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return false;
        var el = cast(layer, layers.EntityLayer);
        var entry = el.getBatchEntryAt(batchIndex);
        if (entry == null) return false;
        return el.moveBatchTo(entry, newIndex);
    }

    // index-based wrappers (look up layer by index)
    public function moveEntityLayerBatchUpByLayerIndex(layerIndex:Int, batchIndex:Int):Bool {
        var layer = getLayerAt(layerIndex);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return false;
        var el = cast(layer, layers.EntityLayer);
        var entry = el.getBatchEntryAt(batchIndex);
        if (entry == null) return false;
        return el.moveBatchUp(entry);
    }

    public function moveEntityLayerBatchDownByLayerIndex(layerIndex:Int, batchIndex:Int):Bool {
        var layer = getLayerAt(layerIndex);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return false;
        var el = cast(layer, layers.EntityLayer);
        var entry = el.getBatchEntryAt(batchIndex);
        if (entry == null) return false;
        return el.moveBatchDown(entry);
    }

    public function moveEntityLayerBatchToByLayerIndex(layerIndex:Int, batchIndex:Int, newIndex:Int):Bool {
        var layer = getLayerAt(layerIndex);
        if (layer == null || !Std.isOfType(layer, layers.EntityLayer)) return false;
        var el = cast(layer, layers.EntityLayer);
        var entry = el.getBatchEntryAt(batchIndex);
        if (entry == null) return false;
        return el.moveBatchTo(entry, newIndex);
    }

    public function moveLayerUpByIndex(index:Int):Bool {
        var layer = getLayerAt(index);
        if (layer == null) {
            return false;
        }
        return moveLayerUp(layer.id);
    }

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
    public function createTilemapLayer(name:String, tilesetName:String, index:Int = -1, tileSize:Int = 64):TilemapLayer {
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
        
        // Compute atlas dimensions from texture size and tileSize
        var tilesPerRow = Std.int(tileset.textureId.width / tileSize);
        var tilesPerCol = Std.int(tileset.textureId.height / tileSize);
        
        // Define tile regions in the batch
        for (row in 0...tilesPerCol) {
            for (col in 0...tilesPerRow) {
                batch.defineRegion(
                    col * tileSize,  // atlasX
                    row * tileSize,  // atlasY
                    tileSize,        // width
                    tileSize         // height
                );
            }
        }
        
        // Create the layer with tileset reference
        var layer = new TilemapLayer(name, tileset, batch, tileSize, tilesPerRow, tilesPerCol);
        addLayerAtIndex(layer, index);
        
        trace("Created tilemap layer: " + name + " with tileset: " + tilesetName + " at index: " + index);
        return layer;
    }
    
    /**
     * Create a new entity layer
     */
    public function createEntityLayer(name:String):EntityLayer {
        // factory for a new entity layer; caller is responsible for adding batches later when
        // placing the first entity (tileset is determined by the entity definition)
        var layer = new EntityLayer(name);
        addLayer(layer);
        trace("Created empty entity layer: " + name);
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

    public function replaceLayerTileset(layerName:String, newTilesetName:String):Bool {
        var layer = getLayerByName(layerName);
        if (layer == null) {
            trace("Layer not found: " + layerName);
            return false;
        }
        
        if (!Std.isOfType(layer, TilemapLayer)) {
            trace("Layer is not a tilemap layer: " + layerName);
            return false;
        }
        
        var tilemapLayer:TilemapLayer = cast layer;
        var newTileset = tilesetManager.tilesets.get(newTilesetName);
        
        if (newTileset == null) {
            trace("New tileset not found: " + newTilesetName);
            return false;
        }
        
        // Update the layer's tileset reference
        tilemapLayer.editorTexture = newTileset;
        
        // Update the tile batch's texture ID to match the new tileset
        tilemapLayer.managedTileBatch.setTexture(newTileset.textureId);
        
        // Recompute atlas dimensions using the layer's existing tileSize and new texture
        tilemapLayer.tilesPerRow = Std.int(newTileset.textureId.width / tilemapLayer.tileSize);
        tilemapLayer.tilesPerCol = Std.int(newTileset.textureId.height / tilemapLayer.tileSize);
        
        // Redefine tile regions in the batch based on the new tileset
        tilemapLayer.redefineRegions();
        
        // Mark buffers as needing update to reflect changes
        tilemapLayer.managedTileBatch.needsBufferUpdate = true;
        
        return true;
    }

    
    /**
     * Export tilemap data to JSON format
     * @param filePath Absolute path where to save the JSON file
     * @return true on success, false on error
     */
    public function exportToJSON(filePath:String):Bool {
        try {
            var count = exportMapToJSON(filePath);
            if (count < 0) {
                var errMsg = "EditorState: exportToJSON failed for " + filePath;
                app.log.error(LogCategory.APP, errMsg);
                throw errMsg;
            }
            return true;
        } catch (e:Dynamic) {
            var errMsg = "EditorState: exportToJSON error for " + filePath + ": " + e;
            app.log.error(LogCategory.APP, errMsg);
            throw errMsg;
        }
    }

    private function exportMapToJSON(filePath:String):Int {
        var layersData:Array<Dynamic> = [];
        var totalTileCount = 0;

        for (entity in entities) {
            if (!Std.isOfType(entity, Layer)) continue;
            var layer:Layer = cast entity;

            if (Std.isOfType(layer, TilemapLayer)) {
                var tilemapLayer:TilemapLayer = cast layer;
                var tileset = tilesetManager.tilesets.get(tilemapLayer.editorTexture.name);
                if (tileset == null) continue;

                var layerTiles:Array<Dynamic> = [];
                for (tileId in 0...1000) {
                    var tile = tilemapLayer.managedTileBatch.getTile(tileId);
                    if (tile != null) {
                        layerTiles.push({
                            gridX: Std.int(tile.x / tileSizeX),
                            gridY: Std.int(tile.y / tileSizeY),
                            region: tile.regionId
                        });
                    }
                }

                if (layerTiles.length > 0) {
                    layersData.push({
                        type: "tilemap",
                        name: tilemapLayer.id,
                        tilesetName: tilemapLayer.editorTexture.name,
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

                for (entry in entityLayer.batches) {
                    var batchEntities:Array<Dynamic> = [];
                    for (entityId in entry.entities.keys()) {
                        var ed = entry.entities.get(entityId);
                        batchEntities.push({
                            uid: ed.uid,
                            name: ed.name,
                            x: ed.x,
                            y: ed.y,
                            pivotX: ed.pivotX,
                            pivotY: ed.pivotY
                        });
                    }
                    if (batchEntities.length > 0) {
                        batchesData.push({
                            entities: batchEntities,
                            count: batchEntities.length
                        });
                        totalEntities += batchEntities.length;
                    }
                }

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

        var hasProject = projectFilePath != null;

        var mapData:Dynamic = {
            version: "1.6",
            mapBounds: {
                x: mapX,
                y: mapY,
                width: mapWidth,
                height: mapHeight,
                tileSizeX: tileSizeX,
                tileSizeY: tileSizeY,
                gridWidth: Std.int(mapWidth / tileSizeX),
                gridHeight: Std.int(mapHeight / tileSizeY)
            },
            layers: layersData,
            tileCount: totalTileCount
        };

        Reflect.setField(mapData, "projectFile", projectFilePath != null ? projectFilePath : "");
        Reflect.setField(mapData, "projectId", projectId != null ? projectId : "");
        Reflect.setField(mapData, "projectName", projectName != null ? projectName : "");

        var data:Dynamic = { map: mapData };

        if (!hasProject) {
            var texturesArray:Array<Dynamic> = [];
            for (tilesetName in tilesetManager.tilesets.keys()) {
                var ts = tilesetManager.tilesets.get(tilesetName);
                texturesArray.push({ name: ts.name, texturePath: ts.texturePath });
            }
            Reflect.setField(data, "textures", texturesArray);
        }

        var jsonString = haxe.Json.stringify(data, null, "  ");
        try {
            sys.io.File.saveContent(filePath, jsonString);
            trace("Exported " + totalTileCount + " tiles in " + layersData.length + " layers to: " + filePath);
            return totalTileCount;
        } catch (e:Dynamic) {
            var errMsg = "Error exporting JSON: " + e;
            app.log.error(LogCategory.APP, errMsg);
            trace(errMsg);
            throw errMsg;
        }
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
     * @param mapData Map object
     * @param basePath Optional map file path for resolving relative texture paths
     * @return true on success, false on error
     */
    public function importFromJSON(mapData:Dynamic, basePath:String = null):Bool {
        try {

            var result = importMapFromJSON(mapData);
            if (result < 0) {
                var errMsg = "EditorState: importFromJSON failed for " + (basePath != null ? basePath : "<data>");
                app.log.error(LogCategory.APP, errMsg);
                throw errMsg;
            }

            // Rebuild entity name labels for all imported entities.
            // Labels may not have been created during import if labelFont was not yet assigned
            // to a layer when placeEntity was called (e.g. timing / ordering issues).
            if (entityLabelFont != null) {
                for (entity in entities) {
                    var el = Std.downcast(entity, EntityLayer);
                    if (el != null) {
                        el.labelFont = entityLabelFont;
                        el.rebuildLabels();
                    }
                }
            }

            return true;

        } catch (e:Dynamic) {
            var errMsg = "EditorState: importFromJSON error for " + (basePath != null ? basePath : "<data>") + ": " + e;
            app.log.error(LogCategory.APP, errMsg);
            throw errMsg;
        }
    }

    private function importMapFromJSON(mapData:Dynamic):Int {
        var tileSizeMap:Map<String, Int> = new Map();
        try {
            // Enforce exact map data versioning: only 1.6 is supported.
            var mapVersion:String = null;
            if (mapData.version != null && Std.is(mapData.version, String)) {
                mapVersion = cast(mapData.version, String);
            }

            if (mapVersion != "1.6") {
                var errMsg:String = "Unsupported map version: " + (mapVersion != null ? mapVersion : "<missing>") + ". Expected 1.6.";
                app.log.error(LogCategory.APP, errMsg);
                throw errMsg;
            }

            // TODO: Import textures later
            // var rawTextures:Null<Array<Dynamic>> = mapData.textures != null ? mapData.textures : mapData.tilesets;
            // if (rawTextures != null) {
            //     for (texData in rawTextures) {
            //         var name:String = texData.name;
            //         var path:String = texData.texturePath;
            //         if (texData.tileSize != null) tileSizeMap.set(name, Std.int(texData.tileSize));

            //         if (!tilesetManager.exists(name)) {
            //             var resolvedPath:String = resolveTexturePath(path);
            //             var err:String = Editor.createTileset(resolvedPath, name);
            //             if (err != null) {
            //                 var errorMsg:String = "EditorState: Could not load tileset '" + name + "' from '" + resolvedPath + "': " + err;
            //                 app.log.error(LogCategory.APP, errorMsg);
            //                 trace(errorMsg);
            //                 continue;
            //             }
            //             trace("Loaded texture from map JSON: " + name + " (path: " + resolvedPath + ")");
            //         }
            //     }
            // }

            var importedCount = 0;
            var layersData:Array<Dynamic> = mapData.layers;

            if (layersData != null) {
                for (layerData in layersData) {
                    var layerType:String = layerData.type != null ? layerData.type : "tilemap";
                    var layerName:String = layerData.name != null ? layerData.name : "Layer_" + layerData.tilesetName;

                    if (layerType == "tilemap") {
                        var tilesetName:String = layerData.tilesetName;
                        var editorTexture:EditorTexture = tilesetManager.tilesets.get(tilesetName);
                        if (editorTexture == null) {
                            trace("Skipping layer with unknown tileset: " + tilesetName);
                            continue;
                        }

                        var layerTileSize:Int = layerData.tileSize != null ? Std.int(layerData.tileSize)
                            : tileSizeMap.exists(tilesetName) ? tileSizeMap.get(tilesetName) : 64;
                        var tilemapLayer = createTilemapLayer(layerName, tilesetName, -1, layerTileSize);

                        if (tilemapLayer != null) {
                            if (layerData.visible != null) tilemapLayer.visible = layerData.visible;

                            if (layerData.tiles != null) {
                                var tiles:Array<Dynamic> = layerData.tiles;
                                for (tileData in tiles) {
                                    var gridX:Int = tileData.gridX;
                                    var gridY:Int = tileData.gridY;
                                    var worldX:Float = gridX * layerTileSize;
                                    var worldY:Float = gridY * layerTileSize;
                                    var tileId = tilemapLayer.managedTileBatch.addTile(
                                        worldX, worldY,
                                        tilemapLayer.tileSize, tilemapLayer.tileSize,
                                        tileData.region
                                    );
                                    if (tileId >= 0) {
                                        tilemapLayer.tileGrid.set(gridX + "_" + gridY, tileId);
                                        importedCount++;
                                    }
                                }
                                if (tilemapLayer.managedTileBatch.needsBufferUpdate)
                                    tilemapLayer.managedTileBatch.updateBuffers(app.renderer);
                            }
                        }

                    } else if (layerType == "entity") {
                        var entityLayer = createEntityLayer(layerName);

                        if (entityLayer != null) {
                            if (layerData.visible != null) entityLayer.visible = layerData.visible;

                            if (layerData.batches != null) {
                                var batches:Array<Dynamic> = layerData.batches;
                                var programInfo = app.renderer.getProgramInfo("texture");
                                var fallback:EditorTexture = null;
                                for (ts in tilesetManager.tilesets) { fallback = ts; break; }
                                for (batchData in batches) {
                                    var batchEntities:Array<Dynamic> = batchData.entities;
                                    for (entityData in batchEntities) {
                                        var def = entityManager.getEntityDefinition(entityData.name);
                                        if (def == null) continue;
                                        var tileset:EditorTexture = tilesetManager.tilesets.get(def.tilesetName);
                                        var pivotX:Float = entityData.pivotX != null ? entityData.pivotX : 0.0;
                                        var pivotY:Float = entityData.pivotY != null ? entityData.pivotY : 0.0;
                                        entityLayer.placeEntity(def, tileset, entityData.x, entityData.y,
                                            app.renderer, programInfo, pivotX, pivotY, entityData.uid, fallback);
                                        importedCount++;
                                    }
                                }
                            } else if (layerData.entities != null) {
                                var legacyEntities:Array<Dynamic> = layerData.entities;
                                var programInfo = app.renderer.getProgramInfo("texture");
                                for (entityData in legacyEntities) {
                                    var def = entityManager.getEntityDefinition(entityData.name);
                                    if (def == null) continue;
                                    var tsName:String = Std.is(entityData.tilesetName, String) ? entityData.tilesetName : null;
                                    var lookupName = tsName != null ? tsName : def.tilesetName;
                                    var tileset:EditorTexture = tilesetManager.tilesets.get(lookupName);
                                    if (tileset == null) continue;
                                    var pivotX:Float = entityData.pivotX != null ? entityData.pivotX : 0.0;
                                    var pivotY:Float = entityData.pivotY != null ? entityData.pivotY : 0.0;
                                    entityLayer.placeEntity(def, tileset, entityData.x, entityData.y,
                                        app.renderer, programInfo, pivotX, pivotY, entityData.uid);
                                    importedCount++;
                                }
                            }

                            for (eentry in entityLayer.batches) {
                                if (eentry.batch != null && eentry.batch.needsBufferUpdate)
                                    eentry.batch.updateBuffers(app.renderer);
                            }
                        }
                    }
                }
            }

            // Map bounds and tile size restore, if present
            var tsx:Int = (mapData.mapBounds != null && mapData.mapBounds.tileSizeX != null) ? Std.int(mapData.mapBounds.tileSizeX) : 64;
            var tsy:Int = (mapData.mapBounds != null && mapData.mapBounds.tileSizeY != null) ? Std.int(mapData.mapBounds.tileSizeY) : 64;
            if (mapData.mapBounds != null) {
                updateMapBounds(mapData.mapBounds.x, mapData.mapBounds.y, mapData.mapBounds.width, mapData.mapBounds.height);
                setTileSize(tsx, tsy);
            }

            return importedCount;

        } catch (e:Dynamic) {
            var errMsg = "Error importing JSON: " + e;
            app.log.error(LogCategory.APP, errMsg);
            trace(errMsg);
            return -1;
        }
    }

    private function clearLayers():Void {
        var layersToRemove:Array<Layer> = [];
        for (entity in entities) {
            if (Std.isOfType(entity, Layer)) {
                layersToRemove.push(cast entity);
            }
        }

        for (layer in layersToRemove) {
            if (Std.isOfType(layer, TilemapLayer)) {
                var tl:TilemapLayer = cast layer;
                if (tl.managedTileBatch != null) tl.managedTileBatch.clear();
                if (tl.tileGrid != null) tl.tileGrid.clear();
            } else if (Std.isOfType(layer, EntityLayer)) {
                var el:EntityLayer = cast layer;
                for (entry in el.batches) {
                    if (entry.batch != null) entry.batch.clear();
                    if (entry.entities != null) {
                        for (ent in entry.entities) {
                            if (ent.text != null) ent.text.remove();
                        }
                        entry.entities.clear();
                    }
                    if (entry.definedRegions != null) entry.definedRegions.clear();
                }
            }
            entities.remove(layer);
        }

        activeLayer = null;
    }

    private function setCurrentTileset(name:String):Void {
        tilesetManager.currentTilesetName = name;
    }
    
    private function setTileSize(x:Int, y:Int):Void {
        tileSizeX = x;
        tileSizeY = y;

        if (grid != null) {
            grid.subGridSizeX = tileSizeX;
            grid.subGridSizeY = tileSizeY;
            grid.gridSizeX = tileSizeX * 4.0;
            grid.gridSizeY = tileSizeY * 4.0;
        }
    }

    /**
     * Change the snap tile size and reposition all existing tiles in every
     * TilemapLayer so their world coordinates stay consistent with the new grid.
     * @param newSizeX New tile width in pixels
     * @param newSizeY New tile height in pixels
     */
    public function recalibrateTileSize(newSizeX:Int, newSizeY:Int):Void {
        if (newSizeX <= 0 || newSizeY <= 0) return;

        for (entity in entities) {
            if (!Std.isOfType(entity, TilemapLayer)) continue;
            var tilemapLayer:TilemapLayer = cast entity;

            for (gridKey in tilemapLayer.tileGrid.keys()) {
                var parts = gridKey.split("_");
                var gridX = Std.parseInt(parts[0]);
                var gridY = Std.parseInt(parts[1]);
                var tileId = tilemapLayer.tileGrid.get(gridKey);

                tilemapLayer.managedTileBatch.updateTilePosition(
                    tileId,
                    gridX * newSizeX,
                    gridY * newSizeY
                );
            }

            if (Lambda.count(tilemapLayer.tileGrid) > 0)
                tilemapLayer.managedTileBatch.needsBufferUpdate = true;
        }

        tileSizeX = newSizeX;
        tileSizeY = newSizeY;

        // Sync the visual grid
        if (grid != null) {
            grid.subGridSizeX = newSizeX;
            grid.subGridSizeY = newSizeY;
            grid.gridSizeX = newSizeX * 4.0;
            grid.gridSizeY = newSizeY * 4.0;
        }
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

        // Sync every EntityLayer quadtree to the new world bounds
        var cx = mapX + mapWidth  * 0.5;
        var cy = mapY + mapHeight * 0.5;
        for (entity in entities) {
            var el = Std.downcast(entity, EntityLayer);
            if (el != null) el.setWorldBounds(cx, cy, mapWidth, mapHeight);
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

        // Draw quadtree debug overlay (repopulated each frame from all EntityLayers)
        if (showQuadtreeDebug && quadtreeDebug != null) {
            quadtreeDebug.clear();
            for (entity in entities) {
                var el = Std.downcast(entity, EntityLayer);
                if (el != null) el.drawDebugQuadtree(quadtreeDebug, [1.0, 1.0, 1.0, 1.0]);
            }
            quadtreeDebug.updateBuffers(renderer);
            renderDisplayObject(renderer, viewProjectionMatrix, quadtreeDebug);
        }

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

        // Draw entity name labels on top of all entity sprites.
        // Tiles are rebuilt fresh every frame so they always reflect current entity positions
        // regardless of whether entities came from JSON import or interactive placement.
        if (entityLabelFont != null) {
            buildEntityLabels();
            renderer.renderDisplayObject(entityLabelFont, viewProjectionMatrix);
        }

        // Draw selection outline on top of everything
        if (selection != null) {
            renderDisplayObject(renderer, viewProjectionMatrix, selection.getLineBatch());
        }
    }
    
    /**
     * Rebuild all entity label font tiles fresh each frame.
     * This approach is immune to timing issues (JSON import vs. interactive placement)
     * because tiles are never stored persistently — they are regenerated every render frame
     * directly from the current entity data in all visible entity layers.
     */
    private function buildEntityLabels():Void {
        // Remove all tiles from previous frame
        entityLabelFont.clear();

        for (entity in entities) {
            var el = Std.downcast(entity, EntityLayer);
            if (el == null || !el.visible) continue;

            for (entry in el.batches) {
                for (ent in entry.entities) {
                    var renderX = ent.x - ent.pivotX * ent.width;
                    var renderY = ent.y - ent.pivotY * ent.height;
                    var textWidth = entityLabelFont.measureTextWidth(ent.name);
                    var cursorX:Float = Math.round(renderX + ent.width * 0.5 - textWidth * 0.5);
                    var cursorY:Float = Math.round(renderY - entityLabelFont.fontData.lineHeight - 2);

                    for (i in 0...ent.name.length) {
                        var charCode = ent.name.charCodeAt(i);
                        var fontChar = entityLabelFont.getCharData(charCode);
                        if (fontChar == null) {
                            cursorX += entityLabelFont.fontData.lineHeight * 0.5;
                            continue;
                        }
                        var regionId = entityLabelFont.getRegionForChar(charCode);
                        if (regionId == -1) {
                            cursorX += fontChar.xadvance;
                            continue;
                        }
                        entityLabelFont.addTile(
                            cursorX + fontChar.xoffset,
                            cursorY + fontChar.yoffset,
                            fontChar.width, fontChar.height,
                            regionId
                        );
                        cursorX += fontChar.xadvance;
                    }
                }
            }
        }

        entityLabelFont.needsBufferUpdate = true;
    }

    override public function release():Void {
        // Layers are entities and will be cleaned up by super.release()
        activeLayer = null;
        super.release();
    }
}

