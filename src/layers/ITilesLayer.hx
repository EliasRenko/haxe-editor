package layers;

import display.ManagedTileBatch;

interface ITilesLayer {
    public var tileset:Tileset;
    public var managedTileBatch:ManagedTileBatch;

    public function redefineRegions(newTileset:Tileset):Void;
}