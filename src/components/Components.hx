package components;

/**
 * Components — registers all editor Web Components.
 *
 * Call Components.registerAll() once from EditorWeb.main() (or the HTML
 * <script> block) before the DOM is used.
 *
 * Each component is a standard Custom Element and can be placed directly
 * in editor.html as a tag:
 *
 *   <editor-property-grid id="prop-grid"></editor-property-grid>
 *   <editor-hierarchy     id="hierarchy"></editor-hierarchy>
 *   <editor-console       id="console-panel"></editor-console>
 */
@:expose("Components")
class Components {

    public static function registerAll():Void {
        PropertyGrid.register();
        HierarchyPanel.register();
        ConsolePanel.register();
        TextureBrowser.register();
        TextureBrowserDialog.register();
        EntityManagerDialog.register();
    }
}
