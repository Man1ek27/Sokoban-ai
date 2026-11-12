extends SceneTree

## Verifies that every campaign level is solvable with the shared physics model.
## Run: Godot --headless --path . --script res://tests/check_levels.gd
##      [-- <level index or -1> [steps|plan|trace|energy] [h1|h2|h3|dijkstra]]
const Campaign = preload("res://scripts/campaign.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var only := int(args[0]) if args.size() >= 1 and args[0].is_valid_int() else -1
	var mode := AStarSolver.CostMode.ENERGY if args.size() >= 2 and args[1] == "energy" else AStarSolver.CostMode.STEPS
	var heuristic_name := args[2] if args.size() >= 3 else "h1"
	var paths := Campaign.level_paths()
	var failures := 0
	for index in paths.size():
		if only >= 0 and index != only:
			continue
		var level := LevelData.from_file(paths[index])
		var heuristic := SokobanHeuristics.for_name(heuristic_name, level, mode == AStarSolver.CostMode.ENERGY)
		if not heuristic.is_valid():
			push_error("Nieznana heurystyka: %s" % heuristic_name)
			quit(2)
			return
		var result := AStarSolver.new().solve(level, null, mode, heuristic, 3000000, 300000)
		var pushes := _count_pushes(level, result["actions"])
		print("%2d %-26s %-10s moves=%3d pushes=%3d expanded=%8d time=%8.0f ms  game_ai=%s  discovered=%d energy=%.2f" % [
			index + 1, level.name, result["status"], result["moves"], pushes,
			result["expanded_states"], result["elapsed_ms"],
			"ok" if result["success"] and int(result["expanded_states"]) <= 100000 and float(result["elapsed_ms"]) < 30000.0 else "limit",
			result["discovered_states"], result["energy"]
		])
		if not result["success"]:
			failures += 1
		elif args.size() >= 2 and args[1] == "plan":
			print("   plan: ", _plan_text(result["actions"]))
		elif args.size() >= 2 and args[1] == "trace":
			_trace(level, result["actions"])
	quit(0 if failures == 0 else 1)

func _count_pushes(level: LevelData, actions: Array) -> int:
	var physics := PhysicalModel.new(level.robot_force)
	var state := BoardState.from_level(level)
	var pushes := 0
	for direction in actions:
		var transition := physics.move(state, direction, level)
		if int(transition["box_index"]) >= 0:
			pushes += 1
		state = transition["state"]
	return pushes

func _trace(level: LevelData, actions: Array) -> void:
	var physics := PhysicalModel.new(level.robot_force)
	var state := BoardState.from_level(level)
	var step := 0
	for direction in actions:
		step += 1
		var transition := physics.move(state, direction, level)
		state = transition["state"]
		if int(transition["box_index"]) >= 0 or transition.get("slid", false):
			print("-- %d %s %s" % [step, _plan_text([direction]), "push" if int(transition["box_index"]) >= 0 else "robot slide"])
			for y in level.tiles.size():
				var row := ""
				for x in level.tiles[y].length():
					var position := Vector2i(x, y)
					var index := state.box_at(position)
					if position == state.player_position:
						row += "P"
					elif index >= 0:
						row += "o" if state.boxes[index]["kind"] == LevelData.BARREL_KIND else "B"
					else:
						row += level.tile_at(position)
				print("   " + row)

func _plan_text(actions: Array) -> String:
	var text := ""
	for direction in actions:
		match direction:
			Vector2i.UP: text += "U"
			Vector2i.DOWN: text += "D"
			Vector2i.LEFT: text += "L"
			Vector2i.RIGHT: text += "R"
	return text
