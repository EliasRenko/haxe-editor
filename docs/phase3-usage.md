# Phase 3 Features - Usage Guide

## Feature 1: JSON Export

Export your tilemap to a JSON file for saving/loading:

### Usage from C# host:
```csharp
// Call the export function
int tileCount = editorState.exportToJSON("C:\\path\\to\\map.json");
Console.WriteLine($"Exported {tileCount} tiles");
```

### JSON Output Format:
```json
{
  "version": "1.0",
  "tileSize": 32,
  "mapBounds": {
    "x": 0,
    "y": 0,
    "width": 1024,
    "height": 1024,
    "gridWidth": 32,
    "gridHeight": 32
  },
  "tiles": [
    {
      "gridX": 0,
      "gridY": 0,
      "x": 0,
      "y": 0,
      "region": 0
    },
    {
      "gridX": 1,
      "gridY": 0,
      "x": 32,
      "y": 0,
      "region": 1
    }
  ],
  "tileCount": 2
}
```

### Data Structure:
- **gridX, gridY**: Grid coordinates (tile indices)
- **x, y**: World coordinates in pixels
- **region**: Atlas region ID (which tile texture from the sprite sheet)
- **mapBounds**: Current size of the editable area
- **tileSize**: Size of each tile (32px)

---

## Feature 2: World Axes

Visual aid showing X/Y axes at world origin (0,0).

### Colors:
- **Red line**: X-axis (horizontal)
- **Green line**: Y-axis (vertical)

### Toggle visibility:
```csharp
// Show/hide axes
editorState.showWorldAxes = true;  // Show
editorState.showWorldAxes = false; // Hide
```

### Properties:
- Axes extend 10,000 units in each direction (infinite for practical purposes)
- Always visible regardless of zoom level
- Rendered slightly above grid (z = 0.05)
- No depth testing (always on top)

---

## Feature 3: Tile Deletion Options

Control what happens to tiles when resizing the frame smaller.

### Default behavior (auto-delete):
```csharp
editorState.deleteOutOfBoundsTilesOnResize = true; // Default
```
- Tiles outside new bounds are **automatically deleted**
- No orphaned tiles in storage
- Clean and predictable

### Keep tiles (preserve on resize):
```csharp
editorState.deleteOutOfBoundsTilesOnResize = false;
```
- Tiles outside bounds **remain in storage**
- Can restore by expanding frame back
- Use `cleanupTilesOutsideBounds()` to manually delete later

### Manual cleanup:
```csharp
// Remove all tiles outside current bounds
int removedCount = editorState.cleanupTilesOutsideBounds();
Console.WriteLine($"Removed {removedCount} orphaned tiles");
```

---

## Grid-Based Storage Performance

Tiles are now indexed using a grid-based hash map for **O(1) lookups**:

### Before:
```haxe
// O(n) - iterate through 1000 tiles
for (tileId in 0...1000) {
    if (tile.x == targetX && tile.y == targetY) { /* found */ }
}
```

### After:
```haxe
// O(1) - instant dictionary lookup
var gridKey = "32_64"; // "gridX_gridY"
var tileId = tileGrid.get(gridKey); // instant!
```

**Performance gain**: ~1000x faster for placement/removal operations!

---

## Complete Example

```csharp
using System;

class EditorExample {
    void SetupEditor() {
        var editorState = GetEditorState();
        
        // Enable world axes for orientation
        editorState.showWorldAxes = true;
        
        // Keep tiles when resizing (safer for experimentation)
        editorState.deleteOutOfBoundsTilesOnResize = false;
        
        // ... user edits the map ...
        
        // Export to JSON
        int tileCount = editorState.exportToJSON("maps/level1.json");
        Console.WriteLine($"Saved {tileCount} tiles to level1.json");
        
        // Optional: clean up orphaned tiles
        int removed = editorState.cleanupTilesOutsideBounds();
        if (removed > 0) {
            Console.WriteLine($"Cleaned up {removed} orphaned tiles");
        }
    }
}
```

---

## Next Steps

- **Phase 4**: Implement JSON import/loading
- **Phase 5**: Add tile selection UI (picker palette)
- **Phase 6**: Multi-tile selection and copy/paste
- **Phase 7**: Undo/redo system
