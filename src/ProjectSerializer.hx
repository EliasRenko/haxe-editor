package;

import EntityDefinition;
import EditorTexture;
import states.EditorState;
import utils.UIDGenerator;

// ---------------------------------------------------------------------------
// ProjectSerializer — saves and loads .hxproject JSON files.
//
// A project file is the authoritative source for:
//   • Entity definitions  (shared across all maps in the project)
//   • Tileset declarations (name → texture path mappings)
//   • Global editor settings (default tile size, etc.)
//
// Map files reference the project file via a "projectFile" field so that
// entity definitions and tilesets do not need to be duplicated inside every
// map export.
// ---------------------------------------------------------------------------

/** Version tag embedded in every project file. */
private inline var PROJECT_VERSION:String = "1.0";

@:access(states.EditorState)
class ProjectSerializer {

    private var state:EditorState;

    public function new(state:EditorState) {
        this.state = state;
    }

    // -----------------------------------------------------------------------
    // Export
    // -----------------------------------------------------------------------

    /**
     * Serialize the current project (entity definitions + tilesets + global
     * settings) to a JSON file at `filePath`.
     *
     * @param filePath  Absolute path for the output .hxproject file.
     * @param projectName  Human-readable project name stored inside the file.
     * @return  Number of entity definitions written, or -1 on error.
     */
    public function exportToJSON(filePath:String, projectName:String = "", projectId:String = ""):Int {

        var projectUid:String = (projectId != "") ? projectId : UIDGenerator.generate();

        // ── Tilesets ────────────────────────────────────────────────────────
        var tilesetsArray:Array<Dynamic> = [];
        for (tilesetName in state.tilesetManager.tilesets.keys()) {
            var ts = state.tilesetManager.tilesets.get(tilesetName);
            tilesetsArray.push({
                name: ts.name,
                texturePath: ts.texturePath
            });
        }

        // ── Entity definitions ───────────────────────────────────────────────
        var entitiesArray:Array<Dynamic> = [];
        for (entityName in state.entityManager.entityDefinitions.keys()) {
            var def = state.entityManager.getEntityDefinition(entityName);
            entitiesArray.push({
                name:         def.name,
                width:        def.width,
                height:       def.height,
                tilesetName:  def.tilesetName,
                regionX:      def.regionX,
                regionY:      def.regionY,
                regionWidth:  def.regionWidth,
                regionHeight: def.regionHeight,
                pivotX:       def.pivotX,
                pivotY:       def.pivotY
            });
        }

        var projectData = {
            version:          PROJECT_VERSION,
            projectId:        projectUid,
            projectName:      projectName != "" ? projectName : "Untitled",
            defaultTileSizeX: state.tileSizeX,
            defaultTileSizeY: state.tileSizeY,
            tilesets:         tilesetsArray,
            entityDefinitions: entitiesArray
        };

        var data = {
            project: projectData
        };

        var jsonString = haxe.Json.stringify(data, null, "  ");
        try {
            sys.io.File.saveContent(filePath, jsonString);
            trace("ProjectSerializer: Saved " + entitiesArray.length + " entity definitions and "
                + tilesetsArray.length + " tilesets to: " + filePath);
            return entitiesArray.length;
        } catch (e:Dynamic) {
            trace("ProjectSerializer: Error saving project: " + e);
            return -1;
        }
    }

    // -----------------------------------------------------------------------
    // Import
    // -----------------------------------------------------------------------

