package states;

import display.ManagedTileBatch;
import EditorTexture;

/**
 * Lightweight state bag for the per-frame placement ghost cursor overlay.
 * EditorState owns one instance and updates it every frame inside handleInput().
 * The batch is created lazily and its texture is swapped (not reallocated) when
 * the active tileset / entity definition changes.
 */
class PlacementPreview {

    /** Alpha applied to the ghost sprite (0.6 = 60 % opacity). */
    public static inline var ALPHA:Float = 0.6;

    /** Whether the ghost should be rendered this frame. */
    public var visible:Bool = false;

    /** GPU batch holding the single ghost tile. Created lazily on first use. */
    public var batch:ManagedTileBatch = null;

    /**
     * The EditorTexture currently backing `batch`.
     * Compared each frame to detect tileset / entity changes so the batch texture
     * can be swapped cheaply via setTexture() instead of a full re-allocation.
     */
    public var currentTexture:EditorTexture = null;

    public function new() {}
}
