class AIConstructionSite extends AIAssigned {

	public var src(get, null) : ConstructionSite;
	inline function get_src() return cast linked;

	var lastProgress : Int;
	var previousProgress : Int;

	public function new () {
		super();
	}

	public function configure () {
		initialize ();
		return this;
	}

	public override function tick () {

		if (previousProgress > src.progress) {
			lastProgress = Game.time;
		}
		previousProgress = src.progress;

		if (Std.int ((Game.time - lastProgress)/50) % 2 == 1 ) {
			// Probably stuck
			trace("Builders probably stuck");
			maxAssignedCount = 0;
			cleanup();
			for (creep in assigned) {
				unassign(creep);
			}
			return;
		}

		maxAssignedCount = switch (src.structureType) {
			case Spawn: Std.int (Math.min ((manager.getRoleCount(Harvester)+manager.getRoleCount(Builder))/2, 6));
			case Extension: 3;
			case Road: 1;
			case Wall: 2;
			case Rampart: 1;
		}

		cleanup ();

		if (assigned.length < maxAssignedCount || Game.time % 20 == 0) {
			var bestScore = -100000.0;
			var best = null;

			for (creep in IDManager.creeps) {
				if ((creep.role == Harvester || creep.role == Builder) && creep.src.getActiveBodyparts(Carry) > 0) {
					var score = creep.role == Builder ? 10.0 : 0.0;
					//score -= Math.sqrt (RoomPosition.squaredDistance(src.pos, creep.src.pos));

					if (creep.originalRole == Builder) score += 30;

					// If we can add more assigned units, add a huge negative score for already assigned units
					// otherwise add a large positive score
					if (creep.currentTarget == this) score += assigned.length < maxAssignedCount ? -100 : 19;
					else if (creep.currentTarget != null && creep.currentTarget.type == AIConstructionSite) continue;

					if (score > bestScore) {

						var path = creep.src.pos.findPathTo (src.pos);
						if (path.length != 0 && src.pos.isNearTo (cast path[path.length-1])) {
							best = creep;
							bestScore = score;
						}
					}
				}
			}

			if (best != null && best.currentTarget != this) {

				best.role = Builder;
				assign(best, bestScore);
			}
		}
	}
}