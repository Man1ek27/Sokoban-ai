extends SceneTree

## Standalone experiment runner. No gameplay scene or campaign progress is loaded.
const Solver = preload("res://scripts/astar_solver.gd")
const CampaignData = preload("res://scripts/campaign.gd")
const Heuristics = preload("res://scripts/sokoban_heuristics.gd")

const ENERGY_ABS_TOLERANCE := 0.000001
const ENERGY_REL_TOLERANCE := 0.000000001
const RAW_COLUMNS := [
	"level_number", "level_name", "level_path", "level_sha256", "cost_mode", "heuristic",
	"repeat", "status", "success", "moves", "pushes", "energy_j", "objective_cost",
	"expanded_states", "discovered_states", "search_ms", "replay_valid", "validation_error",
	"replay_moves", "replay_energy_j", "plan_actions", "max_expanded", "time_limit_ms",
	"godot_version", "started_utc"
]
const SUMMARY_COLUMNS := [
	"level_number", "level_name", "level_path", "level_sha256", "cost_mode", "heuristic",
	"repeats", "solved_count", "valid_plan_count", "status_consistent", "plan_consistent",
	"status", "success", "moves", "pushes", "energy_j", "objective_cost", "expanded_states",
	"discovered_states", "replay_valid", "validation_error", "replay_moves", "replay_energy_j",
	"plan_actions", "search_ms_median", "search_ms_min", "search_ms_max",
	"max_expanded", "time_limit_ms", "godot_version", "started_utc"
]
const AGGREGATED_COLUMNS := [
	"status", "success", "moves", "pushes", "energy_j", "objective_cost", "expanded_states",
	"discovered_states", "replay_valid", "validation_error", "replay_moves", "replay_energy_j",
	"plan_actions"
]

var options := {
	"levels": "all", "mode": "both", "repeats": 3, "time-limit-ms": 30000,
	"max-expanded": 100000, "output": "res://results/benchmark_raw.csv"
}
var argument_error := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--help"):
		print("benchmark.gd -- [--levels all|1-3|1,3,5-7] [--mode steps|energy|both]")
		print("  [--repeats 3] [--time-limit-ms 30000] [--max-expanded 100000]")
		print("  [--output res://results/benchmark_raw.csv]")
		quit(0)
		return
	if not _parse_options(args):
		_fail(argument_error)
		return
	var paths := CampaignData.level_paths()
	if paths.is_empty():
		_fail("Campaign manifest is empty or unreadable.")
		return
	var selected := _select_levels(str(options["levels"]), paths.size())
	if selected.is_empty():
		_fail(argument_error)
		return
	var output := _output_paths(str(options["output"]))
	for path in output:
		if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
			_fail("Cannot create output directory: %s" % path.get_base_dir())
			return
	var raw := FileAccess.open(output[0], FileAccess.WRITE)
	if raw == null:
		_fail("Cannot open raw CSV: %s" % output[0])
		return
	var summary := FileAccess.open(output[1], FileAccess.WRITE)
	if summary == null:
		_fail("Cannot open summary CSV: %s" % output[1])
		return

	raw.store_csv_line(PackedStringArray(RAW_COLUMNS))
	summary.store_csv_line(PackedStringArray(SUMMARY_COLUMNS))
	var modes: Array[String] = ["STEPS", "ENERGY"]
	if options["mode"] != "both":
		modes.assign([str(options["mode"]).to_upper()])
	var benchmark_error := false
	for number in selected:
		var path: String = paths[number - 1]
		for mode_name in modes:
			for heuristic_name in _heuristic_factories():
				var rows: Array[Dictionary] = []
				for repeat in range(1, int(options["repeats"]) + 1):
					# Fresh level, state, heuristic, physics and solver for every measurement.
					var level := LevelData.from_file(path)
					var initial := BoardState.from_level(level)
					var initial_key := initial.state_key()
					var energy_mode := mode_name == "ENERGY"
					var mode := Solver.CostMode.ENERGY if energy_mode else Solver.CostMode.STEPS
					var factory: Callable = _heuristic_factories()[heuristic_name]
					var heuristic: Callable = factory.call(level, energy_mode)
					var started := Time.get_datetime_string_from_system(true) + "Z"
					var result := Solver.new().solve(level, initial.copy(), mode, heuristic,
						int(options["max-expanded"]), int(options["time-limit-ms"]))
					var row := _measurement(level, initial, result, energy_mode)
					if initial.state_key() != initial_key:
						row["replay_valid"] = false
						row["validation_error"] = "Initial state was mutated"
					row.merge({
						"level_number": number, "level_name": level.name, "level_path": path,
						"level_sha256": FileAccess.get_sha256(path), "cost_mode": mode_name,
						"heuristic": heuristic_name, "repeat": repeat,
						"max_expanded": options["max-expanded"], "time_limit_ms": options["time-limit-ms"],
						"godot_version": Engine.get_version_info()["string"], "started_utc": started
					})
					rows.append(row)
					_write_row(raw, RAW_COLUMNS, row)
					raw.flush()
					print("%02d %s %s repeat=%d status=%s moves=%s energy=%s ms=%s replay=%s" % [
						number, mode_name, heuristic_name, repeat, row["status"], _cell(row["moves"]),
						_cell(row["energy_j"]), _cell(row["search_ms"]), _cell(row["replay_valid"])])
					if row["validation_error"] != "" or result["status"] in ["invalid_input", "invalid_heuristic"]:
						benchmark_error = true
						push_error("Benchmark error: level %d %s: %s %s" % [number, mode_name,
							row["status"], row["validation_error"]])
				_write_row(summary, SUMMARY_COLUMNS, _summarize(rows))
				summary.flush()
	var io_error := raw.get_error() != OK or summary.get_error() != OK
	raw.close()
	summary.close()
	print("Raw CSV: %s\nSummary CSV: %s" % output)
	if io_error:
		push_error("CSV write failed; results may be incomplete.")
	quit(1 if benchmark_error or io_error else 0)

