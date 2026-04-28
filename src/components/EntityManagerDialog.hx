package components;

import js.Browser;
import js.html.Element;
import js.html.Event;
import js.html.KeyboardEvent;
import js.html.InputElement;
import js.html.SelectElement;
import js.html.CanvasElement;
import EditorAccess;

/**
 * EntityManagerDialog β€” Web Component  <editor-entity-manager-dialog>
 *
 * A modal dialog for creating, editing and deleting entity definitions.
 * Mirrors the layout of the native Entity Manager window:
 *   Left   β€” entity list + New / Delete buttons
 *   Right  β€” editor form (Basic / Appearance / Behaviour / Custom Properties)
 *
 * Public API:
 *   el.open()    β€” show dialog, refresh list
 *   el.close()   β€” hide dialog
 */
@:expose("EntityManagerDialog")
class EntityManagerDialog {

    public static inline var TAG = "editor-entity-manager-dialog";

    public static function register():Void {
        HTMLElement.define(TAG, EntityManagerDialogElement);
    }
}

@:nativeGen
@:keep
class EntityManagerDialogElement extends HTMLElement {

    // β”€β”€ Template β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€
    // β”€β”€ Template β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€
    // (HTML lives in src/components/templates/EntityManagerDialog.html)

    // β”€β”€ Instance state β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€
    var _overlay:Element;
    var _entityList:Element;
    var _inpName:InputElement;
    var _selTilemap:SelectElement;
    var _inpWidth:InputElement;
    var _inpHeight:InputElement;
    var _regionInfo:Element;
    var _pivotGrid:Element;
    var _inpPivotX:InputElement;
    var _inpPivotY:InputElement;
    var _propsBody:Element;
    var _previewCanvas:CanvasElement;
    var _previewWrap:Element;

    var _selectedName:String;        // entity currently selected in the list
    var _isNew:Bool;                 // true when editing a not-yet-saved entity
    var _regionX:Int;  var _regionY:Int;
    var _regionW:Int;  var _regionH:Int;
    var _pivotX:Float; var _pivotY:Float;

    var _onKeyDown:KeyboardEvent->Void;
    var _onMouseMove:Dynamic;
    var _onMouseUp:Dynamic;

    // pivot picking state
    var _pickingPivot:Bool;

    public function new() {
        super();
        _overlay       = null;
        _selectedName  = "";
        _isNew         = false;
        _regionX = 0; _regionY = 0; _regionW = 32; _regionH = 32;
        _pivotX  = 0.5; _pivotY = 0.5;
        _pickingPivot  = false;
        _onKeyDown     = null;
        _onMouseMove   = null;
        _onMouseUp     = null;
    }

    // β”€β”€ Lifecycle β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    public function connectedCallback():Void {
        var shadow = HTMLElement.shadow(this);
        if (_overlay != null) return;
        shadow.innerHTML = haxe.Resource.getString("EntityManagerDialog");

        _overlay      = cast HTMLElement.find(shadow, "#overlay");
        _entityList   = cast HTMLElement.find(shadow, "#entity-list");
        _inpName      = cast HTMLElement.find(shadow, "#inp-name");
        _selTilemap   = cast HTMLElement.find(shadow, "#sel-tilemap");
        _inpWidth     = cast HTMLElement.find(shadow, "#inp-width");
        _inpHeight    = cast HTMLElement.find(shadow, "#inp-height");
        _regionInfo   = cast HTMLElement.find(shadow, "#region-info");
        _pivotGrid    = cast HTMLElement.find(shadow, "#pivot-grid");
        _inpPivotX    = cast HTMLElement.find(shadow, "#inp-pivot-x");
        _inpPivotY    = cast HTMLElement.find(shadow, "#inp-pivot-y");
        _propsBody    = cast HTMLElement.find(shadow, "#props-body");
        _previewCanvas = cast HTMLElement.find(shadow, "#preview-canvas");
        _previewWrap  = cast HTMLElement.find(shadow, "#preview-wrap");

