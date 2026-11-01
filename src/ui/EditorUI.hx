package ui;

import gui.Button;
import gui.Canvas;
import gui.ControlEventType;
import gui.Dialog;
import gui.PropertyGrid;
import gui.Toolstrip;
import gui.Toolstripmenu;
import states.EditorState;
import type.ToolType;

/**
 * EditorUI — builds and owns all GUI controls that live on the editor canvas.
 *
 * Instantiated by EditorState._initCanvas() after the Canvas is ready.
 * Each UI section (menubar, toolbar, panels, etc.) is added here step-by-step.
 */
class EditorUI {

    // ── Controls ──────────────────────────────────────────────────────────────

    public var menubar:Toolstripmenu;
    public var toolbar:Toolstrip;
    public var propertyGrid:PropertyGrid;
    public var mapProperties:MapProperties;
    public var tilesetManagerDialog:Dialog;

    private static inline var PROPERTY_GRID_WIDTH:Float = 240;
    private static inline var CONTENT_TOP:Float = 24;
    private static inline var TILESET_DIALOG_WIDTH:Float = 480;
    private static inline var TILESET_DIALOG_HEIGHT:Float = 360;

    // ── Callbacks (wire from EditorState or EditorMain) ───────────────────────

    public var onNewProject:Void->Void   = null;
    public var onOpenProject:Void->Void  = null;
    public var onSave:Void->Void         = null;
    public var onSaveAs:Void->Void       = null;
    public var onClose:Void->Void        = null;

    // ── Privates ──────────────────────────────────────────────────────────────

    private var _canvas:Canvas;
    private var _state:EditorState;

    // Local toggle state for View menu items (mirrors EditorState bools)
    private var _labelsVisible:Bool     = true;
    private var _gridVisible:Bool       = true;
    private var _axesVisible:Bool       = true;

    public function new(canvas:Canvas, state:EditorState) {
        _canvas = canvas;
        _state  = state;
    }

    /**
     * Build all UI panels. Call once after the canvas is initialised.
     */
    public function build():Void {
        _buildMenubar();
        //_buildToolbar();
        _buildPropertyGrid();
        _buildTilesetManagerDialog();

        // Keep the canvas and its full-width controls in sync with window resize.
        _canvas.onResize = function(w, h) _onCanvasResize(w, h);
    }

    // ── Menubar ───────────────────────────────────────────────────────────────

    private function _buildMenubar():Void {
        menubar = new Toolstripmenu();
        _canvas.addControl(menubar);

        // Resize both the outer container and the internal ToolstripBar to fill
        // the window width (both default-construct at a hardcoded 640).
        menubar.width = _canvas.width;
        @:privateAccess menubar.__strip.width = _canvas.width;

        menubar.addItem("File", [
            "New Project", "Open Project", "Save", "Save As", "Close"
        ], _onFileMenu);

        menubar.addItem("Edit", [
            "Undo", "Redo", "Cut", "Copy", "Paste", "Delete"
        ], null);

        menubar.addItem("Project", [
            "Project Settings", "Map Properties", "Export Map"
        ], _onProjectMenu);

        menubar.addItem("Map", [
            "Tileset Manager"
        ], _onMapMenu);

        menubar.addItem("View", [
            "Toggle Grid", "Toggle World Axes", "Toggle Entity Labels", "Zoom In", "Zoom Out", "Reset Zoom"
        ], _onViewMenu);

        menubar.addItem("Tools", [
            "Tile Draw", "Tile Erase", "Entity Add", "Entity Select"
        ], _onToolsMenu);

        menubar.addItem("Help", ["About"], null);
    }

    private function _onFileMenu(opt:String):Void {
        switch (opt) {
            case "New Project":  if (onNewProject  != null) onNewProject();
            case "Open Project": if (onOpenProject != null) onOpenProject();
            case "Save":         if (onSave        != null) onSave();
            case "Save As":      if (onSaveAs      != null) onSaveAs();
            case "Close":        if (onClose       != null) onClose();
        }
    }

