class_name AStarSolver
extends RefCounted

const Queue = preload("res://scripts/min_priority_queue.gd")
const State = preload("res://scripts/board_state.gd")
const Heuristics = preload("res://scripts/sokoban_heuristics.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

enum CostMode { STEPS, ENERGY }

func solve(
		level: LevelData,
		initial_state: BoardState = null,
		cost_mode: CostMode = CostMode.STEPS,
		heuristic: Callable = Callable(),
		max_expanded: int = 100000,
		time_limit_ms: int = 5000
	) -> Dictionary:
	var started := Time.get_ticks_usec()
	if level == null or max_expanded <= 0 or time_limit_ms <= 0:
		return _result("invalid_input", started, 0, 0)
	if cost_mode != CostMode.STEPS and cost_mode != CostMode.ENERGY:
		return _result("invalid_input", started, 0, 0)
	var start: BoardState = State.from_level(level) if initial_state == null else initial_state.copy()
	if not _valid_state(start, level):
		return _result("invalid_input", started, 0, 0)
	if not heuristic.is_valid():
		heuristic = Heuristics.manhattan_for(level, cost_mode == CostMode.ENERGY)
	var physics := PhysicalModel.new(level.robot_force)
	var frontier := Queue.new()
	var start_key := start.state_key()
	var best_g := {start_key: 0.0}
	var parents := {}
	var start_h := _estimate(start, level, heuristic)
	if not is_finite(start_h) or start_h < 0.0:
		return _result("invalid_heuristic", started, 0, 1)
	frontier.push({"state": start, "key": start_key, "g": 0.0}, start_h)
	var expanded := 0
	while not frontier.is_empty():
		if Time.get_ticks_usec() - started >= time_limit_ms * 1000:
			return _result("time_limit", started, expanded, best_g.size())
		var current: Dictionary = frontier.pop()
		var key: String = current["key"]
		var g: float = current["g"]
		# Improved states can leave older entries in the heap.
		if g != float(best_g[key]):
			continue
		var state: BoardState = current["state"]
		if state.is_solved(level):
			return _solution(key, parents, g, started, expanded, best_g.size())
		if expanded >= max_expanded:
			return _result("state_limit", started, expanded, best_g.size())
		expanded += 1
		for direction in DIRECTIONS:
			var transition := physics.move(state, direction, level)
			if not transition["success"]:
				continue
			var next_state: BoardState = transition["state"]
			var next_key := next_state.state_key()
			var step_cost: float = 1.0 if cost_mode == CostMode.STEPS else float(transition["energy"])
			var next_g := g + step_cost
			if best_g.has(next_key) and next_g >= float(best_g[next_key]):
				continue
			var h := _estimate(next_state, level, heuristic)
			if not is_finite(h) or h < 0.0:
				return _result("invalid_heuristic", started, expanded, best_g.size())
			best_g[next_key] = next_g
			parents[next_key] = {"parent": key, "direction": direction, "energy": transition["energy"]}
			frontier.push({"state": next_state, "key": next_key, "g": next_g}, next_g + h)
	return _result("no_solution", started, expanded, best_g.size())

func _estimate(state: BoardState, level: LevelData, heuristic: Callable) -> float:
	return float(heuristic.call(state, level))

func _valid_state(state: BoardState, level: LevelData) -> bool:
	if state.boxes.is_empty() or state.boxes.size() != level.goals.size():
		return false
	if not is_finite(level.robot_force) or level.robot_force < 0.0:
		return false
	if not level.is_walkable(state.player_position) or state.box_at(state.player_position) >= 0:
		return false
	if state.box_positions().size() != state.boxes.size():
		return false
	for box in state.boxes:
		var mass := float(box["mass"])
		if not is_finite(mass) or mass <= 0.0 or not level.is_walkable(box["position"]):
			return false
	for goal in level.goals:
		if not level.is_walkable(goal):
			return false
	return true

func _solution(key: String, parents: Dictionary, cost: float, started: int, expanded: int, discovered: int) -> Dictionary:
	var actions: Array[Vector2i] = []
	var energy := 0.0
	while parents.has(key):
		var link: Dictionary = parents[key]
		actions.append(link["direction"])
		energy += float(link["energy"])
		key = link["parent"]
	actions.reverse()
	var result := _result("solved", started, expanded, discovered)
	result["actions"] = actions
	result["moves"] = actions.size()
	result["cost"] = cost
	result["energy"] = energy
	return result

func _result(status: String, started: int, expanded: int, discovered: int) -> Dictionary:
	return {
		"status": status, "success": status == "solved",
		"actions": [], "moves": 0, "cost": INF, "energy": 0.0,
		"elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"expanded_states": expanded, "discovered_states": discovered
	}
