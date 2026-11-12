class_name PhysicalModel
extends RefCounted

## Tile-based physical model shared by manual play, animation and the A* solver.
##
## Robot:  drive force is limited by the motor (robot_force) AND by wheel grip on
##         the tile it stands on: F_push = min(F_max, grip * m_robot * g).
##         On low-grip terrain (ice) the robot cannot brake and keeps sliding.
## Bodies: crates slide on friction, barrels roll (rolling resistance).
##         A body starts moving when F_push >= static resistance on its tile.
##         If it enters a tile where its kinetic resistance is low, the excess
##         force becomes kinetic energy E = (F_push - F_static) * d and the body
##         glides on while it stays on slippery tiles, paying
##         m * g * (mu_k(from) + mu_k(to)) / 2 * d per tile. It stops on the first
##         rough tile it can still reach, in front of an obstacle, or when the
##         energy runs out.
## Tiles:  pressure plates open all doors when each plate carries >= plate_mass,
##         one-way ramps can be entered only in their arrow direction.

const GRAVITY := 9.81
const ROBOT_MASS := 40.0
const TILE_SIZE_METERS := 1.0
## A body glides when its kinetic resistance on the entered tile is below this value.
const SLIPPERY_FRICTION_THRESHOLD := 0.10
## The robot cannot brake on tiles where its wheel grip is below this value.
const ROBOT_SLIP_GRIP := 0.2

const WOOD := {
	"name": "drewno", "static_friction": 0.35, "kinetic_friction": 0.25,
	"grip": 0.9, "rolling_resistance": 0.015
}
const TERRAIN := {
	".": WOOD,
	"G": {"name": "cel", "static_friction": 0.35, "kinetic_friction": 0.25, "grip": 0.9, "rolling_resistance": 0.015},
	"I": {"name": "lód", "static_friction": 0.05, "kinetic_friction": 0.03, "grip": 0.1, "rolling_resistance": 0.01},
	"S": {"name": "piasek", "static_friction": 0.75, "kinetic_friction": 0.65, "grip": 0.6, "rolling_resistance": 0.30},
	"_": {"name": "płyta naciskowa", "static_friction": 0.35, "kinetic_friction": 0.25, "grip": 0.9, "rolling_resistance": 0.015},
	"D": {"name": "drzwi", "static_friction": 0.35, "kinetic_friction": 0.25, "grip": 0.9, "rolling_resistance": 0.015},
	">": {"name": "uskok", "static_friction": 0.35, "kinetic_friction": 0.25, "grip": 0.9, "rolling_resistance": 0.015},
	"<": {"name": "uskok", "static_friction": 0.35, "kinetic_friction": 0.25, "grip": 0.9, "rolling_resistance": 0.015},
	"^": {"name": "uskok", "static_friction": 0.35, "kinetic_friction": 0.25, "grip": 0.9, "rolling_resistance": 0.015},
	"v": {"name": "uskok", "static_friction": 0.35, "kinetic_friction": 0.25, "grip": 0.9, "rolling_resistance": 0.015}
}
## Barrel resistance to start rolling, relative to its rolling resistance.
const BARREL_STATIC_FACTOR := 2.0
const DIRECTIONS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var robot_force: float

func _init(max_force: float = 300.0) -> void:
	robot_force = max_force

func terrain_for(tile: String) -> Dictionary:
	return TERRAIN.get(tile, WOOD)

## Static and kinetic resistance coefficients of a body kind on a tile.
func resistance(kind: String, tile: String) -> Dictionary:
	var terrain := terrain_for(tile)
	if kind == LevelData.BARREL_KIND:
		var rolling := float(terrain["rolling_resistance"])
		return {"static": rolling * BARREL_STATIC_FACTOR, "kinetic": rolling}
	return {"static": float(terrain["static_friction"]), "kinetic": float(terrain["kinetic_friction"])}

func starting_force(box_mass: float, terrain_tile: String, kind: String = LevelData.CRATE_KIND) -> float:
	return box_mass * GRAVITY * float(resistance(kind, terrain_tile)["static"])

## Maximum horizontal force the robot can transmit while standing on a tile.
func traction_force(robot_tile: String) -> float:
	return float(terrain_for(robot_tile)["grip"]) * ROBOT_MASS * GRAVITY

func push_force(robot_tile: String) -> float:
	return minf(robot_force, traction_force(robot_tile))

func can_start_push(box_mass: float, terrain_tile: String, robot_tile: String = ".", kind: String = LevelData.CRATE_KIND) -> bool:
	return push_force(robot_tile) >= starting_force(box_mass, terrain_tile, kind)

func robot_slides_on(tile: String) -> bool:
	return float(terrain_for(tile)["grip"]) < ROBOT_SLIP_GRIP

func walking_energy(position: Vector2i, level: LevelData) -> float:
	var terrain := terrain_for(level.tile_at(position))
	return ROBOT_MASS * GRAVITY * float(terrain["kinetic_friction"]) * TILE_SIZE_METERS

## Doors are open while every plate carries at least level.plate_mass of boxes.
## `masses` maps positions to the resting mass (moving bodies excluded).
func doors_open(level: LevelData, masses: Dictionary) -> bool:
	if level.plates.is_empty():
		return false
	for plate in level.plates:
		if float(masses.get(plate, 0.0)) < level.plate_mass:
			return false
	return true