## Add only real factory callables here when h2/h3 exist; grouping includes the name.
func _heuristic_factories() -> Dictionary:
	return {"manhattan": Heuristics.manhattan_for}

func _measurement(level: LevelData, initial: BoardState, result: Dictionary, energy_mode: bool) -> Dictionary:
	var row := {
		"status": result["status"], "success": result["success"],
		"moves": null, "pushes": null, "energy_j": null, "objective_cost": null,
		"expanded_states": result["expanded_states"], "discovered_states": result["discovered_states"],
		"search_ms": result["elapsed_ms"], "replay_valid": null, "validation_error": "",
		"replay_moves": null, "replay_energy_j": null, "plan_actions": null
	}
	if not result["success"]:
		return row
	var replay := _validate_plan(level, initial, result, energy_mode)
	row.merge({
		"moves": result["moves"], "pushes": replay["pushes"], "energy_j": result["energy"],
		"objective_cost": result["cost"], "replay_valid": replay["valid"],
		"validation_error": replay["error"], "replay_moves": replay["moves"],
		"replay_energy_j": replay["energy"], "plan_actions": _plan_text(result["actions"])
	}, true)
	return row

func _validate_plan(level: LevelData, initial: BoardState, result: Dictionary, energy_mode: bool) -> Dictionary:
	var state := initial.copy()
	var physics := PhysicalModel.new(level.robot_force)
	var moves := 0
	var pushes := 0
	var energy := 0.0
	var errors: Array[String] = []
	for direction in result["actions"]:
		var transition := physics.move(state, direction, level)
		if not transition["success"]:
			errors.append("Illegal action %d: %s" % [moves + 1, transition.get("reason", "")])
			break
		moves += 1
		energy += float(transition["energy"])
		if int(transition["box_index"]) >= 0:
			pushes += 1
		# Use the full transition, including multi-tile robot/crate/barrel slides.
		state = transition["state"]
	if not state.is_solved(level):
		errors.append("Final state is not solved")
	if moves != int(result["moves"]) or moves != result["actions"].size():
		errors.append("Action count differs from solver moves")
	if not _energy_equal(energy, float(result["energy"])):
		errors.append("Replay energy differs from solver energy")
	var expected_cost := energy if energy_mode else float(moves)
	if not _energy_equal(expected_cost, float(result["cost"])):
		errors.append("Objective cost differs from replay")
	return {"valid": errors.is_empty(), "error": "; ".join(errors),
		"moves": moves, "pushes": pushes, "energy": energy}

func _energy_equal(a: float, b: float) -> bool:
	return is_finite(a) and is_finite(b) and absf(a - b) <= \
		ENERGY_ABS_TOLERANCE + ENERGY_REL_TOLERANCE * maxf(absf(a), absf(b))

