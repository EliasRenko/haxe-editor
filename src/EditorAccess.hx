package;

/**
 * EditorAccess — single point of access for the global Editor object.
 *
 * The compiled editor DLL / JS module exposes a global `Editor` object on
 * `window`.  Components reach it through this helper instead of repeating
 * the inline existence check everywhere.
 *
 * Usage:
 *   var editor = EditorAccess.get();
 *   if (editor == null) return;
 *   editor.doSomething();
 */
class EditorAccess {
    /** Returns the global Editor object, or null if it is not yet available. */
    public static inline function get():Dynamic {
        return untyped js.Browser.window.Editor;
    }
}
