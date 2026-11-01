package utils;

import display.LineBatch;

typedef EntityBounds = {
    id:String,
    x:Float,    // center X
    y:Float,    // center Y
    width:Float,
    height:Float,
}

/**
 * Simple axis-aligned quadtree for broad-phase entity spatial queries.
 *
 * Entities are inserted by their AABB center (cx, cy) and half-extents.
 * pickEntity() performs a broad-phase cell query followed by a narrow-phase
 * AABB containment test against the full bounds map.
 */
class EntityQuadtree {

    private static inline var MAX_DEPTH:Int    = 6;
    private static inline var MAX_OBJECTS:Int  = 8;

    private var _x:Float;
    private var _y:Float;
    private var _w:Float;
    private var _h:Float;
    private var _depth:Int;

    private var _objects:Array<{id:String, cx:Float, cy:Float, hw:Float, hh:Float}> = [];
    private var _children:Array<EntityQuadtree> = null;

    public function new(x:Float, y:Float, w:Float, h:Float, depth:Int = 0) {
        _x = x;  _y = y;  _w = w;  _h = h;  _depth = depth;
    }

    // ── Public API ─────────────────────────────────────────────────────────────

    public function clear():Void {
        _objects = [];
        if (_children != null) {
            for (c in _children) c.clear();
            _children = null;
        }
    }

    public function insert(id:String, cx:Float, cy:Float, width:Float, height:Float):Void {
        var hw = width  * 0.5;
        var hh = height * 0.5;
        _insert(id, cx, cy, hw, hh);
    }

    /**
     * Broad-phase + narrow-phase point pick.
     * Returns entity ID of the first entity whose AABB contains (px, py), or null.
     */
    public function pickEntity(px:Float, py:Float, bounds:Map<String, EntityBounds>):String {
        var candidates:Array<String> = [];
        _query(px, py, candidates);

        for (id in candidates) {
            var b = bounds.get(id);
            if (b == null) continue;
            var hw = b.width  * 0.5;
            var hh = b.height * 0.5;
            if (px >= b.x - hw && px <= b.x + hw &&
                py >= b.y - hh && py <= b.y + hh) {
                return id;
            }
        }
        return null;
    }

    /** Draw cell boundaries into a LineBatch for debug visualisation. */
    public function drawDebug(batch:LineBatch, color:Array<Float>):Void {
        _drawCell(batch, color);
    }

    // ── Internals ──────────────────────────────────────────────────────────────

    private function _insert(id:String, cx:Float, cy:Float, hw:Float, hh:Float):Void {
        if (_children != null) {
            var idx = _childIndex(cx, cy, hw, hh);
            if (idx != -1) {
                _children[idx]._insert(id, cx, cy, hw, hh);
                return;
            }
        }

        _objects.push({ id:id, cx:cx, cy:cy, hw:hw, hh:hh });

        if (_objects.length > MAX_OBJECTS && _depth < MAX_DEPTH) {
            if (_children == null) _subdivide();
            var remaining = [];
            for (o in _objects) {
                var idx = _childIndex(o.cx, o.cy, o.hw, o.hh);
                if (idx != -1)
                    _children[idx]._insert(o.id, o.cx, o.cy, o.hw, o.hh);
                else
                    remaining.push(o);
            }
            _objects = remaining;
        }
    }

    private function _query(px:Float, py:Float, out:Array<String>):Void {
        for (o in _objects) {
            if (px >= o.cx - o.hw && px <= o.cx + o.hw &&
                py >= o.cy - o.hh && py <= o.cy + o.hh) {
                out.push(o.id);
            }
        }
        if (_children != null) {
            for (c in _children) {
                if (px >= c._x && px < c._x + c._w &&
                    py >= c._y && py < c._y + c._h) {
                    c._query(px, py, out);
                }
            }
        }
    }

    private function _subdivide():Void {
        var hw = _w * 0.5;
        var hh = _h * 0.5;
        var d  = _depth + 1;
        _children = [
            new EntityQuadtree(_x,      _y,      hw, hh, d),  // NW
            new EntityQuadtree(_x + hw, _y,      hw, hh, d),  // NE
            new EntityQuadtree(_x,      _y + hh, hw, hh, d),  // SW
            new EntityQuadtree(_x + hw, _y + hh, hw, hh, d),  // SE
        ];
    }

    /**
     * Returns which child quadrant the AABB fits entirely inside, or -1
     * if it straddles a boundary and must stay in the parent.
     */
    private function _childIndex(cx:Float, cy:Float, hw:Float, hh:Float):Int {
        if (_children == null) return -1;
        var midX = _x + _w * 0.5;
        var midY = _y + _h * 0.5;
        var inTop    = (cy - hh >= _y   && cy + hh < midY);
        var inBottom = (cy - hh >= midY && cy + hh < _y + _h);
        var inLeft   = (cx - hw >= _x   && cx + hw < midX);
        var inRight  = (cx - hw >= midX && cx + hw < _x + _w);
        if (inLeft  && inTop)    return 0;
        if (inRight && inTop)    return 1;
        if (inLeft  && inBottom) return 2;
        if (inRight && inBottom) return 3;
        return -1;
    }

    private function _drawCell(batch:LineBatch, color:Array<Float>):Void {
        batch.addLine(_x,      _y,      0, _x + _w, _y,      0, color, color);
        batch.addLine(_x + _w, _y,      0, _x + _w, _y + _h, 0, color, color);
        batch.addLine(_x + _w, _y + _h, 0, _x,      _y + _h, 0, color, color);
        batch.addLine(_x,      _y + _h, 0, _x,      _y,      0, color, color);
        if (_children != null) {
            for (c in _children) c._drawCell(batch, color);
        }
    }
}
