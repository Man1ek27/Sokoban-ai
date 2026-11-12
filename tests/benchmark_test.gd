extends "res://tests/benchmark.gd"

## Regression checks of measurement/validation/export, without running a campaign.
var checks := 0
var failures := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	for map in [
		["#######", "#PB.G.#", "#######"],
		["#########", "#PBIIG..#", "#########"],
		["#########", "#PO....G#", "#########"],
		["##########", "#PII.B.G.#", "##########"]
	]:
		var level := LevelData.from_dictionary({"map": map})
		var initial := BoardState.from_level(level)
		var key := initial.state_key()
		for energy_mode in [false, true]:
			var mode := Solver.CostMode.ENERGY if energy_mode else Solver.CostMode.STEPS
			var result := Solver.new().solve(level, initial, mode)
			_check(result["success"], "Replay fixture must solve")
			var replay := _validate_plan(level, initial, result, energy_mode)
			_check(replay["valid"], "Walking/sliding/crate/barrel solution must validate")
			var sliding_body: bool = str(map[1]).contains("IIG") or str(map[1]).contains("O")
			_check(replay["pushes"] == (1 if sliding_body else 2),
				"Pushes must count actions with box_index, including a multi-cell slide once")
			_check(initial.state_key() == key, "Replay must preserve the initial state")
			var bad_energy: Dictionary = result.duplicate(true)
			bad_energy["energy"] += 1.0
			_check(not _validate_plan(level, initial, bad_energy, energy_mode)["valid"], "Wrong energy must fail")
			var bad_moves: Dictionary = result.duplicate(true)
			bad_moves["moves"] += 1
			_check(not _validate_plan(level, initial, bad_moves, energy_mode)["valid"], "Wrong action count must fail")
			var bad_cost: Dictionary = result.duplicate(true)
			bad_cost["cost"] += 1.0
			_check(not _validate_plan(level, initial, bad_cost, energy_mode)["valid"], "Wrong objective cost must fail")
			var bad_actions: Dictionary = result.duplicate(true)
			bad_actions["actions"] = [Vector2i.UP]
			_check(not _validate_plan(level, initial, bad_actions, energy_mode)["valid"], "Blocked action must fail")
			bad_actions["actions"] = []
			_check(not _validate_plan(level, initial, bad_actions, energy_mode)["valid"], "Unsolved final state must fail")

	var level := LevelData.from_dictionary({"map": ["#######", "#PB.G.#", "#######"]})
	var initial := BoardState.from_level(level)
	var result := Solver.new().solve(level)
	var solved := _measurement(level, initial, result, false)
	var rows: Array[Dictionary] = []
	for ms in [9.0, 1.0, 5.0]:
		var row: Dictionary = solved.duplicate(true)
		row["search_ms"] = ms
		rows.append(row)
	var summary := _summarize(rows)
	_check(summary["search_ms_median"] == 5.0 and summary["plan_consistent"], "Median uses sorted times")
	rows.pop_back()
	_check(_summarize(rows)["search_ms_median"] == 5.0, "Even median averages middle times")
	var limited := Solver.new().solve(level, initial, Solver.CostMode.STEPS, Callable(), 1, 30000)
	_check(limited["status"] == "state_limit", "Fixture must really hit state limit")
	var limit_row := _measurement(level, initial, limited, false)
	_check(limit_row["moves"] == null and limit_row["energy_j"] == null and limit_row["replay_valid"] == null,
		"Unsolved measurements must retain missing plan metrics")
	rows.append(limit_row)
	summary = _summarize(rows)
	_check(not summary["status_consistent"] and not summary["plan_consistent"], "Mixed statuses must be explicit")
	_check(JSON.parse_string(summary["status"]) == ["solved", "solved", "state_limit"], "Preserve statuses in repeat order")
	_check(JSON.parse_string(summary["energy_j"]) == [solved["energy_j"], solved["energy_j"], null], "Do not turn failed metrics into zeros")
	var different: Dictionary = solved.duplicate(true)
	different["plan_actions"] = "DIFFERENT"
	rows.assign([solved, different])
	_check(not _summarize(rows)["plan_consistent"], "Equal metrics with different action plans must be flagged")
	var slow := func(_state: BoardState, _level: LevelData) -> float:
		OS.delay_usec(2000)
		return 0.0
	var timed := Solver.new().solve(level, initial, Solver.CostMode.STEPS, slow, 100000, 1)
	_check(_measurement(level, initial, timed, false)["status"] == "time_limit", "Time limit must remain time_limit")
	var impossible := LevelData.from_dictionary({"robot_force": 0.0, "map": ["#######", "#PB.G.#", "#######"]})
	_check(_measurement(impossible, BoardState.from_level(impossible), Solver.new().solve(impossible), false)["status"] == "no_solution",
		"Exhausted search must remain no_solution")
	_check(_select_levels("1-3,2,5", 12) == [1, 2, 3, 5], "Level selection is one-based and deduplicated")
	for invalid in ["0", "13", "3-1", "1,", "1-2-3", "abc"]:
		_check(_select_levels(invalid, 12).is_empty(), "Reject invalid level selection: " + invalid)
	_check(not _parse_options(PackedStringArray(["--repeats", "0"])), "Reject nonpositive repetitions")
	_check(not _parse_options(PackedStringArray(["--mode", "h2"])), "Reject unknown mode")
	_check(not _parse_options(PackedStringArray(["--unknown", "x"])), "Reject unknown option")
	_check(_energy_equal(100.0, 100.00000001) and not _energy_equal(100.0, 100.01), "Energy tolerance is explicit")
	var csv_path := "user://benchmark_csv_test.csv"
	var csv := FileAccess.open(csv_path, FileAccess.WRITE)
	_check(csv != null, "CSV test requires write access to user://")
	if csv == null:
		quit(1)
		return
	var special := {"name": "Zażółć, \"test\"\nline", "missing": null, "value": 12.5}
	_write_row(csv, ["name", "missing", "value"], special)
	csv.close()
	csv = FileAccess.open(csv_path, FileAccess.READ)
	_check(csv != null, "CSV test must be able to reopen its file")
	if csv == null:
		quit(1)
		return
	_check(csv.get_csv_line() == PackedStringArray([special["name"], "", "12.5"]), "CSV must round-trip quotes, newlines, Polish text and missing values")
	csv.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(csv_path))
	print("Benchmark: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
