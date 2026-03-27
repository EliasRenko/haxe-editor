# Refactoring Plan and Project Review

## Honest project review

### What’s good
- Working core features:
  - tilemap + entity layers, hierarchical folders (`src/states/EditorState.hx`, `src/layers/FolderLayer.hx`)
  - quadtree spatial indexing for entities (`src/layers/EntityLayer.hx`, `src/utils/EntityQuadtree.hx`)
  - serialization round-trip (export/import v1.6) in `EditorState.exportMapToJSON` and `importMapFromJSON`
  - native C API exposure through `editor_native.h` + macro auto-export (`src/macro/NativeExportMacro.hx`)
- Clean separation of rendering objects (`Grid`, `MapFrame`, `Selection`, `LineBatch`)

### Main problems
- `EditorState` is too large and mixes responsibilities:
  - UI/input handling (`handleInput`, keyboard/mouse)
  - layer operations (`createTilemapLayer`, `moveLayerUp`)
  - project/tileset/entity manager glue
  - serialization + import/export
- `exportMapToJSON` iterates fixed `for (tileId in 0...1000)`; brittle, loses tiles if >1000.
- lots of inline `trace`/raw thrown strings; no structured errors.
- direct `entities` array contains `Layer` + `Grid` + etc (via `State` base), causing fragile indexing.
- `mapFrame` handles resize in state; should be separate.
- tests / documentation incomplete for key workflows.

## Suggestions for feature changes / improvements

1. Layer & scene hierarchy
   - new class `LayerManager`:
     - methods for create/remove/reorder/folder flatten
     - active layer tracking
   - unify `getLayerAt/getLayerCount` and avoid duplicate Std.isOfType loops.

2. Input/Tools split
   - `InputController`, `ToolController` (tile draw / entity place / select)
   - `ToolType` + per-tool strategy; avoid huge switch in `handleInput`.

3. Entity selection and manipulation
   - preserve multi-select with shift/ctrl
   - drag-move for selected entities
   - property panel updates by callback (`onEntitySelectionChanged` already exists)

4. Undo/redo
   - command pattern with `ICommand.execute()` / `.undo()` / `.redo()`
   - tile add/remove/move, layer CRUD, entity transform

5. Serialization / migration
   - move JSON logic to `MapSerializer`
   - support version checks and migrations (1.6 -> future)
   - fix bug: tile region loop and fixed-size loops.

6. Performance
   - avoid rebuilding entity labels every frame
   - update labels only when entities change
   - quadtree debug only when flag on

7. Error handling
   - new error type for rich SDK responses
   - replace null/trace patterns with structured errors.

8. Clean API boundary
   - `editor_native.h` methods API docs
   - callback lifecycle tests

9. Missing features to add
   - layer opacity, blend modes, folder visibility cascade
   - snap-to-grid toggle, grid opacity
   - tile fill tools, copy/paste, TMX export
   - custom entity properties

## Full refactoring plan (phased)

### Phase 0: Baseline
- add unit tests harness
- add lint rules, no magic numbers

### Phase 1: Structural refactor
- split `EditorState` into manager classes
- move map bounds and frame logic to dedicated modules

### Phase 2: Data managers
- keep `TilesetManager` + `EntityManager`
- add `ProjectManager`
- add `MapSerializer`

### Phase 3: Command + undo
- define command manager
- wire to UI callbacks and undo/redo actions

### Phase 4: QA + robustness
- add regression tests
- add robust error returns for native API

### Phase 5: Polish + features
- implement advanced selection and editing
- optimize performance
- complete docs

## Quick low/medium/high effort tasks
- low: refactor loops and error logging
- medium: extract layer manager + serializer
- high: command history, undo/redo, format migration

## References
- `src/states/EditorState.hx`
- `src/layers/EntityLayer.hx`
- `src/layers/TilemapLayer.hx`
- `src/editor_native.h`
- `src/macro/NativeExportMacro.hx`

> Next step: I can create concrete patch files for `LayerManager` and `MapSerializer` if you want.
