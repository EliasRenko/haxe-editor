package components;

import js.Browser;
import js.html.Element;
import js.html.Event;
import js.html.CustomEvent;
import js.html.InputElement;
import js.html.SelectElement;

/**
 * HierarchyPanel — Web Component  <editor-hierarchy>
 *
 * Usage in HTML:
 *   <editor-hierarchy id="hierarchy"></editor-hierarchy>
 *
 * Public API:
 *   el.clearLayers()
 *   el.addLayer(name:String, type:Int)   — type: 0=tilemap, 1=entities, 2=folder
 *   el.refresh()                         — force immediate tree rebuild
 *   el.startSync()                       — start polling loop
 *   el.setActiveLayerChangedCallback(cb: String->Void)
 */
@:expose("HierarchyPanel")
class HierarchyPanel {

    public static inline var TAG = "editor-hierarchy";

    public static function register():Void {
        HTMLElement.define(TAG, HierarchyElement);
    }
}

@:nativeGen
@:keep
class HierarchyElement extends HTMLElement {

    // Layer type icons: 0=tilemap  1=entities  2=folder
    static var ICONS       = ["▦", "⊞", "📁"];
    static var TYPE_LABELS = ["Tilemap", "Entity", "Folder"];

    // ── Instance state ───────────────────────────────────────────────────────
    var _tree:js.html.Element;
    var _layerChangedCb:Null<String->Void>;
    var _syncLayerSig:String;       // name+type signature for change detection
    var _selectedLayerName:Null<String>;
    var _addMenu:Null<js.html.Element>;

