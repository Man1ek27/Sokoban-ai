class_name LevelData
extends RefCounted

const FLOOR := "."
const WALL := "#"
const GOAL := "G"
const PLAYER := "P"
const BOX := "B"
const BOX_ON_GOAL := "*"
const BARREL := "O"
const ICE := "I"
const SAND := "S"
const PLATE := "_"
const DOOR := "D"
const RAMP_RIGHT := ">"
const RAMP_LEFT := "<"
const RAMP_UP := "^"
const RAMP_DOWN := "v"

const CRATE_KIND := "crate"
const BARREL_KIND := "barrel"
const DEFAULT_CRATE_MASS := 35.0
const DEFAULT_BARREL_MASS := 30.0
const DEFAULT_PLATE_MASS := 40.0

const RAMP_DIRECTIONS := {
	RAMP_RIGHT: Vector2i.RIGHT,
	RAMP_LEFT: Vector2i.LEFT,
	RAMP_UP: Vector2i.UP,
	RAMP_DOWN: Vector2i.DOWN
}

var tiles: Array[String] = []
var player_start := Vector2i.ZERO
var boxes: Array[Dictionary] = []
var goals: Array[Vector2i] = []
var plates: Array[Vector2i] = []
var doors: Array[Vector2i] = []
var robot_force := 300.0
## Minimum mass [kg] resting on every pressure plate for the doors to open.
var plate_mass := DEFAULT_PLATE_MASS
var name := ""
var description := ""

static func from_file(path: String) -> LevelData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Nie mozna otworzyc poziomu: %s" % path)
		return LevelData.new()

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Nieprawidlowy format poziomu: %s" % path)
		return LevelData.new()
	return from_dictionary(parsed)

static func from_dictionary(data: Dictionary) -> LevelData:
	var level := LevelData.new()
	level.robot_force = float(data.get("robot_force", 300.0))
	level.plate_mass = float(data.get("plate_mass", DEFAULT_PLATE_MASS))
	level.name = str(data.get("name", ""))
	level.description = str(data.get("description", ""))

	for row_value in data.get("map", []):
		var row := str(row_value)
		level.tiles.append(row)
		for x in row.length():
			var tile := row.substr(x, 1)
			var position := Vector2i(x, level.tiles.size() - 1)
			match tile:
				PLAYER:
					level.player_start = position
				BOX:
					level.boxes.append(_box(position, CRATE_KIND))
				BARREL:
					level.boxes.append(_box(position, BARREL_KIND))
				BOX_ON_GOAL:
					level.boxes.append(_box(position, CRATE_KIND))
					level.goals.append(position)
				GOAL:
					level.goals.append(position)
				PLATE:
					level.plates.append(position)
				DOOR:
					level.doors.append(position)

	for box_value in data.get("boxes", []):
		if box_value is Dictionary:
			var index := int(box_value.get("index", -1))
			if index >= 0 and index < level.boxes.size():
				level.boxes[index]["mass"] = float(box_value.get("mass", level.boxes[index]["mass"]))

	return level

static func _box(position: Vector2i, kind: String) -> Dictionary:
	var mass := DEFAULT_BARREL_MASS if kind == BARREL_KIND else DEFAULT_CRATE_MASS
	return {"position": position, "mass": mass, "kind": kind}

func is_inside(position: Vector2i) -> bool:
	return position.y >= 0 and position.y < tiles.size() \
		and position.x >= 0 and position.x < tiles[position.y].length()

func tile_at(position: Vector2i) -> String:
	if not is_inside(position):
		return WALL
	var tile := tiles[position.y].substr(position.x, 1)
	if tile == PLAYER or tile == BOX or tile == BOX_ON_GOAL or tile == BARREL:
		return FLOOR
	return tile

## Static walkability: walls only. Doors and ramps depend on the move,
## see PhysicalModel.entry_block_reason().
func is_walkable(position: Vector2i) -> bool:
	return tile_at(position) != WALL

func is_wall(position: Vector2i) -> bool:
	return tile_at(position) == WALL

func ramp_direction(position: Vector2i) -> Vector2i:
	return RAMP_DIRECTIONS.get(tile_at(position), Vector2i.ZERO)

func has_sliding_bodies() -> bool:
	for box in boxes:
		if box.get("kind", CRATE_KIND) == BARREL_KIND:
			return true
	return false
