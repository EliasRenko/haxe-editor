package;

import manager.EntityManager;
import manager.TilesetManager;
import states.EditorState;

/**
 * Standalone entry point for the native editor application.
 * Creates App + EditorState directly and runs the main loop.
 * (The DLL path uses Editor.hx instead.)
 */
class EditorMain {
    public static function main():Void {
        var tilesetManager = new TilesetManager();
        var entityManager  = new EntityManager();

        var app = new App();
        app.init();

        var editorState = new EditorState(app, tilesetManager, entityManager);
        app.addState(editorState);

        app.run();
    }
}
