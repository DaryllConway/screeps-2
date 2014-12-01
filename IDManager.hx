import Storage.Memory;

class IDManager {

    private static var scId2objs = new Map<String, Entity> ();
	private static var id2objs = new Map<Int, Base> ();
	private static var objs2ref : DynamicObject<Ref<Base>>;

	public static var creeps : Array<AICreep> = new Array<AICreep>();
	public static var spawns : Array<AISpawn> = new Array<AISpawn>();

	public static var loadedObjects : Array<Base>;

	public static var creepQueue : DynamicObject<Dynamic>;

	public static var manager : AIManager;

	public static function tick () {

		if (Game.time == 0) {
			trace("Clearing old data...");
			Memory["counter"] = 0;
			Memory["objects"] = null;
			Memory["refmap"] = null;
			Memory["manager"] = null;
			Memory["creepQueue"] = null;
		}

		// Load ID counter
		if ( Memory["counter"] == null ) {
			Memory["counter"] = 1;
		}

		// Load manager
		manager = Memory["manager"];
		if ( manager == null ) manager = new AIManager ();
		else manager = copyFields(manager, new AIManager());

		// Load objects
		var objects : Array<Dynamic>;
		if ( Memory["objects"] == null ) objects = new Array<Dynamic>();
		else objects = Memory["objects"];

		// Load creep queue
		creepQueue = Memory["creepQueue"];
		if ( creepQueue == null ) creepQueue = new DynamicObject<Dynamic>();

		// Load reference map
		objs2ref = Memory["refmap"];
		if ( objs2ref == null ) objs2ref = new DynamicObject<Ref<Base>>();

		loadedObjects = new Array<Base>();

		// Process creep queue
		var toRemove : Array<String> = [];
		for (queItem in creepQueue.keys()) {
			if (Game.creeps[queItem] != null) {
				addLink (Game.creeps[queItem], copyFields(creepQueue[queItem], new AICreep()));
				toRemove.push(queItem);
			}
		}
		for (key in toRemove) creepQueue.remove(key);

		// Hacky way to find the current room
		var room = Game.spawns["Spawn1"].room;

		// Make sure IDs are hooked up
		for (obj in room.find(Creeps)) scId2objs[obj.id] = obj;
		for (obj in room.find(Sources)) scId2objs[obj.id] = obj;
		for (obj in room.find(Structures)) scId2objs[obj.id] = obj;
		for (obj in room.find(Flags)) scId2objs[obj.id] = obj;
		for (obj in room.find(ConstructionSites)) scId2objs[obj.id] = obj;
		for (obj in room.find(DroppedEnergy)) scId2objs[obj.id] = obj;

		for (obj in Game.creeps) {
			scId2objs[obj.id] = obj;
		}

		for (obj in Game.flags) {
			scId2objs[obj.id] = obj;
		}

		for (obj in Game.structures) {
			scId2objs[obj.id] = obj;
		}

		for (obj in Game.spawns) {
			scId2objs[obj.id] = obj;
		}

		var toDestroy = new Array<Base>();

		for (obj in objects) {
			var ent : Base = cast obj;

			// Right now, ids have not been deserialized, so we have to do this
			var linkStr : String = cast ent.linked;
			var destroyed = bySCID (linkStr != null ? cast linkStr.substring(1,linkStr.length) : null) == null;

			switch (ent.type) {
			case AICreep:
				ent = cast copyFields (obj, new AICreep());
				if (!destroyed) creeps.push (cast ent);
			case AISpawn:
				ent = cast copyFields (obj, new AISpawn());
				if (!destroyed) spawns.push (cast ent);
			case AIEnergy:
				ent = cast copyFields (obj, new AIEnergy());
			case Base:
				throw "Cannot instantiate abstract Base";
			}

			ent.manager = manager;

			if (destroyed) {
				trace ("Detected destruction of " + ent.id + " of type " + ent.type);
				toDestroy.push(ent);
			} else {
				id2objs[ent.id] = ent;
				loadedObjects.push(ent);
			}
		}

		// Make sure all IDs are rewritten to real references
		for (ent in loadedObjects) {
			rewriteForDeserialization(ent);

			// Make sure the 'my' flag is set correctly
			var owned : OwnedEntity = cast ent.linked;
			ent.my = owned.my != null ? owned.my : false;
		}

		// Make sure all IDs are rewritten to real references
		for (ent in toDestroy) {
			rewriteForDeserialization(ent);
		}

		// Destroy objects
		for (ent in toDestroy) {
			ent.onDestroyed();
		}

		// Process spawns and create objects for them if none exists
		for (obj in Game.spawns) {
			if (objs2ref[obj.id] == null) {
				addLink(obj, new AISpawn().configure());
			}
		}
		//trace ("Loaded " + spawns.length + " " + creeps.length);
	}