        // Window buttons
        HTMLElement.find(shadow, "#close-btn").addEventListener("click", (_:Event) -> close());
        HTMLElement.find(shadow, "#btn-close-footer").addEventListener("click", (_:Event) -> close());
        HTMLElement.find(shadow, "#btn-save").addEventListener("click", (_:Event) -> _save());
        HTMLElement.find(shadow, "#btn-new").addEventListener("click", (_:Event) -> _newEntity());
        HTMLElement.find(shadow, "#btn-delete").addEventListener("click", (_:Event) -> _deleteEntity());
        HTMLElement.find(shadow, "#btn-region").addEventListener("click", (_:Event) -> _openRegionPicker());
        HTMLElement.find(shadow, "#btn-add-prop").addEventListener("click", (_:Event) -> _addProp());
        HTMLElement.find(shadow, "#btn-remove-prop").addEventListener("click", (_:Event) -> _removeSelectedProp());

        // Entity list click
        _entityList.addEventListener("click", (e:Event) -> _onListClick(e));

        // Tilemap change β€” reload preview
        _selTilemap.addEventListener("change", (_:Event) -> { _resetRegion(); _redrawPreview(); });

        // Width/height change β€” sync region default + redraw
        _inpWidth.addEventListener("change", (_:Event) -> { _syncRegionToSize(); _redrawPreview(); });
        _inpHeight.addEventListener("change", (_:Event) -> { _syncRegionToSize(); _redrawPreview(); });

        // Pivot grid
        _pivotGrid.addEventListener("click", (e:Event) -> _onPivotGridClick(e));

        // Pivot numeric inputs β€” update grid highlight + redraw
        _inpPivotX.addEventListener("change", (_:Event) -> { _pivotX = _parseFloat(_inpPivotX.value, 0.5); _updatePivotGrid(); _redrawPreview(); });
        _inpPivotY.addEventListener("change", (_:Event) -> { _pivotY = _parseFloat(_inpPivotY.value, 0.5); _updatePivotGrid(); _redrawPreview(); });

        // Click on preview to set pivot
        _previewWrap.addEventListener("click", (e:Dynamic) -> _onPreviewClick(e));

        // Backdrop closes
        _overlay.addEventListener("click", (e:Event) -> { if (e.target == _overlay) close(); });

        // Drag title bar
        _initDrag(shadow);

