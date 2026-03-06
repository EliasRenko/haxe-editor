package utils;

import differ.shapes.Polygon;
import differ.shapes.Circle;
import differ.Collision;
import display.LineBatch;

/**
 * Axis-aligned bounding box record stored in the quadtree for each entity.
 * (x, y) is the CENTER of the entity in world space.
 */
typedef EntityBounds = {
    var id:Int;
    var x:Float;
    var y:Float;
    var width:Float;
    var height:Float;
}

/**
 * Quadtree for broad-phase entity spatial partitioning.
 *
 * Usage pattern:
 *   1. Broad phase  — queryPoint / query      → candidate ID list
 *   2. Narrow phase — pickEntity (SAT via Differ) → exact hit
 *   3. Debug draw   — drawDebug (LineBatch)   → cell outlines
 *
 * All coordinates are world-space with (x, y) as the CENTER of a region.
 */
class EntityQuadtree {

    /** Maximum entities per leaf node before the node is subdivided. */
    public static inline var MAX_OBJECTS:Int = 8;
    /** Maximum subdivision depth — prevents infinite splitting for co-located entities. */
    public static inline var MAX_DEPTH:Int   = 8;

    /** Center x of this node's world region. */
    public var x:Float;
    /** Center y of this node's world region. */
    public var y:Float;
    /** Width of this node's world region. */
    public var width:Float;
    /** Height of this node's world region. */
    public var height:Float;

    private var depth:Int;
    private var objects:Array<EntityBounds>;
    /** Four children (TL, TR, BR, BL) after a split, or null while still a leaf. */
    private var nodes:Array<EntityQuadtree>;

    /**
     * @param x       Center X of the root region (world space)
     * @param y       Center Y of the root region (world space)
     * @param width   Width  of the root region
     * @param height  Height of the root region
     * @param depth   Internal recursion depth — leave at 0 for the root
     */
    public function new(x:Float, y:Float, width:Float, height:Float, depth:Int = 0) {
        this.x      = x;
        this.y      = y;
        this.width  = width;
        this.height = height;
        this.depth  = depth;
        objects     = [];
        nodes       = null;
    }

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /** Remove every entity and collapse all child nodes back to leaf state. */
    public function clear():Void {
        objects = [];
        if (nodes != null) {
            for (n in nodes) n.clear();
            nodes = null;
        }
    }

    /**
     * Insert an entity into the tree.
     *
     * @param id  Unique entity ID (as returned by EntityLayer.placeEntity)
     * @param ex  Center X of the entity AABB in world space
     * @param ey  Center Y of the entity AABB in world space
     * @param ew  Width  of the entity AABB
     * @param eh  Height of the entity AABB
     */
    public function insert(id:Int, ex:Float, ey:Float, ew:Float, eh:Float):Void {
        // If already split, try to delegate to a single child
        if (nodes != null) {
            var idx = _getQuadrant(ex, ey, ew, eh);
            if (idx >= 0) {
                nodes[idx].insert(id, ex, ey, ew, eh);
                return;
            }
        }

        // Store in this node
        objects.push({ id:id, x:ex, y:ey, width:ew, height:eh });

        // Split if over capacity and still within depth limit
        if (objects.length > MAX_OBJECTS && depth < MAX_DEPTH) {
            if (nodes == null) _split();
            // Push down any objects that now fit in a single child
            var remaining:Array<EntityBounds> = [];
            for (obj in objects) {
                var idx = _getQuadrant(obj.x, obj.y, obj.width, obj.height);
                if (idx >= 0) nodes[idx].insert(obj.id, obj.x, obj.y, obj.width, obj.height);
                else          remaining.push(obj);
            }
            objects = remaining;
        }
    }

    /**
     * Broad-phase AABB overlap query.
     * Fills `result` with the IDs of entities whose bounding boxes overlap
     * the supplied query rectangle (qx, qy, qw, qh — center + size).
     * Does NOT deduplicate; callers should use a Set if needed.
     */
    public function query(qx:Float, qy:Float, qw:Float, qh:Float, result:Array<Int>):Void {
        var qL = qx - qw * 0.5;  var qR = qx + qw * 0.5;
        var qT = qy - qh * 0.5;  var qB = qy + qh * 0.5;

        for (obj in objects) {
            var oL = obj.x - obj.width  * 0.5;  var oR = obj.x + obj.width  * 0.5;
            var oT = obj.y - obj.height * 0.5;  var oB = obj.y + obj.height * 0.5;
            if (oR >= qL && oL <= qR && oB >= qT && oT <= qB) result.push(obj.id);
        }

        if (nodes != null) {
            var idx = _getQuadrant(qx, qy, qw, qh);
            if (idx >= 0) {
                // Query fits in a single child
                nodes[idx].query(qx, qy, qw, qh, result);
            } else {
                // Query spans multiple children — descend all
                for (n in nodes) n.query(qx, qy, qw, qh, result);
            }
        }
    }

