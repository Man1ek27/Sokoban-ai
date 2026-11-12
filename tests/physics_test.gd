extends SceneTree

## Unit checks of the shared physical model, the new tiles/bodies and campaign progress.
## Run: Godot --headless --path . --script res://tests/physics_test.gd
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _level(rows: Array, extra: Dictionary = {}) -> LevelData:
	var data := {"robot_force": 300.0, "map": rows}
	data.merge(extra)
	return LevelData.from_dictionary(data)

func _move(level: LevelData, state: BoardState, direction: Vector2i) -> Dictionary:
	return PhysicalModel.new(level.robot_force).move(state, direction, level)

func _run() -> void:
	_traction()
	_robot_slide()
	_box_slide()
	_barrels()
	_plates_and_doors()
	_ramps()
	_solver_rules()
	_heuristic_bounds()
	_campaign_progress()
	print("Physics: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _traction() -> void:
	var physics := PhysicalModel.new(300.0)
	_check(is_equal_approx(physics.push_force("."), 300.0), "On wood the motor limit must apply")
	_check(is_equal_approx(physics.push_force("I"), 0.1 * PhysicalModel.ROBOT_MASS * PhysicalModel.GRAVITY), "On ice grip must limit the push force")
	_check(physics.push_force("S") < 300.0, "Sand must reduce the push force")
	# Robot standing on ice cannot move a crate resting on wood.
	var level := _level(["#######", "#IB..G#", "#######"])
	var state := BoardState.new(Vector2i(1, 1), level.boxes)
	var result := _move(level, state, Vector2i.RIGHT)
	_check(not result["success"] and str(result["reason"]).contains("Koła"), "Ice under the robot must block a heavy push with a grip message")
	# The same push works from wood.
	level = _level(["#######", "#PB..G#", "#######"])
	result = _move(level, BoardState.from_level(level), Vector2i.RIGHT)
	_check(result["success"] and result["position"] == Vector2i(3, 1), "Push from wood must move the crate one tile")
	_check(result["state"].player_position == Vector2i(2, 1), "Robot must follow the pushed crate")

func _robot_slide() -> void:
	var level := _level(["########", "#PIII.G#", "#B.....#", "########"])
	var result := _move(level, BoardState.from_level(level), Vector2i.RIGHT)
	_check(result["success"] and result["state"].player_position == Vector2i(5, 1), "Robot must slide over ice to the first grippy tile")
	_check(result["robot_path"].size() == 4, "Robot path must list every slid tile")
	_check(is_equal_approx(float(result["energy"]), PhysicalModel.ROBOT_MASS * PhysicalModel.GRAVITY * 0.25), "Sliding must cost only the starting step")
	level = _level(["#######", "#PIIB.#", "#....G#", "#######"])
	result = _move(level, BoardState.from_level(level), Vector2i.RIGHT)
	_check(result["state"].player_position == Vector2i(3, 1) and int(result["box_index"]) == -1, "Sliding robot must stop in front of a box without pushing it")

func _box_slide() -> void:
	# A 35 kg crate pushed onto ice glides and is caught by the first rough tile.
	var level := _level(["##########", "#PBIIII.G#", "##########"])
	var result := _move(level, BoardState.from_level(level), Vector2i.RIGHT)
	_check(result["position"] == Vector2i(7, 1), "Crate must glide across ice and stop on the first wood tile")
	# Sand catches a sliding crate.
	level = _level(["#########", "#PBIIS.G#", "#########"])
	result = _move(level, BoardState.from_level(level), Vector2i.RIGHT)
	_check(result["position"] == Vector2i(5, 1), "Sand must catch a sliding crate")
	# A 45 kg crate lacks the energy to climb onto sand from ice.
	level = _level(["#########", "#PBIIS.G#", "#########"], {"boxes": [{"index": 0, "mass": 45.0}]})
	result = _move(level, BoardState.from_level(level), Vector2i.RIGHT)
	_check(result["position"] == Vector2i(4, 1), "Heavy crate must stop on the ice before sand")
	# A very heavy crate barely slides even on long ice.
	level = _level(["###########", "#PBIIIIII.#", "#........G#", "###########"], {"boxes": [{"index": 0, "mass": 75.0}]})
	result = _move(level, BoardState.from_level(level), Vector2i.RIGHT)
	_check(result["position"] == Vector2i(4, 1), "75 kg crate must stop after a short glide")
	# Crates on sand need the robot on firm ground.
	level = _level(["########", "#SSB..G#", "########"])
	result = _move(level, BoardState.new(Vector2i(2, 1), level.boxes), Vector2i.RIGHT)
	_check(result["success"], "Robot on sand can still push a 35 kg crate resting on wood")
	var on_sand := LevelData.from_dictionary({"robot_force": 300.0, "map": ["########", "#.SS..G#", "########"]})
	var crate_on_sand: Array[Dictionary] = [{"position": Vector2i(3, 1), "mass": 35.0, "kind": "crate"}]
	result = _move(on_sand, BoardState.new(Vector2i(2, 1), crate_on_sand), Vector2i.RIGHT)
	_check(not result["success"], "Robot on sand cannot unstick a crate from sand")
	result = _move(on_sand, BoardState.new(Vector2i(4, 1), crate_on_sand), Vector2i.LEFT)
	_check(result["success"] and result["position"] == Vector2i(2, 1), "Robot on wood can push a 35 kg crate through sand")

func _barrels() -> void:
	var level := _level(["##########", "#PO.....G#", "##########"])
	var result := _move(level, BoardState.from_level(level), Vector2i.RIGHT)
	_check(result["position"] == Vector2i(8, 1), "Barrel must roll over wood up to the wall")
	level = _level(["##########", "#PO..S..G#", "##########"])
	result = _move(level, BoardState.from_level(level), Vector2i.RIGHT)
	_check(result["position"] == Vector2i(5, 1), "Sand must stop a rolling barrel")
	_check(level.boxes[0]["kind"] == LevelData.BARREL_KIND and is_equal_approx(float(level.boxes[0]["mass"]), 30.0), "Barrel defaults must be parsed")

func _plates_and_doors() -> void:
	var rows := ["#########", "#P.B.D.G#", "#..._...#", "#########"]
	var light := _level(rows)
	var heavy := _level(rows, {"boxes": [{"index": 0, "mass": 45.0}]})
	var physics := PhysicalModel.new(300.0)
	for level: LevelData in [light, heavy]:
		var state := BoardState.from_level(level)
		state.boxes[0]["position"] = Vector2i(4, 2)
		state.player_position = Vector2i(4, 1)
		var result := physics.move(state, Vector2i.RIGHT, level)
		var open: bool = float(state.boxes[0]["mass"]) >= level.plate_mass
		_check(bool(result["success"]) == open, "Door must open only for >= plate_mass on the plate (mass %.0f)" % state.boxes[0]["mass"])
		if not open:
			_check(str(result["reason"]).contains("Drzwi"), "Closed door must explain the plate requirement")
	_check(not physics.doors_open(_level(["#####", "#PD.#", "#####"]), {}), "Doors without plates stay closed")
	var walled := _level(rows, {"plate_mass": 30.0})
	var masses := {Vector2i(4, 2): 35.0}
	_check(physics.doors_open(walled, masses), "Plate threshold must come from the level")

func _ramps() -> void:
	var level := _level(["#######", "#P.>.G#", "#..B..#", "#######"])
	var state := BoardState.from_level(level)
	state.player_position = Vector2i(2, 1)
	var result := _move(level, state, Vector2i.RIGHT)
	_check(result["success"] and result["state"].player_position == Vector2i(3, 1), "Ramp must accept movement along its arrow")
	state.player_position = Vector2i(4, 1)
	result = _move(level, state, Vector2i.LEFT)
	_check(not result["success"] and str(result["reason"]).contains("uskok"), "Ramp must reject movement against its arrow")
	# A box cannot be pushed onto a ramp from the side.
	level = _level(["#######", "#..P..#", "#..B..#", "#..^..#", "#G....#", "#######"])
	result = _move(level, BoardState.from_level(level), Vector2i.DOWN)
	_check(not result["success"], "Box must not enter a ramp against its direction")

func _solver_rules() -> void:
	# Extra boxes may stay off goals (e.g. as plate weights).
	var level := _level(["#######", "#PB.G.#", "#..B..#", "#######"])
	var result := AStarSolver.new().solve(level)
	_check(result["success"] and result["moves"] == 2, "Solver must accept more boxes than goals")
	var dead := AStarSolver.corner_dead_squares(_level(["#####", "#P.G#", "#...#", "#####"]))
	_check(dead.has(Vector2i(1, 2)) and not dead.has(Vector2i(3, 1)), "Corners are dead unless they hold a goal")
	var heuristic := SokobanHeuristics.manhattan_for(_level(["#####", "#PO.#", "#.G.#", "#####"]))
	var barrel_level := _level(["######", "#PO..#", "#...G#", "######"])
	_check(SokobanHeuristics.manhattan_for(barrel_level).call(BoardState.from_level(barrel_level), barrel_level) <= 2.0, "Barrels must not make the heuristic overestimate")
	_check(heuristic.is_valid(), "Heuristic factory must return a callable")

func _heuristic_bounds() -> void:
	var ice := _level(["##########", "#PB..IIG.#", "##########"])
	# The extra crate stops the barrel exactly on the goal before the end of its glide.
	var blocked_glide := _level(["##########", "#PO..GB..#", "##########"])
	var plate := _level(["#########", "#P.B.D.G#", "#..._...#", "#########"])
	plate.boxes.append({"position": Vector2i(4, 2), "mass": 40.0, "kind": LevelData.CRATE_KIND})
	var solver := AStarSolver.new()
	for level: LevelData in [ice, blocked_glide, plate]:
		var start := BoardState.from_level(level)
		for mode in [AStarSolver.CostMode.STEPS, AStarSolver.CostMode.ENERGY]:
			var energy_cost: bool = mode == AStarSolver.CostMode.ENERGY
			var baseline := solver.solve(level, start, mode, SokobanHeuristics.for_name("dijkstra", level))
			_check(baseline["success"], "Dijkstra must solve each heuristic fixture")
			for name in ["h2", "h3"]:
				var heuristic := SokobanHeuristics.for_name(name, level, energy_cost)
				var estimate := float(heuristic.call(start, level))
				var cost := float(baseline["cost"])
				var result := solver.solve(level, start, mode, heuristic)
				_check(estimate > 0.0 and (estimate <= cost or is_equal_approx(estimate, cost)), "%s must give a positive lower bound on the fixture" % name)
				_check(result["success"] and is_equal_approx(float(result["cost"]), cost), "%s must preserve the Dijkstra optimum" % name)

	var ice_start := BoardState.from_level(ice)
	var h2 := SokobanHeuristics.weighted_for(ice)
	var h3 := SokobanHeuristics.terrain_aware_for(ice)
	_check(h3.call(ice_start, ice) > h2.call(ice_start, ice), "h3 must account for the pushes needed to reach the ice")
	var light := _level(["######", "#PBG.#", "######"])
	var light_state := BoardState.from_level(light)
	var heavy_state := light_state.copy()
	heavy_state.boxes[0]["mass"] = 45.0
	var weighted_energy := SokobanHeuristics.weighted_for(light, true)
	_check(weighted_energy.call(heavy_state, light) > weighted_energy.call(light_state, light), "h2 ENERGY must account for mass in the current state")
	light.robot_force = 0.0
	var no_force := solver.solve(light, null, AStarSolver.CostMode.ENERGY, SokobanHeuristics.terrain_aware_for(light, true))
	_check(no_force["status"] == "no_solution", "h3 must return a finite estimate when the relaxed graph cannot reach a goal")

func _campaign_progress() -> void:
	var path := "user://physics_test_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var campaign := Campaign.new(path)
	_check(campaign.size() >= 10, "Campaign must list at least 10 levels")
	_check(campaign.is_unlocked(0) and not campaign.is_unlocked(1), "Only level 1 is unlocked at start")
	_check(campaign.complete(0, 10, 500.0), "Completing level 1 must report a new unlock")
	_check(campaign.is_unlocked(1) and not campaign.is_unlocked(2), "Exactly the next level unlocks")
	_check(not campaign.complete(0, 12, 400.0), "Replaying a level must not unlock more")
	_check(int(campaign.best_results[0]["moves"]) == 10, "Best result keeps the fewest moves")
	var reloaded := Campaign.new(path)
	_check(reloaded.is_unlocked(1) and reloaded.is_completed(0), "Progress must survive reload")
	reloaded.reset_progress()
	_check(not Campaign.new(path).is_unlocked(1), "Reset must lock the campaign again")
	for index in campaign.size():
		var level := LevelData.from_file(campaign.paths[index])
		_check(level.name != "" and level.description != "", "Level %d needs a name and description" % (index + 1))
		_check(level.boxes.size() >= level.goals.size() and not level.goals.is_empty(), "Level %d needs enough boxes" % (index + 1))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
