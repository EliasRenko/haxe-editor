package components;

import js.Browser;
import js.html.Element;
import js.html.Event;
import js.html.KeyboardEvent;

/**
 * TextureBrowserDialog — Web Component  <editor-texture-browser-dialog>
 *
 * A self-contained modal dialog that wraps the <editor-texture-browser>
 * component in a titled overlay window.
 *
 * Usage in HTML:
 *   <editor-texture-browser-dialog id="dlg-textures"></editor-texture-browser-dialog>
 *
 * Public API:
 *   el.open()    — show the dialog and refresh the texture list
 *   el.close()   — hide the dialog
 */
@:expose("TextureBrowserDialog")
class TextureBrowserDialog {

    public static inline var TAG = "editor-texture-browser-dialog";

    public static function register():Void {
        HTMLElement.define(TAG, TextureBrowserDialogElement);
    }
}

@:nativeGen
@:keep
class TextureBrowserDialogElement extends HTMLElement {

    // ── Template ─────────────────────────────────────────────────────────────
    // (HTML lives in src/components/templates/TextureBrowserDialog.html)

    // ── Instance state ────────────────────────────────────────────────────────
    var _overlay:Element;
    var _browser:Dynamic;       // editor-texture-browser element
    var _onKeyDown:KeyboardEvent->Void;

    public function new() {
        super();
        _overlay   = null;
        _browser   = null;
        _onKeyDown = null;
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    public function connectedCallback():Void {
        var shadow = HTMLElement.shadow(this);
        if (_overlay != null) return;
        shadow.innerHTML = haxe.Resource.getString("TextureBrowserDialog");

        _overlay = cast HTMLElement.find(shadow, "#overlay");
        _browser = HTMLElement.find(shadow, "#browser");

        // Close button
        HTMLElement.find(shadow, "#close-btn").addEventListener("click", (_:Event) -> close());

        // Click on backdrop closes dialog
        _overlay.addEventListener("click", (e:Event) -> {
            if (e.target == _overlay) close();
        });

        // Drag to move window
        _initDrag(shadow);

        // Escape key
        _onKeyDown = (e:KeyboardEvent) -> {
            if (e.key == "Escape") close();
        };
    }

    public function disconnectedCallback():Void {
        close(); // removes keydown listener and hides overlay
    }

    public function attributeChangedCallback(name:String, oldVal:String, newVal:String):Void {}

    public function adoptedCallback():Void {}

    // ── Drag support ──────────────────────────────────────────────────────────

    function _initDrag(shadow:Dynamic):Void {
        var header:Dynamic = shadow.getElementById("header");
        var win:Dynamic    = shadow.getElementById("window");
        var startX = 0;  var startY = 0;
        var origX  = 0;  var origY  = 0;
        var dragging = false;

        header.addEventListener("mousedown", (e:Dynamic) -> {
            if (e.target != header && e.target.className != "title") return;
            dragging = true;
            startX = e.clientX;
            startY = e.clientY;
            var rect = win.getBoundingClientRect();
            origX = rect.left;
            origY = rect.top;
            // Switch from flex-center to absolute positioning
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

    // Stored as instance fields so removeEventListener works
    var _onMouseMove:Dynamic;
    var _onMouseUp:Dynamic;

    // ── Public API ────────────────────────────────────────────────────────────

    public function open():Void {
        if (_overlay == null) return;
        _overlay.classList.remove("hidden");
        if (_browser != null && untyped _browser.refresh != null)
            untyped _browser.refresh();
        Browser.document.addEventListener("keydown", cast _onKeyDown);
    }

    public function close():Void {
        if (_overlay == null) return;
        _overlay.classList.add("hidden");
        Browser.document.removeEventListener("keydown", cast _onKeyDown);
    }
}
