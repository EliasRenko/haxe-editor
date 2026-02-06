package states;

import State;
import App;
import Renderer;
import ProgramInfo;
import display.Grid;
import entity.DisplayEntity;

/**
 * Editor state with just an infinite grid for visual reference
 * Minimal state for level editing and scene construction
 */
class EditorState extends State {
    
    private var grid:Grid;
    
    public function new(app:App) {
        super("EditorState", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("EditorState: Initializing");
        
        // Setup camera for 2D orthographic view
        camera.ortho = true;
        
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
        
        trace("EditorState: Grid created - visible=" + grid.visible + ", pos=(" + grid.x + "," + grid.y + "," + grid.z + ")");
        
        var gridEntity = new DisplayEntity(grid, "grid");
        addEntity(gridEntity);
        
        trace("EditorState: Grid entity added - active=" + gridEntity.active + ", visible=" + gridEntity.visible);
        trace("EditorState: Camera - ortho=" + camera.ortho + ", zoom=" + camera.zoom + ", pos=(" + camera.x + "," + camera.y + "," + camera.z + ")");
        trace("EditorState: Setup complete");
    }
    
    private var updateCount:Int = 0;
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        if (updateCount < 3) {
            trace("EditorState: update() frame " + updateCount);
            updateCount++;
        }
    }
    
    private var renderCount:Int = 0;
    
    override public function render(renderer:Renderer):Void {
        // WORKAROUND: Call render() directly due to C++ virtual method dispatch issue
        if (grid != null && grid.visible) {
            if (renderCount < 3) {
                trace("EditorState.render() frame " + renderCount + " - calling grid.render()");
                trace("  grid.vertices.length=" + grid.vertices.length);
                trace("  grid.z=" + grid.z);
                trace("  camera.zoom=" + camera.zoom);
            }
            grid.render(camera.getMatrix());
        } else if (renderCount < 3) {
            trace("EditorState.render() frame " + renderCount + " - grid is null or not visible");
        }
        
        super.render(renderer);
        renderCount++;
    }
    
    override public function release():Void {
        super.release();
    }
}
