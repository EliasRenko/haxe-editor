package manager;

import EntityDefinition;

class EntityManager {

    public var entityDefinitions:Map<String, EntityDefinition>;

    public var selectedEntityName:String = "";
    private var __nextRegionId:Int = 0;

    public function new() {
        this.entityDefinitions = new Map<String, EntityDefinition>();
    }

    public function addEntityDefinition(def:EntityDefinition):Void {
        entityDefinitions.set(def.name, def);
    }

    public function getEntityDefinition(name:String):Null<EntityDefinition> {
        return entityDefinitions.get(name);
    }

    public function exists(name:String):Bool {
        return entityDefinitions.exists(name);
    }

    public function setEntity(entityName:String, width:Int, height:Int, tilesetName:String):Void {
        
        var entity:EntityDefinition = {
            name: entityName,
            width: width,
            height: height,
            tilesetName: tilesetName,
            regionX: 0,
            regionY: 0,
            regionWidth: width,
            regionHeight: height,
            pivotX: 0.0,
            pivotY: 0.0
        };
        
        entityDefinitions.set(entityName, entity);
    }

    /** Create or fully overwrite an entity definition with all fields provided. */
    public function setEntityFull(entityName:String, width:Int, height:Int, tilesetName:String,
                                   regionX:Int, regionY:Int, regionWidth:Int, regionHeight:Int,
                                   pivotX:Float, pivotY:Float):Void {
        var entity:EntityDefinition = {
            name: entityName,
            width: width,
            height: height,
            tilesetName: tilesetName,
            regionX: regionX,
            regionY: regionY,
            regionWidth: regionWidth,
            regionHeight: regionHeight,
            pivotX: pivotX,
            pivotY: pivotY
        };
        entityDefinitions.set(entityName, entity);
    }

	public function getEntityDefinitionAt(index:Int):Null<EntityDefinition> {
		if (index < 0)
			return null;

		var i = 0;
		for (name in entityDefinitions.keys()) {
			if (i == index) {
				return entityDefinitions.get(name);
			}
			i++;
		}
		return null;
	}

	public function getEntityDefinitionCount():Int {
		var count = 0;
		for (_ in entityDefinitions.keys()) {
			count++;
		}
		return count;
    }

	public function getEntityDefinitionNameAt(index:Int):String {
		if (index < 0)
			return "";

		var i = 0;
		for (name in entityDefinitions.keys()) {
			if (i == index) {
				return name;
			}
			i++;
		}
		return "";
	}

    public function deleteEntityDefinition(entityName:String):Bool {
        if (!entityDefinitions.exists(entityName)) {
            return false;
        }
        
        entityDefinitions.remove(entityName);
        return true;
    }

    public function setEntityRegion(tilesetManager:TilesetManager, entityName:String, x:Int, y:Int, width:Int, height:Int):Void {
        var entityDef = getEntityDefinition(entityName);
        if (entityDef == null) {
            return;
        }
        
        var tileset = tilesetManager.tilesets.get(entityDef.tilesetName);
        if (tileset == null) {
            return;
        }

        entityDef.regionX = x * tileset.tileSize;
        entityDef.regionY = y * tileset.tileSize;
        entityDef.regionWidth = width * tileset.tileSize;
        entityDef.regionHeight = height * tileset.tileSize;
    }
}