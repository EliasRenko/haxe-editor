package display;

import ProgramInfo;
import Renderer;
import math.Matrix;
import display.LineBatch;

/**
 * Visual frame showing map boundaries with resize handles
 * Note: Not a DisplayObject itself, just manages a LineBatch
 */
class MapFrame {
    
    public var visible:Bool = true;
    private var lineBatch:LineBatch;
    private var x:Float;
    private var y:Float;
    private var width:Float;
    private var height:Float;
    
    // Handle properties
    private var handleSize:Float = 16.0;
    
    // Colors
    private var frameColor:Array<Float> = [1.0, 1.0, 0.0, 1.0]; // Yellow frame
    private var handleColor:Array<Float> = [1.0, 0.5, 0.0, 1.0]; // Orange handles
    
    public function new(programInfo:ProgramInfo, x:Float, y:Float, width:Float, height:Float) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        
        // Create persistent line batch for the frame
        lineBatch = new LineBatch(programInfo, true);
        lineBatch.depthTest = false;
    }
    
    /**
     * Update map bounds and rebuild the frame
     */
    public function setBounds(x:Float, y:Float, width:Float, height:Float):Void {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        rebuildFrame();
    }
    
    /**
     * Rebuild the frame lines and handles
     */
    private function rebuildFrame():Void {
        lineBatch.clear();
        
        var z = 0.1; // Slightly in front
        
        // Draw frame rectangle (4 lines)
        // Top line
        lineBatch.addLine(x, y, z, x + width, y, z, frameColor, frameColor);
        // Right line
        lineBatch.addLine(x + width, y, z, x + width, y + height, z, frameColor, frameColor);
        // Bottom line
        lineBatch.addLine(x + width, y + height, z, x, y + height, z, frameColor, frameColor);
        // Left line
        lineBatch.addLine(x, y + height, z, x, y, z, frameColor, frameColor);
        
        // Draw handles (as small boxes - 4 lines each)
        drawHandle(getTopHandle(), z);
        drawHandle(getBottomHandle(), z);
        drawHandle(getLeftHandle(), z);
        drawHandle(getRightHandle(), z);
    }
    
    /**
     * Draw a handle box
     */
    private function drawHandle(handle:{x:Float, y:Float, width:Float, height:Float}, z:Float):Void {
        var x1 = handle.x;
        var y1 = handle.y;
        var x2 = handle.x + handle.width;
        var y2 = handle.y + handle.height;
        
        // Top
        lineBatch.addLine(x1, y1, z, x2, y1, z, handleColor, handleColor);
        // Right
        lineBatch.addLine(x2, y1, z, x2, y2, z, handleColor, handleColor);
        // Bottom
        lineBatch.addLine(x2, y2, z, x1, y2, z, handleColor, handleColor);
        // Left
        lineBatch.addLine(x1, y2, z, x1, y1, z, handleColor, handleColor);
    }
    
    public function init(renderer:Renderer):Void {
        lineBatch.init(renderer);
        rebuildFrame();
    }
    
    public function render(viewProjectionMatrix:Matrix, renderer:Renderer):Void {
        if (!visible) return;
        
        // Update buffers if needed (should only happen once after init)
        if (lineBatch.needsBufferUpdate) {
            lineBatch.updateBuffers(renderer);
        }
        
        // Render the line batch
        lineBatch.render(viewProjectionMatrix);
        
        // Actually draw the lines to the screen
        renderer.renderDisplayObject(lineBatch, viewProjectionMatrix);
    }
    
    /**
     * Get the internal LineBatch for renderer management
     */
    public function getLineBatch():LineBatch {
        return lineBatch;
    }
    
    /**
     * Get handle bounds for hit testing
     */
    public function getTopHandle():{x:Float, y:Float, width:Float, height:Float} {
        return {
            x: x + width * 0.5 - handleSize * 0.5,
            y: y - handleSize * 0.5,
            width: handleSize,
            height: handleSize
        };
    }
    
    public function getBottomHandle():{x:Float, y:Float, width:Float, height:Float} {
        return {
            x: x + width * 0.5 - handleSize * 0.5,
            y: y + height - handleSize * 0.5,
            width: handleSize,
            height: handleSize
        };
    }
    
    public function getLeftHandle():{x:Float, y:Float, width:Float, height:Float} {
        return {
            x: x - handleSize * 0.5,
            y: y + height * 0.5 - handleSize * 0.5,
            width: handleSize,
            height: handleSize
        };
    }
    
    public function getRightHandle():{x:Float, y:Float, width:Float, height:Float} {
        return {
            x: x + width - handleSize * 0.5,
            y: y + height * 0.5 - handleSize * 0.5,
            width: handleSize,
            height: handleSize
        };
    }

    // ── Resize state ─────────────────────────────────────────────────────────

    /** Currently active resize handle ("top"/"bottom"/"left"/"right"), or null when not resizing. */
    public var resizeMode:String = null;

    /** Minimum dimension (px) the map can be resized to (default: 10 × 32 px tile). */
    public var minMapSize:Float = 320.0;

    private var _resizeDragStart:{x:Float, y:Float} = null;
    private var _resizeOriginalBounds:{x:Float, y:Float, width:Float, height:Float} = null;

    /**
     * Hit-test a world position against the four resize handles.
     * Returns "top", "bottom", "left", "right", or null.
     */
    public function getHandleAt(worldX:Float, worldY:Float):String {
        var handles = [
            {name: "top",    bounds: getTopHandle()},
            {name: "bottom", bounds: getBottomHandle()},
            {name: "left",   bounds: getLeftHandle()},
            {name: "right",  bounds: getRightHandle()}
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
     * Begin a resize drag: record the active handle and the initial world cursor
     * position so computeResizeBounds() can calculate deltas each frame.
     */
    public function startResize(handle:String, worldX:Float, worldY:Float):Void {
        resizeMode            = handle;
        _resizeDragStart      = {x: worldX, y: worldY};
        _resizeOriginalBounds = {x: x, y: y, width: width, height: height};
    }

    /** End / cancel the current resize drag. */
    public function cancelResize():Void {
        resizeMode            = null;
        _resizeDragStart      = null;
        _resizeOriginalBounds = null;
    }

    /**
     * Compute new map bounds for the current drag world position.
     * Pure computation — does NOT apply the result.
     * Pass the returned bounds to EditorState.updateMapBounds().
     */
    public function computeResizeBounds(worldX:Float, worldY:Float,
                                        tileSizeX:Float, tileSizeY:Float)
                                        :{x:Float, y:Float, width:Float, height:Float} {
        if (resizeMode == null || _resizeDragStart == null || _resizeOriginalBounds == null)
            return {x: x, y: y, width: width, height: height};

        var deltaX = worldX - _resizeDragStart.x;
        var deltaY = worldY - _resizeDragStart.y;

        // Snap delta to tile grid
        deltaX = Math.round(deltaX / tileSizeX) * tileSizeX;
        deltaY = Math.round(deltaY / tileSizeY) * tileSizeY;

        var newX      = _resizeOriginalBounds.x;
        var newY      = _resizeOriginalBounds.y;
        var newWidth  = _resizeOriginalBounds.width;
        var newHeight = _resizeOriginalBounds.height;

        switch (resizeMode) {
            case "top":
                // Move top edge up/down (changes Y and height)
                newY      = _resizeOriginalBounds.y + deltaY;
                newHeight = _resizeOriginalBounds.height - deltaY;
            case "bottom":
                // Move bottom edge up/down (changes height only)
                newHeight = _resizeOriginalBounds.height + deltaY;
            case "left":
                // Move left edge left/right (changes X and width)
                newX     = _resizeOriginalBounds.x + deltaX;
                newWidth = _resizeOriginalBounds.width - deltaX;
            case "right":
                // Move right edge left/right (changes width only)
                newWidth = _resizeOriginalBounds.width + deltaX;
        }

        // Enforce minimum size
        if (newWidth < minMapSize) {
            if (resizeMode == "left") newX = newX + (newWidth - minMapSize);
            newWidth = minMapSize;
        }
        if (newHeight < minMapSize) {
            if (resizeMode == "top") newY = newY + (newHeight - minMapSize);
            newHeight = minMapSize;
        }

        return {x: newX, y: newY, width: newWidth, height: newHeight};
    }
}
