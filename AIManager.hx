class AIManager {

	public var roleCounter : Array<Int> = [];

	public var carrierNeeded : Float = 0;

	public function new () {
	}

	public function tick () {
		if (carrierNeeded > 0) carrierNeeded -= 1.3;
	}

	public function getRoleCount ( role : Role ) {
		while (cast(role,Int) >= roleCounter.length) {
			roleCounter.push(0);
		}
		return roleCounter[role];
	}

	public function modRoleCount ( role : Role, diff : Int ) {
		while (cast(role,Int) >= roleCounter.length) {
			roleCounter.push(0);
		}
		roleCounter[role] += diff;
	}
}

@:enum
abstract Role(Int) to Int from Int {
	var Harvester = 0;
	var MeleeAttacker = 1;
	var RangedAttacker = 2;
	var EnergyCarrier = 3;
}