    /**
     * Load entity definitions and tilesets from a previously saved project
     * file.  Existing tilesets and entity definitions that share a name are
     * overwritten; others are left untouched.
     *
     * @param filePath  Absolute path to the .hxproject JSON file.
     * @return  Number of entity definitions loaded, or -1 on error.
     */
    public function importFromJSON(filePath:String):Int {
        var jsonString:String;
        var data:Dynamic;

        try {
            jsonString = sys.io.File.getContent(filePath);
            data = haxe.Json.parse(jsonString);
        } catch (e:Dynamic) {
            trace("ProjectSerializer: Could not read/parse project file: " + e);
            return -1;
        }

        // Enforce wrapped project format.
        if (data.project == null) {
            trace("ProjectSerializer: Invalid project JSON: missing top-level 'project' object");
            return -1;
        }
        var projectData:Dynamic = data.project;

        // ── Project identity ─────────────────────────────────────────────────
        var projectId:String = "";
        if (projectData.projectId != null && Std.is(projectData.projectId, String) && cast(projectData.projectId, String) != "") {
            projectId = cast(projectData.projectId, String);
        } else {
            projectId = UIDGenerator.generate();
        }
        state.projectId = projectId;

        // ── Global settings ──────────────────────────────────────────────────
        if (projectData.defaultTileSizeX != null && projectData.defaultTileSizeY != null) {
            try {
                state.setTileSize(Std.int(data.defaultTileSizeX), Std.int(data.defaultTileSizeY));
            } catch (e:Dynamic) {
                trace("ProjectSerializer: Warning — could not apply default tile size: " + e);
            }
        }

        // ── Tilesets ─────────────────────────────────────────────────────────
        // Each tileset is loaded independently; one bad path must not abort
        // the rest of the import.
        var tilesetsLoaded = 0;
        if (data.tilesets != null) {
            var tilesetsArray:Array<Dynamic> = data.tilesets;
            for (tilesetData in tilesetsArray) {
                var name:String = tilesetData.name;
                var path:String = tilesetData.texturePath;
                try {
                    if (state.tilesetManager.exists(name)) {
                        trace("ProjectSerializer: Tileset already loaded, skipping: " + name);
                    } else {
                        var err = Editor.createTileset(path, name);
                        if (err == null)
                            trace("ProjectSerializer: Loaded tileset: " + name);
                        else
                            trace("ProjectSerializer: Warning — could not load tileset '" + name + "': " + err);
                    }
                    tilesetsLoaded++;
                } catch (e:Dynamic) {
                    trace("ProjectSerializer: Warning — exception loading tileset '" + name + "' (" + path + "): " + e);
                }
            }
        }

        // ── Entity definitions ───────────────────────────────────────────────
        // Written directly to EntityManager so:
        //   • Definitions load even when their tileset texture failed to upload.
        //   • Re-importing the same project overwrites rather than errors.
        var entitiesLoaded = 0;
        if (data.entityDefinitions != null) {
            var entitiesArray:Array<Dynamic> = data.entityDefinitions;
            for (entityData in entitiesArray) {
                try {
                    var pivotX:Float = entityData.pivotX != null ? entityData.pivotX : 0.0;
                    var pivotY:Float = entityData.pivotY != null ? entityData.pivotY : 0.0;
                    state.entityManager.setEntityFull(
                        entityData.name,
                        entityData.width,       entityData.height,
                        entityData.tilesetName,
                        entityData.regionX,     entityData.regionY,
                        entityData.regionWidth, entityData.regionHeight,
                        pivotX, pivotY
                    );
                    trace("ProjectSerializer: Loaded entity definition: " + entityData.name);
                    entitiesLoaded++;
                } catch (e:Dynamic) {
                    trace("ProjectSerializer: Warning — exception loading entity def '" + entityData.name + "': " + e);
                }
            }
        }

        var loadedProjectName:String = projectData.projectName != null ? cast(projectData.projectName, String) : "?";
        trace("ProjectSerializer: Loaded project '" + loadedProjectName + "' (" + projectId + ") — "
            + entitiesLoaded + " entities, " + tilesetsLoaded + " tilesets");
        return entitiesLoaded;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /**
     * Read the `projectName` field from a project file without fully loading
     * its content into the editor state.  Useful for UI display.
     *
     * @return  The project name string, or null on error.
     */
    public static function readProjectName(filePath:String):Null<String> {
        try {
            var jsonString = sys.io.File.getContent(filePath);
            var data:Dynamic = haxe.Json.parse(jsonString);
            if (data.project == null) return null;
            return data.project.projectName;
        } catch (_:Dynamic) {
            return null;
        }
    }
}