    public function new() {
        super();
        _tree              = null;
        _layerChangedCb    = null;
        _syncLayerSig      = "";
        _selectedLayerName = null;
        _addMenu           = null;
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    public function connectedCallback():Void {
        var shadow = HTMLElement.shadow(this);
        if (_tree != null) return;
        shadow.innerHTML = haxe.Resource.getString("HierarchyPanel");
        _tree = cast HTMLElement.find(shadow, "#tree");
        _tree.addEventListener("click", (e:Event) -> onTreeClick(e));

        // Wire toolbar buttons
        HTMLElement.find(shadow, "#btn-add").addEventListener("click",
            (e:Event) -> onAddClick(e));
        HTMLElement.find(shadow, "#btn-remove").addEventListener("click",
            (_:Event) -> onRemoveClick());
        HTMLElement.find(shadow, "#btn-edit").addEventListener("click",
            (_:Event) -> onEditClick());
        HTMLElement.find(shadow, "#btn-up").addEventListener("click",
            (_:Event) -> onMoveUpClick());
        HTMLElement.find(shadow, "#btn-down").addEventListener("click",
            (_:Event) -> onMoveDownClick());

        // Wire creation dialog buttons
        HTMLElement.find(shadow, "#dlg-entity-ok").addEventListener("click",
            (_:Event) -> onEntityDialogOk());
        HTMLElement.find(shadow, "#dlg-entity-cancel").addEventListener("click",
            (_:Event) -> closeDialogs());
        HTMLElement.find(shadow, "#dlg-entity").addEventListener("click",
            (e:Event) -> { if (untyped e.target == e.currentTarget) closeDialogs(); });
        HTMLElement.find(shadow, "#dlg-entity-name").addEventListener("keydown", (e:Event) -> {
            var ke:js.html.KeyboardEvent = cast e;
            if (ke.key == "Enter") onEntityDialogOk();
            else if (ke.key == "Escape") closeDialogs();
        });

        HTMLElement.find(shadow, "#dlg-tilemap-ok").addEventListener("click",
            (_:Event) -> onTilemapDialogOk());
        HTMLElement.find(shadow, "#dlg-tilemap-cancel").addEventListener("click",
            (_:Event) -> closeDialogs());
        HTMLElement.find(shadow, "#dlg-tilemap").addEventListener("click",
            (e:Event) -> { if (untyped e.target == e.currentTarget) closeDialogs(); });
        HTMLElement.find(shadow, "#dlg-tilemap-name").addEventListener("keydown", (e:Event) -> {
            var ke:js.html.KeyboardEvent = cast e;
            if (ke.key == "Enter") onTilemapDialogOk();
            else if (ke.key == "Escape") closeDialogs();
        });
        HTMLElement.find(shadow, "#dlg-tilemap-tilesize").addEventListener("keydown", (e:Event) -> {
            var ke:js.html.KeyboardEvent = cast e;
            if (ke.key == "Enter") onTilemapDialogOk();
            else if (ke.key == "Escape") closeDialogs();
        });
    }

    public function disconnectedCallback():Void {}
    public function attributeChangedCallback(name:String, oldVal:String, newVal:String):Void {}
    public function adoptedCallback():Void {}

    // ── Tree click ───────────────────────────────────────────────────────────

    function onTreeClick(e:Event):Void {
        var target:Element = cast e.target;
        var node:Element   = cast target.closest(".root-node, .layer-node");
        if (node == null) return;

        var sel = _tree.querySelectorAll(".selected");
        for (i in 0...sel.length) (cast sel[i] : Element).classList.remove("selected");
        node.classList.add("selected");

        var layerName:String = untyped node.dataset.layer;
        if (layerName != null && layerName != "") {
            _selectedLayerName = layerName;
            dispatchEvent(new CustomEvent("layer-changed",
                cast { bubbles: true, detail: { name: layerName } }));
            if (_layerChangedCb != null) _layerChangedCb(layerName);
            var editor:Dynamic = EditorAccess.get();
            if (editor != null) editor.setActiveLayer(layerName);
        }
    }

    // ── Toolbar button handlers ──────────────────────────────────────────────

    function onAddClick(e:Event):Void {
        e.stopPropagation();
        var shadow = HTMLElement.shadow(this);

        // Toggle: close if already open
        if (_addMenu != null) {
            _addMenu.remove();
            _addMenu = null;
            return;
        }

        var menu = Browser.document.createElement("div");
        menu.className = "add-menu";
        menu.innerHTML =
            '<div class="add-menu-item" data-type="0">▦&nbsp; Tilemap Layer</div>' +
            '<div class="add-menu-item" data-type="1">⊞&nbsp; Entity Layer</div>' +
            '<div class="add-menu-item" data-type="2">📁&nbsp; Folder Layer</div>';
        shadow.appendChild(menu);
        _addMenu = menu;

        menu.addEventListener("click", (e2:Event) -> {
            var tgt:Element = cast e2.target;
            var item:Element = cast tgt.closest(".add-menu-item");
            if (item == null) return;
            var typeStr:String = untyped item.dataset.type;
            menu.remove();
            _addMenu = null;
            doAddLayer(Std.parseInt(typeStr));
        });

        // Close on any outside click
        var onOutside:Event->Void = null;
        onOutside = function(e2:Event) {
            js.Browser.window.removeEventListener("click", cast onOutside);
            if (_addMenu != null) { _addMenu.remove(); _addMenu = null; }
        };
        js.Browser.window.addEventListener("click", cast onOutside);
    }

    // Returns a unique auto-generated name for a layer of the given type.
    function uniqueDefaultName(type:Int):String {
        var editor:Dynamic = EditorAccess.get();
        var base = TYPE_LABELS[type] + " Layer";
        var n = 1;
        var name = base + " " + n;
        if (editor != null) {
            while (editor.getLayerInfo(name) != null) { n++; name = base + " " + n; }
        }
        return name;
    }

    // Creates the layer in the editor and syncs the tree.
    function commitLayer(name:String, type:Int, tilesetName:String = "", tileSize:Int = 64):Void {
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;
        var ok = false;
        switch (type) {
            case 0: ok = editor.createTilemapLayer(name, tilesetName, tileSize);
            case 1: ok = editor.createEntityLayer(name);
            case 2: ok = editor.createFolderLayer(name);
        }
        if (ok) {
            _selectedLayerName = name;
            refresh();
            var node = _tree.querySelector('.layer-node[data-layer="' + name + '"]');
            if (node != null) {
                node.classList.add("selected");
                editor.setActiveLayer(name);
            }
        }
    }

    function doAddLayer(type:Int):Void {
        var shadow = HTMLElement.shadow(this);
        switch (type) {
            case 0: showTilemapDialog(shadow);
            case 1: showEntityDialog(shadow);
            case 2: commitLayer(uniqueDefaultName(2), 2); // no dialog for folders
        }
    }

    function showEntityDialog(shadow:Element):Void {
        var input:InputElement = cast HTMLElement.find(shadow, "#dlg-entity-name");
        input.value = uniqueDefaultName(1);
        HTMLElement.find(shadow, "#dlg-entity").classList.add("visible");
        input.focus();
        input.select();
    }

    function showTilemapDialog(shadow:Element):Void {
        var editor:Dynamic = EditorAccess.get();
        var nameInput:InputElement  = cast HTMLElement.find(shadow, "#dlg-tilemap-name");
        var tilesetSel:SelectElement = cast HTMLElement.find(shadow, "#dlg-tilemap-tileset");
        var sizeInput:InputElement  = cast HTMLElement.find(shadow, "#dlg-tilemap-tilesize");

        nameInput.value = uniqueDefaultName(0);
        sizeInput.value = "64";

        // Repopulate tileset dropdown
        tilesetSel.innerHTML = "";
        var tsCount:Int = editor != null ? editor.getTilesetCount() : 0;
        for (i in 0...tsCount) {
            var ts:Dynamic = editor.getTilesetAt(i);
            if (ts == null) continue;
            var opt = Browser.document.createElement("option");
            opt.setAttribute("value", ts.name);
            opt.textContent = ts.name;
            tilesetSel.appendChild(opt);
        }
        if (tsCount == 0) {
            var opt = Browser.document.createElement("option");
            opt.setAttribute("value", "");
            opt.textContent = "(no tilesets)";
            tilesetSel.appendChild(opt);
        }

        HTMLElement.find(shadow, "#dlg-tilemap").classList.add("visible");
        nameInput.focus();
        nameInput.select();
    }

    function onEntityDialogOk():Void {
        var shadow = HTMLElement.shadow(this);
        var input:InputElement = cast HTMLElement.find(shadow, "#dlg-entity-name");
        var name = StringTools.trim(input.value);
        if (name == "") return;
        closeDialogs();
        commitLayer(name, 1);
    }

    function onTilemapDialogOk():Void {
        var shadow = HTMLElement.shadow(this);
        var nameInput:InputElement   = cast HTMLElement.find(shadow, "#dlg-tilemap-name");
        var tilesetSel:SelectElement = cast HTMLElement.find(shadow, "#dlg-tilemap-tileset");
        var sizeInput:InputElement   = cast HTMLElement.find(shadow, "#dlg-tilemap-tilesize");
        var name = StringTools.trim(nameInput.value);
        if (name == "") return;
        var tilesetName = tilesetSel.value;
        var tileSize = Std.parseInt(sizeInput.value);
        if (tileSize == null || tileSize <= 0) tileSize = 64;
        closeDialogs();
        commitLayer(name, 0, tilesetName, tileSize);
    }

    function closeDialogs():Void {
        var shadow = HTMLElement.shadow(this);
        HTMLElement.find(shadow, "#dlg-entity").classList.remove("visible");
        HTMLElement.find(shadow, "#dlg-tilemap").classList.remove("visible");
    }

    function onRemoveClick():Void {
        if (_selectedLayerName == null) return;
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;

        if (!js.Browser.window.confirm('Remove layer "' + _selectedLayerName + '"?')) return;

        if (editor.removeLayer(_selectedLayerName)) {
            _selectedLayerName = null;
            refresh();
        }
    }

    function onEditClick():Void {
        if (_selectedLayerName == null) return;
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;

        var newName:String = js.Browser.window.prompt("Rename layer:", _selectedLayerName);
        if (newName == null) return;
        newName = StringTools.trim(newName);
        if (newName == "" || newName == _selectedLayerName) return;

        if (editor.renameLayer(_selectedLayerName, newName)) {
            _selectedLayerName = newName;
            refresh();
            var node = _tree.querySelector('.layer-node[data-layer="' + newName + '"]');
            if (node != null) {
                node.classList.add("selected");
                editor.setActiveLayer(newName);
            }
        }
    }

    function onMoveUpClick():Void {
        if (_selectedLayerName == null) return;
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;
        if (editor.moveLayerUp(_selectedLayerName)) {
            refresh();
            var node = _tree.querySelector('.layer-node[data-layer="' + _selectedLayerName + '"]');
            if (node != null) node.classList.add("selected");
        }
    }

    function onMoveDownClick():Void {
        if (_selectedLayerName == null) return;
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;
        if (editor.moveLayerDown(_selectedLayerName)) {
            refresh();
            var node = _tree.querySelector('.layer-node[data-layer="' + _selectedLayerName + '"]');
            if (node != null) node.classList.add("selected");
        }
    }

    // ── Public API ───────────────────────────────────────────────────────────

    public function clearLayers():Void {
        if (_tree == null) return;
        var nodes = _tree.querySelectorAll(".layer-node");
        for (i in 0...nodes.length) untyped nodes[i].remove();
    }

    public function addLayer(name:String, type:Int):Void {
        if (_tree == null) return;
        var icon = ICONS[type >= 0 && type < ICONS.length ? type : 0];
        var node = Browser.document.createElement("div");
        node.className = "layer-node";
        untyped node.dataset.layer = name;
        node.innerHTML =
            '<span class="exp"></span>' +
            '<span class="icon">' + icon + '</span>' +
            '<span class="lbl">'  + name + '</span>';
        _tree.appendChild(node);
    }

    /** Force immediate rebuild of the layer tree from the current Editor state. */
    public function refresh():Void {
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;
        var count:Int = editor.getLayerCount();
        clearLayers();
        var sig = "";
        for (i in 0...count) {
            var info:Dynamic = editor.getLayerInfoAt(i);
            if (info == null) continue;
            addLayer(info.name, info.type);
            sig += info.name + ":" + info.type + ",";
        }
        _syncLayerSig = sig;

        // Restore visual selection
        if (_selectedLayerName != null) {
            var node = _tree.querySelector('.layer-node[data-layer="' + _selectedLayerName + '"]');
            if (node != null) node.classList.add("selected");
        }
    }

    public function setActiveLayerChangedCallback(cb:String->Void):Void {
        _layerChangedCb = cb;
    }

    /**
     * Populate the tree immediately from the current Editor state, then start a
     * 1-second polling interval that keeps it in sync (detects additions,
     * removals, and reordering).  Call once after Editor.init() succeeds.
     */
    public function startSync():Void {
        // Populate immediately — don't wait for the first poll tick.
        refresh();

        js.Browser.window.setInterval(function() {
            var editor:Dynamic = EditorAccess.get();
            if (editor == null) return;
            var count:Int = editor.getLayerCount();
            var sig = "";
            for (i in 0...count) {
                var info:Dynamic = editor.getLayerInfoAt(i);
                if (info == null) continue;
                sig += info.name + ":" + info.type + ",";
            }
            if (sig == _syncLayerSig) return;
            _syncLayerSig = sig;
            clearLayers();
            for (i in 0...count) {
                var info:Dynamic = editor.getLayerInfoAt(i);
                if (info == null) continue;
                addLayer(info.name, info.type);
            }
            // Restore selection if layer still exists
            if (_selectedLayerName != null) {
                var node = _tree.querySelector('.layer-node[data-layer="' + _selectedLayerName + '"]');
                if (node != null) node.classList.add("selected");
            }
        }, 1000);
    }
}

