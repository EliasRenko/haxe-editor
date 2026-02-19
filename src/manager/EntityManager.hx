package manager;

class EntityManager {

    public var entityDefinitions:Map<String, EntityDefinition>;

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
}