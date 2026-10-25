class_name PhysicalModel
extends RefCounted

const GRAVITY := 9.81
const ROBOT_MASS := 20.0
const TILE_SIZE_METERS := 1.0
const SLIPPERY_FRICTION_THRESHOLD := 0.10

const TERRAIN := {
	".": {"name": "drewno", "static_friction": 0.35, "kinetic_friction": 0.25},
	"G": {"name": "cel", "static_friction": 0.35, "kinetic_friction": 0.25},
	"I": {"name": "lod", "static_friction": 0.05, "kinetic_friction": 0.03},
	"S": {"name": "piasek", "static_friction": 0.75, "kinetic_friction": 0.65}
}

var robot_force: float

func _init(max_force: float = 300.0) -> void:
	robot_force = max_force

func terrain_for(tile: String) -> Dictionary:
	return TERRAIN.get(tile, TERRAIN["."])

func starting_force(box_mass: float, terrain_tile: String) -> float:
	var terrain: Dictionary = terrain_for(terrain_tile)
	return box_mass * GRAVITY * float(terrain["static_friction"])

func can_start_push(box_mass: float, terrain_tile: String) -> bool:
	return robot_force >= starting_force(box_mass, terrain_tile)

func walking_energy(position: Vector2i, level: LevelData) -> float:
	var terrain := terrain_for(level.tile_at(position))
	return ROBOT_MASS * GRAVITY * float(terrain["kinetic_friction"]) * TILE_SIZE_METERS

func move(state: BoardState, direction: Vector2i, level: LevelData) -> Dictionary:
	if direction not in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		return {"success": false, "reason": "Nieprawidlowy kierunek ruchu."}
	var destination := state.player_position + direction
	if not level.is_walkable(destination):
		return {"success": false, "reason": "Sciana blokuje przejscie."}
	var index := state.box_at(destination)
	var result: Dictionary
	if index >= 0:
		result = push_box(destination, direction, float(state.boxes[index]["mass"]), level, state.box_positions(index))
		if not result["success"]:
			return result
	else:
		var path: Array[Vector2i] = []
		result = {"success": true, "energy": walking_energy(state.player_position, level), "path": path}
	var next_state := state.copy()
	next_state.player_position = destination
	if index >= 0:
		next_state.boxes[index]["position"] = result["position"]
	result["state"] = next_state
	result["box_index"] = index
	return result

func push_box(
		box_position: Vector2i,
		direction: Vector2i,
		box_mass: float,
		level: LevelData,
		box_positions: Dictionary
	) -> Dictionary:
	var terrain_tile := level.tile_at(box_position)
	var terrain: Dictionary = terrain_for(terrain_tile)
	var required_force := starting_force(box_mass, terrain_tile)
	if robot_force < required_force:
		return {"success": false, "reason": "Za mala sila robota dla tej skrzyni."}

	var destination := box_position + direction
	if not level.is_walkable(destination) or box_positions.has(destination):
		return {"success": false, "reason": "Przeszkoda blokuje skrzynie."}

	var work := walking_energy(box_position - direction, level) \
		+ box_mass * GRAVITY * float(terrain["kinetic_friction"]) * TILE_SIZE_METERS

	var path: Array[Vector2i] = [destination]
	var current_terrain: Dictionary = terrain_for(level.tile_at(destination))

	var kinetic_energy := 0.0
	if float(current_terrain["kinetic_friction"]) < SLIPPERY_FRICTION_THRESHOLD:
		kinetic_energy = maxf(0.0, robot_force - required_force) * TILE_SIZE_METERS
	work += kinetic_energy
	while float(current_terrain["kinetic_friction"]) < SLIPPERY_FRICTION_THRESHOLD and kinetic_energy > 0.0:
		var next_position: Vector2i = path.back() + direction
		if not level.is_walkable(next_position) or box_positions.has(next_position):
			break
		path.append(next_position)
		current_terrain = terrain_for(level.tile_at(next_position))
		kinetic_energy -= box_mass * GRAVITY * float(current_terrain["kinetic_friction"]) * TILE_SIZE_METERS

	return {
		"success": true,
		"position": path.back(),
		"path": path,
		"energy": work,
		"terrain": terrain["name"]
	}
