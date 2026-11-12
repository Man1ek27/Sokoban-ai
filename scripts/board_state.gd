class_name BoardState
extends RefCounted

var player_position: Vector2i
var boxes: Array[Dictionary] = []

func _init(robot_position: Vector2i = Vector2i.ZERO, state_boxes: Array[Dictionary] = []) -> void:
	player_position = robot_position
	for box in state_boxes:
		boxes.append({
			"position": box["position"],
			"mass": float(box["mass"]),
			"kind": str(box.get("kind", LevelData.CRATE_KIND))
		})

static func from_level(level: LevelData) -> BoardState:
	return BoardState.new(level.player_start, level.boxes)

func copy() -> BoardState:
	return BoardState.new(player_position, boxes)

func state_key() -> String:
	var entries: Array[String] = []
	for box in boxes:
		var position: Vector2i = box["position"]
		entries.append("%d,%d,%s,%s" % [position.x, position.y, float(box["mass"]), box["kind"]])
	entries.sort()
	return "%d,%d|%s" % [player_position.x, player_position.y, "|".join(entries)]

func box_at(position: Vector2i) -> int:
	for index in boxes.size():
		if boxes[index]["position"] == position:
			return index
	return -1

func box_positions(excluded_index: int = -1) -> Dictionary:
	var positions := {}
	for index in boxes.size():
		if index != excluded_index:
			positions[boxes[index]["position"]] = true
	return positions

## Total mass [kg] resting on each position, optionally ignoring one moving box.
func mass_at_positions(excluded_index: int = -1) -> Dictionary:
	var masses := {}
	for index in boxes.size():
		if index != excluded_index:
			var position: Vector2i = boxes[index]["position"]
			masses[position] = float(masses.get(position, 0.0)) + float(boxes[index]["mass"])
	return masses

## Solved when every goal holds a box. Extra boxes (e.g. plate weights) may stay anywhere.
func is_solved(level: LevelData) -> bool:
	if boxes.is_empty() or level.goals.is_empty() or boxes.size() < level.goals.size():
		return false
	var positions := box_positions()
	for goal in level.goals:
		if not positions.has(goal):
			return false
	return true
