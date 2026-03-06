package type;

@:enum abstract ToolType(Int) from Int to Int {
	var TILE_DRAW = 0;
	var TILE_ERASE = 1;
	var ENTITY_ADD = 2;
    var ENTITY_SELECT = 3;
}