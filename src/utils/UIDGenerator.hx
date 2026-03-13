package utils;

/**
 * Generates short, globally unique string identifiers for entity instances.
 *
 * Format: e_<8-hex-timestamp-ms>_<4-hex-counter>
 * Example: e_0a3f12bc_0042
 *
 * The monotonic counter ensures uniqueness even when multiple entities are
 * created within the same millisecond. The timestamp component makes IDs
 * readable and naturally ordered. The counter resets across process restarts,
 * but the timestamp component makes collisions between sessions negligible.
 */
class UIDGenerator {

    private static var _counter:Int = 0;

    /**
     * Generate a new unique string ID.
     */
    public static function generate():String {
        var t = Std.int(Sys.time() * 1000) & 0x7FFFFFFF;
        _counter = (_counter + 1) & 0xFFFF;
        return "e_" + StringTools.hex(t, 8) + "_" + StringTools.hex(_counter, 4);
    }
}