## Returns "" when a body moving in `direction` may enter `position`,
## otherwise a human-readable reason. Occupancy by boxes is checked separately.
func entry_block_reason(position: Vector2i, direction: Vector2i, level: LevelData, masses: Dictionary) -> String:
	var tile := level.tile_at(position)
	if tile == LevelData.WALL:
		return "Ściana blokuje przejście."
	if tile == LevelData.DOOR and not doors_open(level, masses):
		return "Drzwi są zamknięte: płyty potrzebują nacisku %.0f kg." % level.plate_mass
	var ramp := level.ramp_direction(position)
	if ramp != Vector2i.ZERO and ramp != direction:
		return "Na uskok można wjechać tylko zgodnie ze strzałką."
	return ""

func move(state: BoardState, direction: Vector2i, level: LevelData) -> Dictionary:
	if direction not in DIRECTIONS:
		return {"success": false, "reason": "Nieprawidłowy kierunek ruchu."}
	var destination := state.player_position + direction
	var index := state.box_at(destination)
	var result: Dictionary
	if index >= 0:
		result = push_box(state, index, direction, level)
		if not result["success"]:
			return result
		var robot_path_after_push: Array[Vector2i] = [destination]
		result["robot_path"] = robot_path_after_push
	else:
		result = walk(state, direction, level)
		if not result["success"]:
			return result
	var robot_path: Array[Vector2i] = result["robot_path"]
	var next_state := state.copy()
	next_state.player_position = robot_path.back()
	if index >= 0:
		next_state.boxes[index]["position"] = result["position"]
	result["state"] = next_state
	result["box_index"] = index
	return result

func walk(state: BoardState, direction: Vector2i, level: LevelData) -> Dictionary:
	var masses := state.mass_at_positions()
	var destination := state.player_position + direction
	var reason := entry_block_reason(destination, direction, level, masses)
	if reason != "":
		return {"success": false, "reason": reason}
	var path: Array[Vector2i] = [destination]
	# Without grip the robot keeps its momentum until it reaches a tile it can brake on.
	while robot_slides_on(level.tile_at(path.back())):
		var next_position: Vector2i = path.back() + direction
		if entry_block_reason(next_position, direction, level, masses) != "" or masses.has(next_position):
			break
		path.append(next_position)
	var terrain_name := str(terrain_for(level.tile_at(path.back()))["name"])
	var box_path: Array[Vector2i] = []
	return {
		"success": true,
		"energy": walking_energy(state.player_position, level),
		"robot_path": path,
		"path": box_path,
		"slid": path.size() > 1,
		"terrain": terrain_name
	}

func push_box(state: BoardState, index: int, direction: Vector2i, level: LevelData) -> Dictionary:
	var box: Dictionary = state.boxes[index]
	var box_position: Vector2i = box["position"]
	var box_mass := float(box["mass"])
	var kind := str(box.get("kind", LevelData.CRATE_KIND))
	var robot_tile := level.tile_at(state.player_position)
	var box_tile := level.tile_at(box_position)
	var force := push_force(robot_tile)
	var required_force := starting_force(box_mass, box_tile, kind)
	if force < required_force:
		if traction_force(robot_tile) < robot_force:
			return {"success": false, "reason": "Koła ślizgają się na podłożu %s: maks. %.0f N, potrzeba %.0f N." % [
				terrain_for(robot_tile)["name"], force, required_force]}
		return {"success": false, "reason": "Za mała siła robota: Fmax %.0f N, potrzeba %.0f N." % [force, required_force]}

	# The robot follows the box into its old tile, so that tile must accept the robot.
	var follow_ramp := level.ramp_direction(box_position)
	if follow_ramp != Vector2i.ZERO and follow_ramp != direction:
		return {"success": false, "reason": "Robot nie wjedzie na uskok pod prąd."}

	var masses := state.mass_at_positions(index)
	var destination := box_position + direction
	if masses.has(destination):
		return {"success": false, "reason": "Przeszkoda blokuje skrzynię."}
	var reason := entry_block_reason(destination, direction, level, masses)
	if reason != "":
		return {"success": false, "reason": reason}

	var start_resistance := resistance(kind, box_tile)
	var work := walking_energy(state.player_position, level) \
		+ box_mass * GRAVITY * float(start_resistance["kinetic"]) * TILE_SIZE_METERS

	var path: Array[Vector2i] = [destination]
	var current_mu := float(resistance(kind, level.tile_at(destination))["kinetic"])
	var kinetic_energy := 0.0
	if current_mu < SLIPPERY_FRICTION_THRESHOLD:
		kinetic_energy = maxf(0.0, force - required_force) * TILE_SIZE_METERS
	work += kinetic_energy
	# The body glides only over slippery tiles; the first rough tile catches it.
	# Moving centre to centre costs half a tile of friction on each surface.
	while kinetic_energy > 0.0 and current_mu < SLIPPERY_FRICTION_THRESHOLD:
		var next_position: Vector2i = path.back() + direction
		if masses.has(next_position) or entry_block_reason(next_position, direction, level, masses) != "":
			break
		var next_mu := float(resistance(kind, level.tile_at(next_position))["kinetic"])
		var step_cost := box_mass * GRAVITY * (current_mu + next_mu) * 0.5 * TILE_SIZE_METERS
		if kinetic_energy < step_cost:
			break
		kinetic_energy -= step_cost
		path.append(next_position)
		current_mu = next_mu

	return {
		"success": true,
		"position": path.back(),
		"path": path,
		"energy": work,
		"force": force,
		"required_force": required_force,
		"slid": path.size() > 1,
		"terrain": terrain_for(box_tile)["name"]
	}