        _onKeyDown = (e:KeyboardEvent) -> { if (e.key == "Escape") close(); };
    }

    public function disconnectedCallback():Void {
        close(); // removes keydown listener and hides overlay
    }

    public function attributeChangedCallback(name:String, oldVal:String, newVal:String):Void {}

    public function adoptedCallback():Void {}

    // β”€β”€ Drag support β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    function _initDrag(shadow:Dynamic):Void {
        var header:Dynamic = shadow.getElementById("header");
        var win:Dynamic    = shadow.getElementById("window");
        var startX = 0; var startY = 0;
        var origX  = 0; var origY  = 0;
        var dragging = false;

        header.addEventListener("mousedown", (e:Dynamic) -> {
            if (e.target != header && e.target.className != "title") return;
            dragging = true;
            startX = e.clientX; startY = e.clientY;
            var rect = win.getBoundingClientRect();
            origX = rect.left; origY = rect.top;
            win.style.position = "absolute";
            win.style.left = origX + "px";
            win.style.top  = origY + "px";
            win.style.margin = "0";
            Browser.document.addEventListener("mousemove", _onMouseMove);
            Browser.document.addEventListener("mouseup",   _onMouseUp);
        });

        _onMouseMove = (e:Dynamic) -> {
            if (!dragging) return;
            win.style.left = (origX + e.clientX - startX) + "px";
            win.style.top  = (origY + e.clientY - startY) + "px";
        };
        _onMouseUp = (_:Dynamic) -> {
            dragging = false;
            Browser.document.removeEventListener("mousemove", _onMouseMove);
            Browser.document.removeEventListener("mouseup",   _onMouseUp);
        };
    }

    // β”€β”€ Entity list helpers β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    function _rebuildList():Void {
        _entityList.innerHTML = "";
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;
        var count:Int = editor.getEntityDefCount();
        if (count == 0) {
            _entityList.innerHTML = '<div class="list-empty">No entities</div>';
            return;
        }
        for (i in 0...count) {
            var def:Dynamic = editor.getEntityDefAt(i);
            if (def == null) continue;
            var item = Browser.document.createElement("div");
            item.className = "list-item" + (def.name == _selectedName ? " selected" : "");
            untyped item.dataset.name = def.name;
            var label = def.name + " (" + def.width + "x" + def.height + "px)";
            if (def.tilesetName != null && def.tilesetName != "") label += " [" + def.tilesetName + "]";
            item.textContent = label;
            _entityList.appendChild(item);
        }
    }

    function _onListClick(e:Event):Void {
        var target:Element = cast e.target;
        var item:Element   = cast target.closest(".list-item");
        if (item == null) return;
        var name:String = untyped item.dataset.name;
        _selectEntity(name);
    }

    function _selectEntity(name:String):Void {
        _selectedName = name;
        _isNew = false;
        // Highlight
        var items = _entityList.querySelectorAll(".list-item");
        for (i in 0...items.length) {
            var el:Element = cast items[i];
            el.classList.toggle("selected", (untyped el.dataset.name) == name);
        }
        // Populate form
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;
        var def:Dynamic = editor.getEntityDef(name);
        if (def == null) return;
        _inpName.value           = def.name;
        _inpWidth.value          = Std.string(def.width);
        _inpHeight.value         = Std.string(def.height);
        _regionX = def.regionX; _regionY = def.regionY;
        _regionW = def.regionWidth; _regionH = def.regionHeight;
        _pivotX  = def.pivotX;  _pivotY  = def.pivotY;
        _inpPivotX.value = _fmtPivot(_pivotX);
        _inpPivotY.value = _fmtPivot(_pivotY);
        _updateRegionInfo();
        _updatePivotGrid();
        _rebuildTilemapSelect(def.tilesetName);
        _redrawPreview();
    }

    // β”€β”€ Tilemap dropdown β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    function _rebuildTilemapSelect(currentTileset:String):Void {
        _selTilemap.innerHTML = "";
        var none:Dynamic = Browser.document.createElement("option");
        none.value = "";
        none.textContent = "(No Texture)";
        _selTilemap.appendChild(none);

        var editor:Dynamic = EditorAccess.get();
        if (editor != null) {
            var count:Int = editor.getTilesetCount();
            for (i in 0...count) {
                var ts:Dynamic = editor.getTilesetAt(i);
                if (ts == null) continue;
                var opt:Dynamic = Browser.document.createElement("option");
                opt.value = ts.name;
                opt.textContent = ts.name;
                _selTilemap.appendChild(opt);
            }
        }
        _selTilemap.value = (currentTileset != null ? currentTileset : "");
    }

    // β”€β”€ Region helpers β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    function _resetRegion():Void {
        _regionX = 0; _regionY = 0;
        var w = _parseInt(_inpWidth.value, 32);
        var h = _parseInt(_inpHeight.value, 32);
        _regionW = w; _regionH = h;
        _updateRegionInfo();
    }

    function _syncRegionToSize():Void {
        _regionW = _parseInt(_inpWidth.value, 32);
        _regionH = _parseInt(_inpHeight.value, 32);
        _updateRegionInfo();
    }

    function _updateRegionInfo():Void {
        if (_regionW == 0 && _regionH == 0) {
            _regionInfo.textContent = "No region selected";
        } else {
            _regionInfo.textContent = _regionX + ", " + _regionY + "  " + _regionW + "Γ—" + _regionH;
        }
    }

    function _openRegionPicker():Void {
        // For now, simply open an inline prompt β€” a full tile-picker overlay
        // can be added as a follow-up component.
        var ts:String = _selTilemap.value;
        if (ts == "") { _regionInfo.textContent = "No texture selected"; return; }
        var xStr  = js.Browser.window.prompt("Region X (pixels):",   Std.string(_regionX));  if (xStr == null) return;
        var yStr  = js.Browser.window.prompt("Region Y (pixels):",   Std.string(_regionY));  if (yStr == null) return;
        var wStr  = js.Browser.window.prompt("Region Width (pixels):", Std.string(_regionW)); if (wStr == null) return;
        var hStr  = js.Browser.window.prompt("Region Height (pixels):",Std.string(_regionH)); if (hStr == null) return;
        _regionX = _parseInt(xStr, _regionX);
        _regionY = _parseInt(yStr, _regionY);
        _regionW = _parseInt(wStr, _regionW);
        _regionH = _parseInt(hStr, _regionH);
        _updateRegionInfo();
        _redrawPreview();
    }

    // β”€β”€ Pivot helpers β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    function _onPivotGridClick(e:Event):Void {
        var target:Element = cast e.target;
        var cell:Element   = cast target.closest(".pivot-cell");
        if (cell == null) return;
        _pivotX = _parseFloat(untyped cell.dataset.px, 0.5);
        _pivotY = _parseFloat(untyped cell.dataset.py, 0.5);
        _inpPivotX.value = _fmtPivot(_pivotX);
        _inpPivotY.value = _fmtPivot(_pivotY);
        _updatePivotGrid();
        _redrawPreview();
    }

    function _updatePivotGrid():Void {
        var cells = _pivotGrid.querySelectorAll(".pivot-cell");
        for (i in 0...cells.length) {
            var cell:Element = cast cells[i];
            var cx = _parseFloat(untyped cell.dataset.px, -1);
            var cy = _parseFloat(untyped cell.dataset.py, -1);
            cell.classList.toggle("active", Math.abs(cx - _pivotX) < 0.01 && Math.abs(cy - _pivotY) < 0.01);
        }
    }

    function _onPreviewClick(e:Dynamic):Void {
        var rect = _previewWrap.getBoundingClientRect();
        var nx = (e.clientX - rect.left) / rect.width;
        var ny = (e.clientY - rect.top)  / rect.height;
        _pivotX = Math.max(0, Math.min(1, nx));
        _pivotY = Math.max(0, Math.min(1, ny));
        _inpPivotX.value = _fmtPivot(_pivotX);
        _inpPivotY.value = _fmtPivot(_pivotY);
        _updatePivotGrid();
        _redrawPreview();
    }

    // β”€β”€ Canvas preview β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    function _redrawPreview():Void {
        var cw:Int = _previewWrap.clientWidth;
        var ch:Int = _previewWrap.clientHeight;
        if (cw <= 0) cw = 180;
        if (ch <= 0) ch = 180;
        _previewCanvas.width  = cw;
        _previewCanvas.height = ch;

        var ctx:Dynamic = _previewCanvas.getContext("2d");
        ctx.clearRect(0, 0, cw, ch);

        var ts:String = _selTilemap.value;
        var texLoaded = false;

        if (ts != null && ts != "") {
            var editor:Dynamic = EditorAccess.get();
            if (editor != null) {
                var dataUrl:String = editor.getTextureDataUrl(ts);
                if (dataUrl != null) {
                    // Draw the region sub-rect scaled to fit the preview
                    var img:Dynamic = cast Browser.document.createElement("img");
                    var self        = this;
                    img.onload = (e:Dynamic) -> {
                        var rw = _regionW > 0 ? _regionW : _parseInt(_inpWidth.value, 32);
                        var rh = _regionH > 0 ? _regionH : _parseInt(_inpHeight.value, 32);
                        // fit region into preview keeping aspect ratio
                        var scale = Math.min(cw / rw, ch / rh) * 0.85;
                        var dw = Std.int(rw * scale);
                        var dh = Std.int(rh * scale);
                        var dx = Std.int((cw - dw) / 2);
                        var dy = Std.int((ch - dh) / 2);

                        // Draw region from texture
                        ctx.imageSmoothingEnabled = false;
                        ctx.drawImage(img, _regionX, _regionY, rw, rh, dx, dy, dw, dh);

                        // Border around region
                        ctx.strokeStyle = "rgba(255,255,255,0.4)";
                        ctx.lineWidth   = 1;
                        ctx.strokeRect(dx + 0.5, dy + 0.5, dw - 1, dh - 1);

                        // Pivot crosshair
                        self._drawPivot(ctx, dx, dy, dw, dh, cw, ch);
                    };
                    img.src = dataUrl;
                    texLoaded = true;
                }
            }
        }

        if (!texLoaded) {
            // No texture β€” draw a plain region rect and pivot
            var rw = _parseInt(_inpWidth.value, 32);
            var rh = _parseInt(_inpHeight.value, 32);
            var scale = Math.min(cw / rw, ch / rh) * 0.85;
            var dw = Std.int(rw * scale); var dh = Std.int(rh * scale);
            var dx = Std.int((cw - dw) / 2); var dy = Std.int((ch - dh) / 2);

            ctx.strokeStyle = "rgba(255,255,255,0.3)";
            ctx.lineWidth   = 1;
            ctx.strokeRect(dx + 0.5, dy + 0.5, dw - 1, dh - 1);

            _drawPivot(ctx, dx, dy, dw, dh, cw, ch);
        }
    }

    function _drawPivot(ctx:Dynamic, dx:Int, dy:Int, dw:Int, dh:Int, cw:Int, ch:Int):Void {
        var px = dx + Std.int(_pivotX * dw);
        var py = dy + Std.int(_pivotY * dh);

        var R = 6;
        // Crosshair lines
        ctx.strokeStyle = "rgba(255, 80, 80, 0.9)";
        ctx.lineWidth   = 1.5;
        ctx.beginPath();
        ctx.moveTo(px - R, py); ctx.lineTo(px + R, py);
        ctx.moveTo(px, py - R); ctx.lineTo(px, py + R);
        ctx.stroke();
        // Circle
        ctx.beginPath();
        ctx.arc(px, py, 3, 0, Math.PI * 2);
        ctx.fillStyle = "rgba(255, 80, 80, 0.9)";
        ctx.fill();
    }

    // β”€β”€ Custom Properties β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    function _addProp():Void {
        var tr = Browser.document.createElement("tr");
        tr.innerHTML = '
            <td><input type="text" placeholder="name"></td>
            <td>
                <select>
                    <option>String</option>
                    <option>Int</option>
                    <option>Float</option>
                    <option>Bool</option>
                </select>
            </td>
            <td><input type="text" placeholder="default"></td>
        ';
        _propsBody.appendChild(tr);
        // Focus name field
        untyped tr.querySelector("input").focus();
    }

    function _removeSelectedProp():Void {
        // Remove the last row for simplicity (selection state not tracked per-row)
        var rows = _propsBody.querySelectorAll("tr");
        if (rows.length > 0) _propsBody.removeChild(rows[rows.length - 1]);
    }

    // β”€β”€ New / Delete β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    function _newEntity():Void {
        _selectedName = "";
        _isNew = true;
        // Clear all fields
        _inpName.value = "";
        _inpWidth.value = "32";
        _inpHeight.value = "32";
        _regionX = 0; _regionY = 0; _regionW = 32; _regionH = 32;
        _pivotX = 0.5; _pivotY = 0.5;
        _inpPivotX.value = "0.50"; _inpPivotY.value = "0.50";
        _propsBody.innerHTML = "";
        _updateRegionInfo();
        _updatePivotGrid();
        _rebuildTilemapSelect("");
        _redrawPreview();
        // Deselect list
        var items = _entityList.querySelectorAll(".list-item");
        for (i in 0...items.length) (cast items[i] : Element).classList.remove("selected");
        _inpName.focus();
    }

    function _deleteEntity():Void {
        if (_selectedName == "") return;
        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;
        editor.deleteEntityDef(_selectedName);
        _selectedName = "";
        _isNew = true;
        _rebuildList();
        _newEntity();
    }

    // β”€β”€ Save β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    function _save():Void {
        var name    = StringTools.trim(_inpName.value);
        if (name == "") { js.Browser.window.alert("Entity name is required."); return; }
        var w       = _parseInt(_inpWidth.value,  32);
        var h       = _parseInt(_inpHeight.value, 32);
        var ts:String = _selTilemap.value;
        var data:Dynamic = {
            width: w, height: h,
            tilesetName: ts,
            regionX: _regionX, regionY: _regionY,
            regionWidth: _regionW, regionHeight: _regionH,
            pivotX: _pivotX, pivotY: _pivotY
        };

        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;

        if (_isNew || _selectedName == "" || name != _selectedName) {
            // New entity or rename: delete old if rename, create new
            if (_selectedName != "" && name != _selectedName) {
                editor.deleteEntityDef(_selectedName);
            }
            editor.createEntityDef(name, data);
        } else {
            editor.editEntityDef(name, data);
        }

        _selectedName = name;
        _isNew = false;
        _rebuildList();
        _selectEntity(name);
    }

    // β”€β”€ Public API β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    public function open():Void {
        if (_overlay == null) return;
        _overlay.classList.remove("hidden");
        _rebuildList();
        if (_selectedName != "") {
            _selectEntity(_selectedName);
        } else {
            _rebuildTilemapSelect("");
            _redrawPreview();
        }
        Browser.document.addEventListener("keydown", cast _onKeyDown);
    }

    public function close():Void {
        if (_overlay == null) return;
        _overlay.classList.add("hidden");
        Browser.document.removeEventListener("keydown", cast _onKeyDown);
    }

    // β”€β”€ Utilities β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€β”€

    static function _parseInt(s:String, def:Int):Int {
        var v = Std.parseInt(s);
        return (v == null || Math.isNaN(v)) ? def : v;
    }

    static function _parseFloat(s:String, def:Float):Float {
        var v = Std.parseFloat(s);
        return (v == null || Math.isNaN(v)) ? def : v;
    }

    static function _fmtPivot(v:Float):String {
        return Std.string(Math.round(v * 100) / 100);
    }
}
