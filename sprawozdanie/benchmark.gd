extends SceneTree

const HEURISTICS := ["h1", "h2", "h3"]
const MODES := ["steps", "energy"]
const REPETITIONS := 3
const STATE_LIMIT := 100000
const TIME_LIMIT_MS := 30000
const OUTPUT := "res://sprawozdanie/benchmark_raw.csv"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write benchmark results.")
		quit(2)
		return
	var paths := Campaign.level_paths()
	var snapshot := _snapshot_digest(paths)
	output.store_csv_line(PackedStringArray([
		"level", "level_name", "heuristic", "cost_mode", "run_id", "robot_force_n",
		"state_limit", "time_limit_ms", "status", "elapsed_ms", "expanded_states",
		"discovered_states", "moves", "pushes", "energy_j", "replay_ok", "code_sha256"
	]))
	print("Godot=%s | OS=%s %s | CPU=%s | RAM bytes=%d | snapshot=%s" % [
		Engine.get_version_info()["string"], OS.get_name(), OS.get_version(), OS.get_processor_name(),
		OS.get_memory_info().get("physical", 0), snapshot
	])
	var invalid_plans := 0
	for run in REPETITIONS:
		for index in paths.size():
			var level := LevelData.from_file(paths[index])
			for mode_offset in MODES.size():
				var mode_index := (mode_offset + run) % MODES.size()
				for heuristic_offset in HEURISTICS.size():
					var heuristic: String = HEURISTICS[(heuristic_offset + run) % HEURISTICS.size()]
					invalid_plans += _measure(output, level, index + 1, run + 1, mode_index, heuristic, snapshot)
			output.flush()
			print("Repetition %d/%d, level %d/%d" % [run + 1, REPETITIONS, index + 1, paths.size()])
	output.close()
	quit(0 if invalid_plans == 0 else 1)

func _measure(
		output: FileAccess, level: LevelData, index: int, run: int, mode_index: int,
		name: String, snapshot: String
	) -> int:
	var mode := AStarSolver.CostMode.ENERGY if mode_index == 1 else AStarSolver.CostMode.STEPS
	var started := Time.get_ticks_usec()
	var heuristic := SokobanHeuristics.for_name(name, level, mode == AStarSolver.CostMode.ENERGY)
	var result := AStarSolver.new().solve(level, null, mode, heuristic, STATE_LIMIT, TIME_LIMIT_MS)
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	var replay_ok := ""
	var moves := ""
	var pushes := ""
	var energy := ""
	if result["success"]:
		var replayed_pushes := _validate_replay(level, result, mode)
		replay_ok = "true" if replayed_pushes >= 0 else "false"
		moves = str(result["moves"])
		pushes = str(replayed_pushes)
		energy = str(result["energy"])
	output.store_csv_line(PackedStringArray([
		str(index), level.name, name, MODES[mode_index], str(run), str(level.robot_force),
		str(STATE_LIMIT), str(TIME_LIMIT_MS), result["status"], str(elapsed),
		str(result["expanded_states"]), str(result["discovered_states"]), moves, pushes, energy,
		replay_ok, snapshot
	]))
	return int(replay_ok == "false")

func _validate_replay(level: LevelData, result: Dictionary, mode: AStarSolver.CostMode) -> int:
	var physics := PhysicalModel.new(level.robot_force)
	var state := BoardState.from_level(level)
	var energy := 0.0
	var pushes := 0
	for action in result["actions"]:
		var transition := physics.move(state, action, level)
		if not transition["success"]:
			return -1
		state = transition["state"]
		energy += float(transition["energy"])
		pushes += int(int(transition["box_index"]) >= 0)
	var moves: int = result["actions"].size()
	var cost := energy if mode == AStarSolver.CostMode.ENERGY else float(moves)
	if not state.is_solved(level) or moves != int(result["moves"]):
		return -1
	if not is_equal_approx(energy, float(result["energy"])) or not is_equal_approx(cost, float(result["cost"])):
		return -1
	return pushes

func _snapshot_digest(level_paths: PackedStringArray) -> String:
	var files := PackedStringArray(["res://levels/campaign.json", "res://sprawozdanie/benchmark.gd"])
	files.append_array(level_paths)
	for file in DirAccess.get_files_at("res://scripts"):
		if file.ends_with(".gd"):
			files.append("res://scripts/" + file)
	files.sort()
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	for path in files:
		hash_context.update((path + ":" + FileAccess.get_sha256(path) + "\n").to_utf8_buffer())
	return hash_context.finish().hex_encode()
