class_name SokobanHeuristics
extends RefCounted

## Manhattan distance heuristic
static func manhattan(state: BoardState, level: LevelData) -> float:
	var distance := 0.0
	for box in state.boxes:
		distance += _nearest_goal_distance(box["position"], level)
	return distance

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
	var max_push_distance := max_span if has_slippery_terrain else 1
	var cost_per_push := 1.0
	if energy_cost:
		cost_per_push = PhysicalModel.ROBOT_MASS * PhysicalModel.GRAVITY \
			* (min_friction if is_finite(min_friction) else 0.0) * PhysicalModel.TILE_SIZE_METERS
	return func(state: BoardState, board: LevelData) -> float:
		var pushes := 0.0
		for box in state.boxes:
			var distance := _nearest_goal_distance(box["position"], board)
			pushes += ceilf(distance / float(max_push_distance))
		return pushes * cost_per_push

static func _nearest_goal_distance(position: Vector2i, level: LevelData) -> float:
	var nearest := INF
	for goal in level.goals:
		nearest = minf(nearest, float(absi(position.x - goal.x) + absi(position.y - goal.y)))
	return nearest
