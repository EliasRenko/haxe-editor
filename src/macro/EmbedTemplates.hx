package macro;

import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;

/**
 * EmbedTemplates — init macro that auto-discovers component HTML templates.
 *
 * All *.html files in src/components/templates/ are embedded as Haxe
 * resources at compile time.  The resource key is the filename without
 * the .html extension (e.g. "ConsolePanel").
 *
 * Components retrieve their template at runtime with:
 *   haxe.Resource.getString("ConsolePanel")
 *
 * To add a template for a new component, simply drop a .html file into
 * src/components/templates/ — no build file changes needed.
 *
 * Usage in build-web.hxml:
 *   --macro macro.EmbedTemplates.run()
 */
class EmbedTemplates {
    public static function run():Void {
        var dir = "src/components/templates";
        if (!FileSystem.exists(dir)) return;
        for (name in FileSystem.readDirectory(dir)) {
            if (!StringTools.endsWith(name, ".html")) continue;
            var key = name.substr(0, name.length - 5);
            var bytes = haxe.io.Bytes.ofString(File.getContent('$dir/$name'));
            Context.addResource(key, bytes);
        }
    }
}
