class_name BoardState
extends RefCounted

var player_position: Vector2i
var boxes: Array[Dictionary] = []

func _init(robot_position: Vector2i = Vector2i.ZERO, state_boxes: Array[Dictionary] = []) -> void:
	player_position = robot_position
	for box in state_boxes:
		boxes.append({"position": box["position"], "mass": float(box["mass"])})

static func from_level(level: LevelData) -> BoardState:
	return BoardState.new(level.player_start, level.boxes)

func copy() -> BoardState:
	return BoardState.new(player_position, boxes)

func state_key() -> String:
	var entries: Array[String] = []
	for box in boxes:
		var position: Vector2i = box["position"]
		entries.append(var_to_bytes([position.x, position.y, float(box["mass"])]).hex_encode())
	entries.sort()
	return var_to_bytes([player_position.x, player_position.y, entries]).hex_encode()

func box_at(position: Vector2i) -> int:
	for index in boxes.size():
		if boxes[index]["position"] == position:
			return index
	return -1

## Compatible with PhysicalModel.push_box; exclude the box being pushed.
func box_positions(excluded_index: int = -1) -> Dictionary:
	var positions := {}
	for index in boxes.size():
		if index != excluded_index:
			positions[boxes[index]["position"]] = true
	return positions

func is_solved(level: LevelData) -> bool:
	if boxes.is_empty() or boxes.size() != level.goals.size():
		return false
	var positions := box_positions()
	if positions.size() != boxes.size():
		return false
	for goal in level.goals:
		if not positions.has(goal):
			return false
	return true
