class_name LevelData
extends RefCounted

const FLOOR := "."
const WALL := "#"
const GOAL := "G"
const PLAYER := "P"
const BOX := "B"
const BOX_ON_GOAL := "*"
const ICE := "I"
const SAND := "S"

var tiles: Array[String] = []
var player_start := Vector2i.ZERO
var boxes: Array[Dictionary] = []
var goals: Array[Vector2i] = []
var robot_force := 300.0

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
					level.boxes.append({"position": position, "mass": 35.0})
				BOX_ON_GOAL:
					level.boxes.append({"position": position, "mass": 35.0})
					level.goals.append(position)
				GOAL:
					level.goals.append(position)

	for box_value in data.get("boxes", []):
		if box_value is Dictionary:
			var index := int(box_value.get("index", -1))
			if index >= 0 and index < level.boxes.size():
				level.boxes[index]["mass"] = float(box_value.get("mass", 35.0))

	return level

func is_inside(position: Vector2i) -> bool:
	return position.y >= 0 and position.y < tiles.size() \
		and position.x >= 0 and position.x < tiles[position.y].length()

func tile_at(position: Vector2i) -> String:
	if not is_inside(position):
		return WALL
	var tile := tiles[position.y].substr(position.x, 1)
	if tile == PLAYER or tile == BOX or tile == BOX_ON_GOAL:
		return FLOOR
	return tile

func is_walkable(position: Vector2i) -> bool:
	return tile_at(position) != WALL
