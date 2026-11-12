class_name SokobanHeuristics
extends RefCounted

const Queue = preload("res://scripts/min_priority_queue.gd")

## Manhattan distance heuristic. With more boxes than goals only the
## goals.size() boxes closest to a goal are counted, which keeps it admissible.
static func manhattan(state: BoardState, level: LevelData) -> float:
	var distances: Array[float] = []
	for box in state.boxes:
		distances.append(_nearest_goal_distance(box["position"], level))
	return _sum_smallest(distances, level.goals.size())

### Manhattan distance heuristic, scaled for sliding and the chosen cost units
static func manhattan_for(level: LevelData, energy_cost: bool = false) -> Callable:
	var physics := PhysicalModel.new(level.robot_force)
	var max_span := maxi(1, level.tiles.size() - 1)
	var has_slippery_terrain := false
	var min_friction := INF
	for y in level.tiles.size():
		max_span = maxi(max_span, level.tiles[y].length() - 1)
		for x in level.tiles[y].length():
			var position := Vector2i(x, y)
			if not level.is_walkable(position):
				continue
			var terrain := physics.terrain_for(level.tile_at(position))
			var friction := float(terrain["kinetic_friction"])
			min_friction = minf(min_friction, friction)
			if friction < PhysicalModel.SLIPPERY_FRICTION_THRESHOLD:
				has_slippery_terrain = true
	# Barrels roll on ordinary floor, so one push may also move them several tiles.
	var max_push_distance := max_span if has_slippery_terrain or level.has_sliding_bodies() else 1
	var cost_per_push := 1.0
	if energy_cost:
		cost_per_push = PhysicalModel.ROBOT_MASS * PhysicalModel.GRAVITY \
			* (min_friction if is_finite(min_friction) else 0.0) * PhysicalModel.TILE_SIZE_METERS
	return func(state: BoardState, board: LevelData) -> float:
		var pushes: Array[float] = []
		for box in state.boxes:
			var distance := _nearest_goal_distance(box["position"], board)
			pushes.append(ceilf(distance / float(max_push_distance)))
		return _sum_smallest(pushes, board.goals.size()) * cost_per_push

## h2: count optimistic pushes separately for crates and barrels. In ENERGY,
## charge the minimum work of the robot and of the body being pushed.
static func weighted_for(level: LevelData, energy_cost: bool = false) -> Callable:
	var physics := PhysicalModel.new(level.robot_force)
	var max_span := maxi(1, level.tiles.size() - 1)
	var min_robot_work := INF
	var min_resistance := {LevelData.CRATE_KIND: INF, LevelData.BARREL_KIND: INF}
	for y in level.tiles.size():
		max_span = maxi(max_span, level.tiles[y].length() - 1)
		for x in level.tiles[y].length():
			var position := Vector2i(x, y)
			if level.is_wall(position):
				continue
			var tile := level.tile_at(position)
			min_robot_work = minf(min_robot_work, physics.walking_energy(position, level))
			for kind in min_resistance:
				var resistance := float(physics.resistance(kind, tile)["kinetic"])
				min_resistance[kind] = minf(min_resistance[kind], resistance)
	return func(state: BoardState, board: LevelData) -> float:
		var estimates: Array[float] = []
		for box in state.boxes:
			var kind := str(box["kind"])
			var resistance := float(min_resistance.get(kind, min_resistance[LevelData.CRATE_KIND]))
			var span := max_span if resistance < PhysicalModel.SLIPPERY_FRICTION_THRESHOLD else 1
			var pushes := ceilf(_nearest_goal_distance(box["position"], board) / span)
			if energy_cost:
				var body_work := float(box["mass"]) * PhysicalModel.GRAVITY * resistance * PhysicalModel.TILE_SIZE_METERS
				pushes *= min_robot_work + body_work
			estimates.append(pushes)
		return _sum_smallest(estimates, board.goals.size())

## h3: shortest paths in a relaxed push graph per (kind, mass). Ignore the
## robot's route to the push and open all doors. Every prefix of a glide is
## legal in the graph because another body or a closed door may stop it early.
static func terrain_aware_for(level: LevelData, energy_cost: bool = false) -> Callable:
	var physics := PhysicalModel.new(level.robot_force)
	var fallback := weighted_for(level, energy_cost)
	var distances_by_body := {}
	return func(state: BoardState, board: LevelData) -> float:
		var estimates: Array[float] = []
		for box in state.boxes:
			var body := [box["kind"], box["mass"]]
			if not distances_by_body.has(body):
				distances_by_body[body] = _relaxed_goal_distances(board, physics, body[0], body[1], energy_cost)
			var distances: Dictionary = distances_by_body[body]
			if distances.has(box["position"]):
				estimates.append(distances[box["position"]])
		# The solver's Callable contract requires a finite value, even for dead states.
		if estimates.size() < board.goals.size():
			return fallback.call(state, board)
		return _sum_smallest(estimates, board.goals.size())

static func for_name(name: String, level: LevelData, energy_cost: bool = false) -> Callable:
	match name:
		"h1":
			return manhattan_for(level, energy_cost)
		"h2":
			return weighted_for(level, energy_cost)
		"h3":
			return terrain_aware_for(level, energy_cost)
		"dijkstra":
			return func(_state: BoardState, _board: LevelData) -> float: return 0.0
	return Callable()

static func _relaxed_goal_distances(
		level: LevelData, physics: PhysicalModel, kind: String, mass: float, energy_cost: bool
	) -> Dictionary:
	var incoming := {}
	var isolated := BoardState.new(Vector2i.ZERO, [{"position": Vector2i.ZERO, "mass": mass, "kind": kind}])
	for y in level.tiles.size():
		for x in level.tiles[y].length():
			var origin := Vector2i(x, y)
			if level.is_wall(origin):
				continue
			isolated.boxes[0]["position"] = origin
			for direction in PhysicalModel.DIRECTIONS:
				isolated.player_position = origin - direction
				if level.is_wall(isolated.player_position):
					continue
				var push := physics.push_box(isolated, 0, direction, level, true)
				if not push["success"]:
					continue
				var cost := float(push["energy"]) if energy_cost else 1.0
				for destination in push["path"]:
					if not incoming.has(destination):
						incoming[destination] = []
					incoming[destination].append({"origin": origin, "cost": cost})

	var distances := {}
	var frontier := Queue.new()
	for goal in level.goals:
		distances[goal] = 0.0
		frontier.push({"position": goal, "cost": 0.0}, 0.0)
	while not frontier.is_empty():
		var current: Dictionary = frontier.pop()
		var position: Vector2i = current["position"]
		var cost: float = current["cost"]
		if cost != float(distances[position]):
			continue
		for edge in incoming.get(position, []):
			var origin: Vector2i = edge["origin"]
			var candidate := cost + float(edge["cost"])
			if candidate < float(distances.get(origin, INF)):
				distances[origin] = candidate
				frontier.push({"position": origin, "cost": candidate}, candidate)
	return distances

static func _nearest_goal_distance(position: Vector2i, level: LevelData) -> float:
	var nearest := INF
	for goal in level.goals:
		nearest = minf(nearest, float(absi(position.x - goal.x) + absi(position.y - goal.y)))
	return nearest

static func _sum_smallest(values: Array[float], count: int) -> float:
	if values.size() > count:
		values.sort()
		values.resize(count)
	var total := 0.0
	for value in values:
		total += value
	return total
