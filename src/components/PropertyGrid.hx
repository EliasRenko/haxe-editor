package components;

import js.Browser;

/**
 * PropertyGrid — Web Component  <editor-property-grid>
 *
 * Usage in HTML:
 *   <editor-property-grid id="prop-grid"></editor-property-grid>
 *
 * Public API (called from EditorWeb / editor.html JS):
 *   el.clear()
 *   el.addCategory(label:String)
 *   el.addProp(name:String, value:Dynamic)
 */
@:expose("PropertyGrid")
class PropertyGrid {

    public static inline var TAG = "editor-property-grid";

    public static function register():Void {
        HTMLElement.define(TAG, PropertyGridElement);
    }
}

/**
 * The actual HTMLElement implementation.
 * @:nativeGen makes Haxe emit `class PropertyGridElement extends HTMLElement { }` (ES6),
 * which is required by the Custom Elements API.
 */
// Minimal extern so @:nativeGen emits `class ... extends HTMLElement` in JS.
// js.html.Element IS available; js.html.HTMLElement is not in this Haxe build.
@:nativeGen
@:keep
class PropertyGridElement extends HTMLElement {



    // ── Instance state ───────────────────────────────────────────────────────
    var _table:js.html.Element;

    public function new() {
        super();
        _table = null;
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    public function connectedCallback():Void {
        var shadow = HTMLElement.shadow(this);
        if (_table != null) return;
        shadow.innerHTML = haxe.Resource.getString("PropertyGrid");
        _table = HTMLElement.find(shadow, "#t");
    }

    public function disconnectedCallback():Void {}

    public function attributeChangedCallback(name:String, oldVal:String, newVal:String):Void {}

    public function adoptedCallback():Void {}

    // ── Public API ───────────────────────────────────────────────────────────

    public function clear():Void {
        if (_table != null) _table.innerHTML = "";
    }

    public function addCategory(label:String):Void {
        if (_table == null) return;
        var tr = Browser.document.createElement("tr");
        tr.className = "cat";
        tr.innerHTML = '<td colspan="2">' + label + '</td>';
        _table.appendChild(tr);
    }

    public function addProp(name:String, value:Dynamic):Void {
        if (_table == null) return;
        var tr = Browser.document.createElement("tr");
        var v = value != null ? Std.string(value) : "";
        tr.innerHTML = '<td class="name">' + name + '</td><td class="val">' + v + '</td>';
        _table.appendChild(tr);
    }

    /**
     * Refresh the grid from the current Editor selection state.
     * Shows Map properties when nothing is selected, Entity properties otherwise.
     * Called from the entity-selection-changed callback and after Editor.init().
     */
    public function refresh():Void {
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;
        clear();
        var count:Int = editor.getEntitySelectionCount();
        if (count == 0) {
            var mp:Dynamic = editor.getMapProps();
            if (mp != null) {
                addCategory('Map');
                addProp('Width',  mp.width);
                addProp('Height', mp.height);
                addProp('Tile W', mp.tileSizeX);
                addProp('Tile H', mp.tileSizeY);
                if (mp.projectName != null && mp.projectName != "") addProp('Project', mp.projectName);
            }
        } else {
            addCategory('Entity');
            for (i in 0...count) {
                var info:Dynamic = editor.getEntitySelectionInfo(i);
                if (info == null) continue;
                addProp('UID',  info.uid);
                addProp('Name', info.name);
                addProp('X',    info.x);
                addProp('Y',    info.y);
                addProp('W',    info.width);
                addProp('H',    info.height);
            }
        }
    }
}