    private function _onProjectMenu(opt:String):Void {
        if (opt == "Map Properties") propertyGrid.refreshProperties();
    }

    private function _onMapMenu(opt:String):Void {
        if (opt == "Tileset Manager") {
            tilesetManagerDialog.x = Math.max(0, (_canvas.width - TILESET_DIALOG_WIDTH) * 0.5);
            tilesetManagerDialog.y = Math.max(0, (_canvas.height - TILESET_DIALOG_HEIGHT) * 0.5);
            _canvas.dialog = tilesetManagerDialog;
        }
    }

    private function _onViewMenu(opt:String):Void {
        switch (opt) {
            case "Toggle Grid":
                _gridVisible = !_state.grid.visible;
                _state.setGridDisplayMode(_gridVisible ? "Colored" : "Hidden");
            case "Toggle World Axes":
                _axesVisible = !_axesVisible;
                _state.showWorldAxes = _axesVisible;
            case "Toggle Entity Labels":
                _labelsVisible = !_labelsVisible;
                _state.toggleLabels(_labelsVisible);
            case "Zoom In":
                _state.zoomIn(EditorState.ZOOM_STEP);
            case "Zoom Out":
                _state.zoomOut(EditorState.ZOOM_STEP);
            case "Reset Zoom":
                _state.resetZoom();
        }
    }

    private function _onToolsMenu(opt:String):Void {
        _setTool(switch (opt) {
            case "Tile Draw":     ToolType.TILE_DRAW;
            case "Tile Erase":    ToolType.TILE_ERASE;
            case "Entity Add":    ToolType.ENTITY_ADD;
            case "Entity Select": ToolType.ENTITY_SELECT;
            default:              _state.toolType;
        });
    }

    // ── Toolbar ───────────────────────────────────────────────────────────────

    private function _buildToolbar():Void {
        toolbar = new Toolstrip(_canvas.width, 0, 24);
        // Resize to full width (Toolstrip hardcodes 640 in its super() call)
        toolbar.width = _canvas.width;
        _canvas.addControl(toolbar);

        var zoomInButton = new Button("+", 28, 0, 0);
        zoomInButton.addListener(
            function(_, _) _state.zoomIn(EditorState.ZOOM_STEP),
            ControlEventType.LEFT_CLICK
        );
        toolbar.addControl(zoomInButton);

        var zoomOutButton = new Button("-", 28, 0, 0);
        zoomOutButton.addListener(
            function(_, _) _state.zoomOut(EditorState.ZOOM_STEP),
            ControlEventType.LEFT_CLICK
        );
        toolbar.addControl(zoomOutButton);
    }

    private function _buildPropertyGrid():Void {
        propertyGrid = new PropertyGrid(
            PROPERTY_GRID_WIDTH,
            Math.max(0, _canvas.height - CONTENT_TOP),
            0,
            CONTENT_TOP
        );
        mapProperties = new MapProperties(_state);
        _canvas.addControl(propertyGrid);
        propertyGrid.setProperties(mapProperties);
    }

    private function _buildTilesetManagerDialog():Void {
        tilesetManagerDialog = new Dialog(
            "Tileset Manager",
            TILESET_DIALOG_WIDTH,
            TILESET_DIALOG_HEIGHT
        );
        tilesetManagerDialog.x = Math.max(0, (_canvas.width - TILESET_DIALOG_WIDTH) * 0.5);
        tilesetManagerDialog.y = Math.max(0, (_canvas.height - TILESET_DIALOG_HEIGHT) * 0.5);
        tilesetManagerDialog.visible = false;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function _onCanvasResize(w:Int, h:Int):Void {
        menubar.width = w;
        @:privateAccess menubar.__strip.width = w;
        //toolbar.width = w;
        propertyGrid.resize(
            Math.min(PROPERTY_GRID_WIDTH, w),
            Math.max(0, h - CONTENT_TOP)
        );
    }

    private function _setTool(tool:ToolType):Void {
        _state.toolType = tool;
    }
}