    /**
     * Convenience wrapper: collects candidate entity IDs near world point (px, py).
     * Uses a 1×1 query box — use pickEntity() or pickEntityAABB() for the exact test.
     */
    public function queryPoint(px:Float, py:Float, result:Array<Int>):Void {
        query(px, py, 1.0, 1.0, result);
    }

    /**
     * Narrow-phase SAT point pick using Differ.
     * Runs broad-phase first, then tests each candidate with a Polygon AABB via SAT.
     *
     * @param px      World X of the pick point (e.g. mouse cursor)
     * @param py      World Y of the pick point
     * @param bounds  Map from entity ID → EntityBounds (call EntityLayer.getAllEntityBounds())
     * @return        ID of the first entity that contains (px, py), or -1 if none.
     */
    public function pickEntity(px:Float, py:Float, bounds:Map<Int, EntityBounds>):Int {
        var candidates:Array<Int> = [];
        queryPoint(px, py, candidates);
        if (candidates.length == 0) return -1;

        // Tiny circle probe at the cursor position
        var probe = new Circle(px, py, 0.5);
        for (id in candidates) {
            var b = bounds.get(id);
            if (b == null) continue;
            var rect = Polygon.rectangle(b.x, b.y, b.width, b.height, true);
            if (Collision.shapeWithShape(probe, rect) != null) return id;
        }
        return -1;
    }

    /**
     * Lightweight AABB-only point pick — no SAT overhead.
     * Returns the first entity whose bounding box contains (px, py), or -1.
     *
     * Prefer pickEntity() when you need exact SAT accuracy (e.g. rotated shapes).
     * Use this for simple rectangular entities where AABB is exact enough.
     */
    public function pickEntityAABB(px:Float, py:Float, bounds:Map<Int, EntityBounds>):Int {
        var candidates:Array<Int> = [];
        queryPoint(px, py, candidates);
        for (id in candidates) {
            var b = bounds.get(id);
            if (b == null) continue;
            var l = b.x - b.width  * 0.5;  var r = b.x + b.width  * 0.5;
            var t = b.y - b.height * 0.5;  var bm = b.y + b.height * 0.5;
            if (px >= l && px <= r && py >= t && py <= bm) return id;
        }
        return -1;
    }

    /**
     * Draw the quadtree cell boundaries into a LineBatch for debug visualisation.
     * Only draws cells that contain at least one entity or have children.
     *
     * Example:
     *   entityLayer.quadtree.drawDebug(myLineBatch, [0.2, 0.8, 0.2, 0.6]);
     *
     * @param lineBatch  LineBatch instance (persistent = false for per-frame draw)
     * @param color      RGBA color, e.g. [0.2, 0.9, 0.2, 0.7]
     */
    public function drawDebug(lineBatch:LineBatch, color:Array<Float>):Void {
        // Always draw this cell's outline so the root is visible even when empty
        var l = x - width  * 0.5;  var r = x + width  * 0.5;
        var t = y - height * 0.5;  var b = y + height * 0.5;

        lineBatch.addLine(l, t, 0,  r, t, 0,  color, color); // top edge
        lineBatch.addLine(r, t, 0,  r, b, 0,  color, color); // right edge
        lineBatch.addLine(r, b, 0,  l, b, 0,  color, color); // bottom edge
        lineBatch.addLine(l, b, 0,  l, t, 0,  color, color); // left edge

        // Only recurse into children that actually hold data, to avoid drawing
        // all 4^depth empty leaf cells of the full tree
        if (nodes != null) {
            for (n in nodes) {
                if (n.objects.length > 0 || n.nodes != null) n.drawDebug(lineBatch, color);
            }
        }
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /** Subdivide this node into four equal child quadrants. */
    private function _split():Void {
        var hw = width  * 0.5;
        var hh = height * 0.5;
        // Order: top-left, top-right, bottom-right, bottom-left
        nodes = [
            new EntityQuadtree(x - hw * 0.5, y - hh * 0.5, hw, hh, depth + 1),
            new EntityQuadtree(x + hw * 0.5, y - hh * 0.5, hw, hh, depth + 1),
            new EntityQuadtree(x + hw * 0.5, y + hh * 0.5, hw, hh, depth + 1),
            new EntityQuadtree(x - hw * 0.5, y + hh * 0.5, hw, hh, depth + 1)
        ];
    }

    /**
     * Returns the child quadrant index [0-3] when the AABB fits entirely within
     * one quadrant, or -1 when it straddles a boundary and must stay in the parent.
     */
    private function _getQuadrant(ex:Float, ey:Float, ew:Float, eh:Float):Int {
        if (nodes == null) return -1;
        var el = ex - ew * 0.5;  var er = ex + ew * 0.5;
        var et = ey - eh * 0.5;  var eb = ey + eh * 0.5;
        for (i in 0...4) {
            var n  = nodes[i];
            var nl = n.x - n.width  * 0.5;  var nr = n.x + n.width  * 0.5;
            var nt = n.y - n.height * 0.5;  var nb = n.y + n.height * 0.5;
            if (el >= nl && er <= nr && et >= nt && eb <= nb) return i;
        }
        return -1;
    }
}