	static function rewriteForSerialization (obj : Dynamic) {
		untyped __js__("

		var rec;
		rec = function (obj) {
			for (var key in obj) {
		    	if ( obj.hasOwnProperty(key)) {

		    		var val = obj[key];
		    		if (val != null) {
						if (val.hasOwnProperty('id')) {
							if (typeof(val.id) == 'string') {
								obj[key] = '#' + val.id;
							} else {
								obj[key] = '@' + val.id;
							}
						} else if (typeof(val) == 'object') {
							rec(obj[key]);
						}
					}
			    }
			}
	    };
	    rec(obj);
		");
	}

	static function rewriteForDeserialization (obj : Dynamic) {
		untyped __js__("

		var rec;
		rec = function (obj) {
			for (var key in obj) {
		    	if ( obj.hasOwnProperty(key)) {

		    		var val = obj[key];
		    		if (val != null && typeof(val) == 'string') {
		    			if (val[0] == '#') {
		    				// Screeps ref
							obj[key] = IDManager.bySCID(val.substring(1,val.length));
						} else if ( val[0] == '@' ) {
							// Our ref
							obj[key] = IDManager.byID(parseInt(val.substring(1,val.length)));
						}
					}
			    }
			}
	    };
	    rec(obj);
		");
	}

	//helper function to clone a given object instance
	static function copyFields<T> (from : Dynamic, to : T) {
		untyped __js__("
	    for (var key in from) {
	    	if ( from.hasOwnProperty(key)) {
		        //copy all the fields
		        to[key] = from[key];
		    }
	    }");
	    return to;
	}

	public static function tickEnd () {

		Memory["creepQueue"] = creepQueue;
		Memory["refmap"] = objs2ref;

		var objects = new Array<Dynamic>();
		for (obj in loadedObjects) {
			obj.manager = untyped __js__("undefined");

			rewriteForSerialization(obj);
			objects.push(obj);
		}

		Memory["objects"] = haxe.Json.parse (haxe.Json.stringify (objects));

		Memory["manager"] = haxe.Json.parse (haxe.Json.stringify (manager));
		//trace(objects);
	}

	public static function initialize ( obj : Base ) {
		obj.manager = manager;

		var id : Int = Memory["counter"];
		Memory["counter"] = id+1;
		obj.id = id;

		id2objs[id] = obj;
	}

	public static function queueAddCreep (name : String, creep : AICreep) {
		trace ("Queing " + creep.id);
		creepQueue[name] = copyFields (creep, {});
	}

	public static function addLink (obj1 : Entity, obj2 : Base) {
		trace("Added link between " + obj1.id + " " + obj2.id);

		var linkedEntity : Entity = obj2.linked;
		if (linkedEntity != null) throw "The Base object needs to be specifically created for the specified Entity.";

		obj2.linked = obj1;

		objs2ref[obj1.id] = obj2;
		loadedObjects.push (obj2);
		
		var owned : OwnedEntity = cast obj1;
		obj2.my = owned.my != null ? owned.my : false;
	}

	public static function bySCID (id : String) {
		return scId2objs[id];
	}

	public static function byID (id : Int) {
		return id2objs[id];
	}

	@:generic
	public static function from<T:Entity, U:Constructible> ( obj : T ) : U {
		if (objs2ref.exists(obj.id)) {
			//trace("Using existing... " + obj.id);
			var lookup : U = cast objs2ref[obj.id].toEntity();
			//trace(lookup + " " + lookup.id + " " + objs2ref[obj.id]);
			return lookup;
		} else {
			//trace("Creating new...");
			var lookup = new U();
			lookup.configure ();
			//trace(lookup + " " + lookup.id);
			addLink(obj, cast lookup);
			return lookup;
		}
	}
}

typedef Constructible = {
	public var id : Int;
	public function new():Void;
	public function configure():Void;
}