func _plan_text(actions: Array) -> String:
	var text := ""
	for direction in actions:
		match direction:
			Vector2i.UP: text += "U"
			Vector2i.DOWN: text += "D"
			Vector2i.LEFT: text += "L"
			Vector2i.RIGHT: text += "R"
	return text

func _summarize(rows: Array[Dictionary]) -> Dictionary:
	var summary: Dictionary = rows[0].duplicate()
	var times: Array[float] = []
	var solved := 0
	var valid := 0
	var plan_consistent := true
	for row in rows:
		times.append(float(row["search_ms"]))
		if row["success"]:
			solved += 1
		if row["replay_valid"] == true:
			valid += 1
		for column in ["status", "success", "moves", "pushes", "energy_j", "objective_cost", "plan_actions", "replay_valid"]:
			if row[column] != rows[0][column]:
				plan_consistent = false
	for column in AGGREGATED_COLUMNS:
		var values: Array = []
		for row in rows:
			values.append(row[column])
		summary[column] = values[0] if values.all(func(value: Variant) -> bool: return value == values[0]) else JSON.stringify(values)
	times.sort()
	var middle := times.size() / 2
	var median := times[middle] if times.size() % 2 == 1 else (times[middle - 1] + times[middle]) / 2.0
	summary.merge({
		"repeats": rows.size(), "solved_count": solved, "valid_plan_count": valid,
		"status_consistent": rows.all(func(row: Dictionary) -> bool: return row["status"] == rows[0]["status"]),
		"plan_consistent": plan_consistent, "search_ms_median": median,
		"search_ms_min": times.front(), "search_ms_max": times.back()
	}, true)
	return summary

func _cell(value: Variant) -> String:
	return "" if value == null else str(value)

func _write_row(file: FileAccess, columns: Array, row: Dictionary) -> void:
	var values := PackedStringArray()
	for column in columns:
		values.append(_cell(row.get(column)))
	# Godot handles quotes, commas, newlines and UTF-8; numeric str() is locale independent.
	file.store_csv_line(values)

func _parse_options(args: PackedStringArray) -> bool:
	if args.size() % 2 != 0:
		argument_error = "Expected --option value pairs. Use --help."
		return false
	for index in range(0, args.size(), 2):
		var name := args[index].trim_prefix("--")
		var value := args[index + 1]
		if not args[index].begins_with("--") or not options.has(name):
			argument_error = "Unknown option: %s" % args[index]
			return false
		if name in ["repeats", "time-limit-ms", "max-expanded"]:
			if not value.is_valid_int() or value.to_int() <= 0:
				argument_error = "%s requires a positive integer" % name
				return false
			options[name] = value.to_int()
		else:
			options[name] = value
	if str(options["mode"]).to_lower() not in ["steps", "energy", "both"]:
		argument_error = "Mode must be steps, energy or both"
		return false
	options["mode"] = str(options["mode"]).to_lower()
	if not str(options["output"]).to_lower().ends_with(".csv"):
		argument_error = "Output must be a CSV file path"
		return false
	return true

func _select_levels(selection: String, count: int) -> Array[int]:
	var selected: Array[int] = []
	if selection == "all":
		for number in range(1, count + 1):
			selected.append(number)
		return selected
	for part in selection.split(","):
		var bounds := part.split("-")
		if bounds.size() > 2 or not bounds[0].is_valid_int() or not bounds[-1].is_valid_int():
			argument_error = "Levels must be all or comma-separated numbers/ranges, e.g. 1-3,5"
			return []
		var first := bounds[0].to_int()
		var last := bounds[-1].to_int()
		if first < 1 or last > count or first > last:
			argument_error = "Level numbers must be in 1..%d, with ascending ranges" % count
			return []
		for number in range(first, last + 1):
			if not selected.has(number):
				selected.append(number)
	selected.sort()
	return selected

func _output_paths(raw_path: String) -> Array[String]:
	if not raw_path.is_absolute_path():
		raw_path = "res://".path_join(raw_path)
	raw_path = ProjectSettings.globalize_path(raw_path)
	var stem := raw_path.get_basename()
	if stem.ends_with("_raw"):
		stem = stem.trim_suffix("_raw")
	return [raw_path, stem + "_summary.csv"]

func _fail(message: String) -> void:
	push_error(message)
	quit(2)
