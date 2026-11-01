package ui;

import gui.PropertySet;
import states.EditorState;

class MapProperties extends PropertySet {

    public function new(state:EditorState) {
        super();

        addString("ID",
            function() return state.iid,
            function(value) state.iid = value
        );
        addFloat("X",
            function() return state.mapX,
            function(value) {
                if (Math.isFinite(value)) state.setMapBounds(value, state.mapY, state.mapWidth, state.mapHeight);
            }
        );
        addFloat("Y",
            function() return state.mapY,
            function(value) {
                if (Math.isFinite(value)) state.setMapBounds(state.mapX, value, state.mapWidth, state.mapHeight);
            }
        );
        addFloat("Width",
            function() return state.mapWidth,
            function(value) {
                if (Math.isFinite(value) && value > 0) state.setMapBounds(state.mapX, state.mapY, value, state.mapHeight);
            }
        );
        addFloat("Height",
            function() return state.mapHeight,
            function(value) {
                if (Math.isFinite(value) && value > 0) state.setMapBounds(state.mapX, state.mapY, state.mapWidth, value);
            }
        );
        addBool("Delete OOB Tiles",
            function() return state.deleteOutOfBoundsTilesOnResize,
            function(value) state.deleteOutOfBoundsTilesOnResize = value
        );
        addEnum("Grid",
            function() return state.grid.visible ? state.gridDisplayMode : "Hidden",
            ["Hidden", "Visible", "Colored"],
            function(value) state.setGridDisplayMode(value)
        );
    }
}
