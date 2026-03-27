# Haxe Editor Refactoring Plan

**Date Created:** February 19, 2026  
**Status:** Draft  
**Priority:** High

## Overview
This document outlines the refactoring plan for the Haxe Editor project. The goal is to improve code organization, maintainability, performance, and extensibility while preserving existing functionality.

---

## Current State Analysis

### Strengths
✅ Working tilemap and entity layer system  
✅ Multi-tileset support  
✅ JSON import/export functionality  
✅ Basic layer management (create, delete, reorder)  
✅ Camera system with zoom and pan  
✅ Grid and visual helpers  

### Pain Points
❌ EditorState is a **God Object** (900+ lines, too many responsibilities)  
❌ Mixed concerns: rendering, input, layer management, serialization  
❌ Hard-coded values scattered throughout (e.g., MAX_TILES = 1000)  
❌ Inconsistent error handling (some trace, some return false)  
❌ No undo/redo system  
❌ Limited entity interaction (can't select, move, or edit entities)  
❌ No proper event system  
❌ Tight coupling between layers and EditorState  

---

## Phase 1: Code Organization (Week 1-2)

### 1.1 Extract Managers from EditorState

**Create dedicated manager classes:**

```
src/managers/
├── TilesetManager.hx      - Manage tilesets collection
├── EntityDefinitionManager.hx - Manage entity definitions
├── LayerManager.hx        - Layer hierarchy and active layer
├── SelectionManager.hx    - Track selected tiles/entities
└── CommandManager.hx      - Undo/redo system
```

**Benefits:**
- Single Responsibility Principle
- Easier testing
- Reduced EditorState complexity
- Better separation of concerns

**Action Items:**
- [ ] Create `TilesetManager` class
  - Move: `tilesets`, `setTileset()`, `deleteTileset()`, `getTilesetInfo()`
  - Add: Events for tileset changes
- [ ] Create `EntityDefinitionManager` class
  - Move: `entityDefinitions`, `setEntity()`, `setEntityRegion()`, etc.
- [ ] Create `LayerManager` class
  - Move: `activeLayer`, layer CRUD operations, layer reordering
  - Add: Layer hierarchy management (parent-child relationships)
- [ ] Create `SelectionManager` class (new feature)
  - Track selected tiles/entities
  - Multi-selection support
  - Selection rectangle rendering
- [ ] Create `CommandManager` class (new feature)
  - Command pattern for undo/redo
  - History stack management

### 1.2 Extract Input Handling

**Create `EditorInputHandler` class:**

```haxe
class EditorInputHandler {
    private var camera:Camera;
    private var layerManager:LayerManager;
    private var selectionManager:SelectionManager;
    
    public function update(deltaTime:Float):Void;
    private function handleTileInput():Void;
    private function handleEntityInput():Void;
    private function handleResizeInput():Void;
    private function handleSelectionInput():Void;
}
```

**Action Items:**
- [ ] Extract all input handling from `update()` and `handleTileInput()`
- [ ] Separate concerns: tile placement, entity placement, selection, camera control
- [ ] Add input context system (e.g., "tile_mode", "entity_mode", "select_mode")

### 1.3 Extract Serialization

**Create `MapSerializer` class:**

```haxe
class MapSerializer {
    public static function exportToJSON(layers:Array<Layer>, tilesets:Map<String, Tileset>, entities:Map<String, EntityDefinition>, mapBounds:Dynamic):String;
    public static function importFromJSON(jsonString:String):MapData;
}
```

**Action Items:**
- [ ] Move `exportToJSON()` and `importFromJSON()` logic
- [ ] Add versioning support (already at v1.3, but formalize it)
- [ ] Add migration system for old formats
- [ ] Better error handling with detailed error messages

---

## Phase 2: Architecture Improvements (Week 3-4)

### 2.1 Event System

**Create event dispatcher for loose coupling:**

```haxe
enum EditorEvent {
    TilesetAdded(name:String);
    TilesetRemoved(name:String);
    LayerCreated(layer:Layer);
    LayerDeleted(layer:Layer);
    ActiveLayerChanged(layer:Layer);
    SelectionChanged(selection:Array<Int>);
    MapBoundsChanged(bounds:Dynamic);
}

class EventDispatcher {
    public function dispatch(event:EditorEvent):Void;
    public function on(eventType:String, callback:Dynamic->Void):Void;
    public function off(eventType:String, callback:Dynamic->Void):Void;
}
```

**Benefits:**
- Decoupled communication between systems
- Easy to add new features without modifying core code
- Better for UI updates (C# can subscribe to events)

**Action Items:**
- [ ] Create `EventDispatcher` class
- [ ] Define all editor events
- [ ] Replace direct manager calls with event dispatching where appropriate
- [ ] Add C# event bridge for UI updates

### 2.2 Command Pattern for Undo/Redo

**Create command classes:**

```haxe
interface ICommand {
    public function execute():Void;
    public function undo():Void;
    public function redo():Void;
}

class PlaceTileCommand implements ICommand {
    private var layer:TilemapLayer;
    private var x:Float;
    private var y:Float;
    private var regionId:Int;
    private var tileId:Int; // Set after execute
    
    public function execute():Void;
    public function undo():Void;
    public function redo():Void;
}

class RemoveTileCommand implements ICommand { ... }
class PlaceEntityCommand implements ICommand { ... }
class MoveLayerCommand implements ICommand { ... }
```

**Action Items:**
- [ ] Create `ICommand` interface
- [ ] Implement commands for all user actions
- [ ] Integrate with `CommandManager`
- [ ] Add keyboard shortcuts (Ctrl+Z, Ctrl+Y)

### 2.3 Configuration System

**Create `EditorConfig` class:**

```haxe
class EditorConfig {
    // Rendering
    public var showGrid:Bool = true;
    public var showWorldAxes:Bool = true;
    public var gridSize:Float = 128.0;
    public var subGridSize:Float = 32.0;
    
    // Behavior
    public var deleteOutOfBoundsTilesOnResize:Bool = true;
    public var snapToGrid:Bool = true;
    public var minMapSize:Float = 320.0;
    
    // Limits
    public var maxTilesPerBatch:Int = 1000;
    
    // Load/save from JSON
    public function loadFromFile(path:String):Void;
    public function saveToFile(path:String):Void;
}
```

**Action Items:**
- [ ] Create configuration class
- [ ] Replace hard-coded values with config references
- [ ] Add config file support (editor-config.json)
- [ ] Expose config to C# UI for user preferences

---

## Phase 3: Feature Improvements (Week 5-6)

### 3.1 Entity Interaction

**Add entity selection and manipulation:**

- [ ] Click to select entity
- [ ] Drag to move entity
- [ ] Delete key to remove selected entity
- [ ] Multi-select entities (Ctrl+Click, drag rectangle)
- [ ] Entity properties panel (C# side)
- [ ] Entity rotation/scaling (future)

### 3.2 Layer Hierarchy

**Add folder layers (already exists but not fully utilized):**

- [ ] Drag layers into folders
- [ ] Collapse/expand folders
- [ ] Folder visibility affects children
- [ ] Proper parent-child rendering order

### 3.3 Performance Optimizations

**Improve rendering performance:**

- [ ] Spatial partitioning for tile/entity queries
- [ ] Frustum culling (only render visible tiles)
- [ ] Batch uploads (buffer orphaning is good, but can be smarter)
- [ ] Layer caching (don't rebuild buffers if layer hasn't changed)
- [ ] Profiling and bottleneck identification

**Action Items:**
- [ ] Add `QuadTree` or `SpatialHash` for fast spatial queries
- [ ] Implement camera frustum culling in layers
- [ ] Add dirty flag system to prevent unnecessary buffer updates
- [ ] Profile with large maps (10,000+ tiles)

### 3.4 Error Handling

**Improve error reporting:**

```haxe
enum EditorError {
    TilesetNotFound(name:String);
    LayerNotFound(name:String);
    InvalidMapBounds(reason:String);
    ImportFailed(reason:String);
}

class EditorErrorHandler {
    public static function handle(error:EditorError):Void;
    public static function report(message:String, category:LogCategory):Void;
}
```

**Action Items:**
- [ ] Create error handling system
- [ ] Replace `trace()` with proper logging
- [ ] Add error reporting to C# UI
- [ ] Add validation for user input

---

## Phase 4: Testing & Documentation (Week 7-8)

### 4.1 Unit Tests

**Add test coverage:**

```
tests/
├── TilesetManagerTest.hx
├── LayerManagerTest.hx
├── MapSerializerTest.hx
├── CommandManagerTest.hx
└── EntityDefinitionManagerTest.hx
```

**Action Items:**
- [ ] Set up testing framework (utest or munit)
- [ ] Write tests for all managers
- [ ] Test serialization (export/import consistency)
- [ ] Test command undo/redo
- [ ] Integration tests for full workflows

### 4.2 Documentation

**Create comprehensive docs:**

```
docs/
├── architecture.md        - System architecture overview
├── api-reference.md       - API documentation
├── tileset-format.md      - Tileset specification
├── entity-format.md       - Entity definition format
├── json-format.md         - Map JSON schema
└── contributing.md        - Contribution guidelines
```

**Action Items:**
- [ ] Document all public APIs
- [ ] Add code examples
- [ ] Document JSON format with schema
- [ ] Add architecture diagrams
- [ ] Document C# interop

---

## Phase 5: Polish & Extensions (Week 9-10)

### 5.1 UI/UX Improvements

- [ ] Visual feedback for active layer
- [ ] Hover preview for tile placement
- [ ] Entity bounding boxes when selected
- [ ] Minimap/overview panel
- [ ] Zoom to fit, zoom to selection
- [ ] Grid snapping toggle

### 5.2 Advanced Features

- [ ] Tile collision shapes/metadata
- [ ] Entity custom properties
- [ ] Layer opacity control
- [ ] Layer blend modes
- [ ] Copy/paste tiles and entities
- [ ] Fill tool (flood fill)
- [ ] Line/rectangle drawing tools

### 5.3 Export Formats

- [ ] Export to PNG (render map to image)
- [ ] Export to TMX (Tiled Map Editor format)
- [ ] Export to custom binary format (faster loading)

---

## Priority Matrix

| Phase | Task | Priority | Effort | Impact |
|-------|------|----------|--------|--------|
| 1.1 | Extract Managers | HIGH | Medium | High |
| 1.2 | Extract Input Handler | HIGH | Low | Medium |
| 2.1 | Event System | MEDIUM | Medium | High |
| 2.2 | Command Pattern | HIGH | High | High |
| 3.1 | Entity Interaction | MEDIUM | Medium | Medium |
| 3.3 | Performance Optimizations | LOW | High | Medium |
| 2.3 | Configuration System | LOW | Low | Low |
| 4.1 | Unit Tests | MEDIUM | High | High |
| 4.2 | Documentation | MEDIUM | Medium | Medium |
| 5.x | Polish & Extensions | LOW | High | Low |

---

## Implementation Guidelines

### Code Style
- Use consistent naming conventions (camelCase for variables, PascalCase for classes)
- Add documentation comments for public APIs
- Keep functions small (< 50 lines)
- Prefer composition over inheritance
- Use interfaces for loose coupling

### Git Workflow
- Create feature branches for each phase
- Write meaningful commit messages
- Create pull requests for review (even solo projects benefit)
- Tag releases after each phase

### Testing Strategy
- Write tests BEFORE refactoring
- Ensure existing functionality still works
- Add regression tests for bug fixes
- Aim for >70% code coverage

---

## Success Criteria

### After Phase 1:
✓ EditorState is < 300 lines  
✓ All managers extracted and tested  
✓ No functionality lost  

### After Phase 2:
✓ Event system integrated  
✓ Undo/redo working for all actions  
✓ Config system in place  

### After Phase 3:
✓ Entities can be selected and moved  
✓ Performance improved by >50% for large maps  
✓ Error handling consistent across codebase  

### After Phase 4:
✓ Test coverage >70%  
✓ Documentation complete  
✓ API stable  

### After Phase 5:
✓ All planned features implemented  
✓ Export formats working  
✓ UI polished  

---

## Notes

- **Backward Compatibility:** Maintain JSON format compatibility (use migration system)
- **C# Integration:** Ensure all manager APIs are exposed to C# via `editor_native.h`
- **Performance:** Profile after each phase to catch regressions early
- **Incremental:** Each phase should leave the editor in a working state

---

## Next Steps

1. Review this plan with team/stakeholders
2. Set up project tracking (GitHub Issues, Trello, etc.)
3. Begin Phase 1.1: Extract TilesetManager
4. Create feature branch: `refactor/phase-1-managers`

---

**Last Updated:** February 19, 2026  
**Version:** 1.0