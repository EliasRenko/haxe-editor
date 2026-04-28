package components;

import js.Browser;

@:expose("ConsolePanel")
class ConsolePanel {
    public static inline var TAG = "editor-console";

    public static function register():Void {
        HTMLElement.define(TAG, ConsolePanelElement);
    }
}

@:nativeGen
@:keep
class ConsolePanelElement extends HTMLElement {

    // ── Instance state ────────────────────────────────────────────────────────
    var _out:Dynamic;
    var _origLog:Dynamic;
    var _origWarn:Dynamic;
    var _origErr:Dynamic;

    public function new() {
        super();
        _out      = null;
        _origLog  = null;
        _origWarn = null;
        _origErr  = null;
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    /** Called when the element is inserted into the document. */
    public function connectedCallback():Void {
        var s = HTMLElement.shadow(this);
        if (_out != null) return;
        s.innerHTML = haxe.Resource.getString("ConsolePanel");
        _out = HTMLElement.find(s, "#out");
        HTMLElement.find(s, "#btn-clear").addEventListener("click", (_) -> clear());
        HTMLElement.find(s, "#btn-copy").addEventListener("click", (_) -> {
            if (_out != null) {
                // clipboard.writeText returns a Promise; suppress rejection silently
                var p:Dynamic = untyped js.Browser.navigator.clipboard.writeText(_out.innerText);
                js.Syntax.field(p, "catch")(function() {});
            }
        });
    }

    /** Called when the element is removed from the document. */
    public function disconnectedCallback():Void {
        unhookConsole();
    }

    /**
     * Called when an observed attribute changes value.
     * Add attribute names to the observedAttributes list (via HTMLElement.define
     * or a static getter) to activate this callback.
     */
    public function attributeChangedCallback(name:String, oldVal:String, newVal:String):Void {
        // e.g.  if (name == "theme") _applyTheme(newVal);
    }

    /** Called when the element is adopted into a new document (rare). */
    public function adoptedCallback():Void {}

    // ── Private helpers ───────────────────────────────────────────────────────

    function _append(text:String, cls:String):Void {
        if (_out == null) return;
        var div = Browser.document.createElement("div");
        div.className = "line " + cls;
        div.textContent = text;
        _out.appendChild(div);
        _out.scrollTop = _out.scrollHeight;
    }

    // ── Public API ────────────────────────────────────────────────────────────

    public function log(msg:String):Void   { _append(msg, "info");  }
    public function warn(msg:String):Void  { _append(msg, "warn");  }
    public function error(msg:String):Void { _append(msg, "error"); }

    public function clear():Void {
        if (_out != null) _out.innerHTML = "";
        HTMLElement.dispatch(this, "console-cleared");
    }

    /**
     * Patches window.console so all output is mirrored into this panel.
     * Stores the original methods on the instance so unhookConsole() can
     * restore them cleanly.  Safe to call multiple times (no-op if already
     * hooked).
     *
     * js.Syntax.code is kept here because variadic spread wrappers have no
     * direct typed equivalent in Haxe.
     */
    public function hookConsole():Void {
        if (_origLog != null) return; // already hooked
        var self = this;
        js.Syntax.code("
            {0}._origLog  = console.log.bind(console);
            {0}._origWarn = console.warn.bind(console);
            {0}._origErr  = console.error.bind(console);
            console.log   = (...args) => { {0}._origLog(...args);  {0}.log(  args.join(' ')); };
            console.warn  = (...args) => { {0}._origWarn(...args); {0}.warn( args.join(' ')); };
            console.error = (...args) => { {0}._origErr(...args);  {0}.error(args.join(' ')); };
        ", self);
    }

    /**
     * Restores the original window.console methods.
     * Called automatically from disconnectedCallback.
     */
    public function unhookConsole():Void {
        if (_origLog == null) return;
        js.Syntax.code("
            console.log   = {0}._origLog;
            console.warn  = {0}._origWarn;
            console.error = {0}._origErr;
        ", this);
        _origLog  = null;
        _origWarn = null;
        _origErr  = null;
    }
}
