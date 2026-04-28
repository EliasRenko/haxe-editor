package components;

import js.Browser;
import js.html.Element;
import js.html.Event;

/**
 * TextureBrowser — Web Component  <editor-texture-browser>
 *
 * Usage in HTML:
 *   <editor-texture-browser id="texture-browser"></editor-texture-browser>
 *
 * Public API:
 *   el.refresh()   — reload the texture list from Editor
 */
@:expose("TextureBrowser")
class TextureBrowser {

    public static inline var TAG = "editor-texture-browser";

    public static function register():Void {
        HTMLElement.define(TAG, TextureBrowserElement);
    }
}

@:nativeGen
@:keep
class TextureBrowserElement extends HTMLElement {

    // ── Template ─────────────────────────────────────────────────────────────
    // (HTML lives in src/components/templates/TextureBrowser.html)

    // ── Instance state ────────────────────────────────────────────────────────
    var _list:Element;
    var _canvasWrap:Element;
    var _placeholder:Element;
    var _search:js.html.InputElement;
    var _infoName:Element;
    var _infoPath:Element;
    var _infoSize:Element;
    var _infoFmt:Element;
    var _allItems:Array<{name:String, texturePath:String}>;

    public function new() {
        super();
        _list       = null;
        _canvasWrap = null;
        _placeholder = null;
        _search     = null;
        _infoName   = null;
        _infoPath   = null;
        _infoSize   = null;
        _infoFmt    = null;
        _allItems   = [];
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    public function connectedCallback():Void {
        var shadow = HTMLElement.shadow(this);
        if (_list != null) return;
        shadow.innerHTML = haxe.Resource.getString("TextureBrowser");
        _list        = cast HTMLElement.find(shadow, "#list");
        _canvasWrap  = cast HTMLElement.find(shadow, "#canvas-wrap");
        _placeholder = cast HTMLElement.find(shadow, "#placeholder");
        _search      = cast HTMLElement.find(shadow, "#search");
        _infoName    = cast HTMLElement.find(shadow, "#info-name");
        _infoPath    = cast HTMLElement.find(shadow, "#info-path");
        _infoSize    = cast HTMLElement.find(shadow, "#info-size");
        _infoFmt     = cast HTMLElement.find(shadow, "#info-fmt");

        _list.addEventListener("click", (e:Event) -> onListClick(e));
        _search.addEventListener("input", (_:Event) -> filterList());
    }

    public function disconnectedCallback():Void {}

    public function attributeChangedCallback(name:String, oldVal:String, newVal:String):Void {}

    public function adoptedCallback():Void {}

    // ── Private helpers ───────────────────────────────────────────────────────

    function onListClick(e:Event):Void {
        var target:Element = cast e.target;
        var item:Element   = cast target.closest(".list-item");
        if (item == null) return;
        var name:String = untyped item.dataset.name;
        selectTexture(name);
    }

    function selectTexture(name:String):Void {
        // Highlight selected row
        var items = _list.querySelectorAll(".list-item");
        for (i in 0...items.length) {
            var el:Element = cast items[i];
            el.classList.toggle("selected", (untyped el.dataset.name) == name);
        }

        var editor:Dynamic = EditorAccess.get();
        if (editor == null) return;

        // Populate info panel
        var info:Dynamic = editor.getTextureInfo(name);
        if (info != null) {
            _infoName.textContent = info.name;
            _infoPath.textContent = info.texturePath;
            _infoSize.textContent = info.width > 0 ? (info.width + " × " + info.height) : "—";
            var bpp:Int = info.bpp;
            _infoFmt.textContent = switch (bpp) {
                case 1: "Grayscale (1 BPP)";
                case 3: "RGB (3 BPP)";
                case 4: "RGBA (4 BPP)";
                default: bpp + " BPP";
            };
        }

        // Load and display the texture
        var dataUrl:String = editor.getTextureDataUrl(name);
        _setPreview(dataUrl);
    }

    function _setPreview(dataUrl:String):Void {
        // Remove old image / placeholder from canvas-wrap (keep checkerboard)
        var toRemove:Array<Dynamic> = [];
        var children = _canvasWrap.childNodes;
        for (i in 0...children.length) {
            var child:Dynamic = children[i];
            var cls:String = (child.className != null) ? child.className : "";
            if (cls != "checkerboard") toRemove.push(child);
        }
        for (child in toRemove) _canvasWrap.removeChild(child);

        if (dataUrl != null && dataUrl != "") {
            var wrap = Browser.document.createElement("div");
            wrap.className = "canvas-img-wrap";
            var img = Browser.document.createElement("img");
            untyped img.src = dataUrl;
            wrap.appendChild(img);
            _canvasWrap.appendChild(wrap);
        } else {
            var span = Browser.document.createElement("span");
            span.className = "placeholder";
            span.textContent = "Texture not available";
            _canvasWrap.appendChild(span);
        }
    }

    function filterList():Void {
        var filter:String = _search.value.toLowerCase();
        var items = _list.querySelectorAll(".list-item");
        for (i in 0...items.length) {
            var el:Element = cast items[i];
            var name:String = ((untyped el.dataset.name) : String).toLowerCase();
            untyped el.style.display = (filter == "" || name.indexOf(filter) >= 0) ? "" : "none";
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    public function refresh():Void {
        if (_list == null) return;

        // Reset state
        _list.innerHTML = "";
        _allItems       = [];
        _search.value   = "";
        _infoName.textContent = "—";
        _infoPath.textContent = "—";
        _infoSize.textContent = "—";
        _infoFmt.textContent  = "—";

        // Clear preview (keep checkerboard)
        var toRemove:Array<Dynamic> = [];
        var children = _canvasWrap.childNodes;
        for (i in 0...children.length) {
            var child:Dynamic = children[i];
            var cls:String = (child.className != null) ? child.className : "";
            if (cls != "checkerboard") toRemove.push(child);
        }
        for (child in toRemove) _canvasWrap.removeChild(child);
        var span = Browser.document.createElement("span");
        span.className = "placeholder";
        span.textContent = "Select a texture";
        _canvasWrap.appendChild(span);

        var editor:Dynamic = EditorAccess.get();
        if (editor == null) {
            _list.innerHTML = '<div class="list-empty">Editor not initialised</div>';
            return;
        }

        var count:Int = editor.getTilesetCount();
        if (count == 0) {
            _list.innerHTML = '<div class="list-empty">No textures loaded</div>';
            return;
        }

        for (i in 0...count) {
            var ts:Dynamic = editor.getTilesetAt(i);
            if (ts == null) continue;
            var name:String  = ts.name;
            var path:String  = ts.texturePath;
            _allItems.push({ name: name, texturePath: path });

            var item = Browser.document.createElement("div");
            item.className = "list-item";
            untyped item.dataset.name = name;
            item.textContent = name;
            _list.appendChild(item);
        }
    }
}
