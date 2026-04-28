package components;

/**
 * HTMLElement — shared base class and static helper API for all editor Web Components.
 *
 * The @:native("HTMLElement") extern shim lets component classes write
 *   `class FooElement extends HTMLElement`
 * and have `super()` wire up correctly against the browser's native HTMLElement.
 *
 * The static helpers replace the old WebComponent utility class:
 *
 *   HTMLElement.define("my-tag", MyElementClass)
 *   var s  = HTMLElement.shadow(this)
 *   var el = HTMLElement.find(s, "#btn")
 *   HTMLElement.dispatch(this, "item-selected", { id: 42 })
 */
@:native("HTMLElement")
extern class HTMLElement extends js.html.Element {

    // ── Registration ──────────────────────────────────────────────────────────

    /**
     * Register a Haxe class as a Custom Element.
     * This is the only place in the codebase that uses js.Syntax.code.
     */
    public static inline function define(tag:String, impl:Class<Dynamic>):Void {
        var registry:Dynamic = (cast js.Browser.window : Dynamic).customElements;
        if (registry.get(tag) != null) return;
        var _CE = js.Syntax.code("class extends HTMLElement { constructor() { super(); } }");
        // Object.assign only copies enumerable properties; ES6 class methods are
        // non-enumerable, so we must use getOwnPropertyNames + defineProperty.
        var proto:Dynamic = (cast impl : Dynamic).prototype;
        for (name in js.lib.Object.getOwnPropertyNames(proto)) {
            if (name != "constructor")
                js.lib.Object.defineProperty(_CE.prototype, name,
                    cast js.lib.Object.getOwnPropertyDescriptor(proto, name));
        }
        registry.define(tag, _CE);
    }

    // ── Shadow DOM helpers ────────────────────────────────────────────────────

    /** Returns the open shadow root of `host`, creating it if absent. */
    public static inline function shadow(host:Dynamic):Dynamic {
        return untyped (host.shadowRoot != null ? host.shadowRoot : host.attachShadow({ mode: "open" }));
    }

    /** Shorthand for querySelector inside a shadow root (or any element). */
    public static inline function find(root:Dynamic, sel:String):Dynamic {
        return untyped root.querySelector(sel);
    }

    // ── Custom events ─────────────────────────────────────────────────────────

    /**
     * Dispatch a CustomEvent from `host`.
     * Bubbles and crosses shadow boundaries by default.
     */
    public static inline function dispatch(host:Dynamic, name:String, ?detail:Dynamic, bubbles:Bool = true):Void {
        var init:Dynamic = { bubbles: bubbles, composed: true, detail: detail };
        untyped host.dispatchEvent(new js.html.CustomEvent(name, init));
    }
}
