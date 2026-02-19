package manager;

import EntityDefinition;

class EntityManager {

    public var entityDefinitions:Map<String, EntityDefinition>;
    public var selectedEntityName:String = "";

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
            regionHeight: height
        };
        
        entityDefinitions.set(entityName, entity);
        trace("Created/updated entity definition: " + entityName + " (" + width + "x" + height + ") using tileset: " + tilesetName);
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
            trace("Entity definition not found: " + entityName);
            return false;
        }
        
        entityDefinitions.remove(entityName);
        trace("Deleted entity definition: " + entityName);
        return true;
    }
}