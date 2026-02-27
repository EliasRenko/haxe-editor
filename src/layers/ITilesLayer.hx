package layers;

import display.ManagedTileBatch;

interface ITilesLayer {
    // Only requirement now is the ability to update regions when tileset changes
    public function redefineRegions(newTileset:Tileset):Void;
}