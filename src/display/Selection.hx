package display;

import ProgramInfo;
import Renderer;
import math.Matrix;
import display.LineBatch;

/**
 * Draws a rectangular selection outline over selected entities.
 * Uses a persistent LineBatch so geometry only rebuilds when the selection changes.
 */
class Selection {

    public var visible:Bool = true;

    /** RGBA colour of the selection rectangle. Default: cyan. */
    public var color:Array<Float> = [0.2, 0.85, 1.0, 1.0];

    private var lineBatch:LineBatch;

    /** Z depth — render slightly above the layers. */
    private static inline var Z:Float = 0.2;

    public function new(programInfo:ProgramInfo) {
        lineBatch = new LineBatch(programInfo, true); // persistent
        lineBatch.depthTest = false;
    }

    public function init(renderer:Renderer):Void {
        lineBatch.init(renderer);
    }

    /**
     * Rebuild the selection rectangles from the provided list.
     * @param entities Array of entries with x/y (pivot world position),
     *                 width, height, pivotX, pivotY (all normalised 0–1).
     */
    public function setSelections(entities:Array<Dynamic>):Void {
        lineBatch.clear();
        for (ent in entities) {
            var x1 = ent.x - ent.pivotX * ent.width;
            var y1 = ent.y - ent.pivotY * ent.height;
            var x2 = x1 + ent.width;
            var y2 = y1 + ent.height;
            // Top
            lineBatch.addLine(x1, y1, Z, x2, y1, Z, color, color);
            // Right
            lineBatch.addLine(x2, y1, Z, x2, y2, Z, color, color);
            // Bottom
            lineBatch.addLine(x2, y2, Z, x1, y2, Z, color, color);
            // Left
            lineBatch.addLine(x1, y2, Z, x1, y1, Z, color, color);
        }
    }

    /** Remove all selection rectangles. */
    public function clear():Void {
        lineBatch.clear();
    }

    /** Expose the underlying LineBatch so callers can pass it to renderDisplayObject. */
    public function getLineBatch():LineBatch {
        return lineBatch;
    }
}
