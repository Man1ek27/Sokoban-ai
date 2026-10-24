extends Node2D

const TILE_SIZE := 56.0
const BOARD_ORIGIN := Vector2(28.0, 76.0)
const MOVE_DURATION := 0.18
const SLIDE_STEP_DURATION := 0.12
const LEVEL_PATHS := [
	"res://levels/demo_level.json",
	"res://levels/win_test.json"
]

@onready var hud: GameHud = $HUD

var level: LevelData
var physics: PhysicalModel
var player_position := Vector2i.ZERO
var visual_player_position := Vector2.ZERO
var boxes: Array[Dictionary] = []
var visual_box_positions: Array[Vector2] = []
var active_tween: Tween
var moves := 0
var energy := 0.0
var status := "Poruszaj sie strzalkami lub WASD."
var selected_level_index := 0
var is_completed := false
var is_animating := false
var pending_victory := false

func _ready() -> void:
	hud.reset_requested.connect(_reset_level)
	hud.level_selected.connect(_select_level)
	_load_level()
	queue_redraw()

func _load_level() -> void:
	_cancel_animations()
	hud.hide_victory()
	level = LevelData.from_file(LEVEL_PATHS[selected_level_index])
	physics = PhysicalModel.new(level.robot_force)
	player_position = level.player_start
	visual_player_position = Vector2(player_position)
	boxes = level.boxes.duplicate(true)
	visual_box_positions.clear()
	for box in boxes:
		visual_box_positions.append(Vector2(box["position"]))
	moves = 0
	energy = 0.0
	status = "Poruszaj sie strzalkami lub WASD."
	is_completed = false
	_update_hud()

func _cancel_animations() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
	is_animating = false
	pending_victory = false

func _select_level(index: int) -> void:
	if index < 0 or index >= LEVEL_PATHS.size():
		return
	selected_level_index = index
	_reset_level()

func _reset_level() -> void:
	_load_level()
	queue_redraw()

func _update_hud() -> void:
	hud.update_state(moves, energy, physics.robot_force, status)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_UP, KEY_W:
			direction = Vector2i.UP
		KEY_DOWN, KEY_S:
			direction = Vector2i.DOWN
		KEY_LEFT, KEY_A:
			direction = Vector2i.LEFT
		KEY_RIGHT, KEY_D:
			direction = Vector2i.RIGHT
		KEY_R:
			_reset_level()
			return
	if direction != Vector2i.ZERO:
		_try_move(direction)

func _try_move(direction: Vector2i) -> void:
	if is_completed or is_animating:
		return
	var result := physics.move(BoardState.new(player_position, boxes), direction, level)
	if bool(result["success"]):
		var next_state: BoardState = result["state"]
		player_position = next_state.player_position
		boxes = next_state.boxes
		moves += 1
		energy += float(result["energy"])
		var box_index: int = result["box_index"]
		if box_index >= 0:
			status = "Pchnieto skrzynie po podlozu: %s." % result["terrain"]
			pending_victory = _is_level_solved()
			_animate_push(box_index, result["path"])
		else:
			status = "Ruch wykonany."
			_animate_player()
	else:
		status = str(result["reason"])
	_update_hud()
	queue_redraw()

func _animate_player() -> void:
	is_animating = true
	var player_tween := create_tween()
	active_tween = player_tween
	player_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	player_tween.tween_method(_set_visual_player_position, visual_player_position, Vector2(player_position), MOVE_DURATION)
	player_tween.finished.connect(_finish_animation)

func _animate_push(box_index: int, path: Array[Vector2i]) -> void:
	is_animating = true
	var push_tween := create_tween()
	active_tween = push_tween
	push_tween.tween_method(_set_visual_player_position, visual_player_position, Vector2(player_position), MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	push_tween.parallel().tween_method(_set_visual_box_position.bind(box_index), visual_box_positions[box_index], Vector2(path[0]), MOVE_DURATION)
	var start_position := Vector2(path[0])
	for step_index in range(1, path.size()):
		var end_position := Vector2(path[step_index])
		push_tween.tween_method(_set_visual_box_position.bind(box_index), start_position, end_position, SLIDE_STEP_DURATION)
		start_position = end_position
	push_tween.finished.connect(_finish_animation)

func _set_visual_player_position(visual_position: Vector2) -> void:
	visual_player_position = visual_position
	queue_redraw()

func _set_visual_box_position(visual_position: Vector2, box_index: int) -> void:
	visual_box_positions[box_index] = visual_position
	queue_redraw()

func _finish_animation() -> void:
	is_animating = false
	active_tween = null
	visual_player_position = Vector2(player_position)
	for box_index in boxes.size():
		visual_box_positions[box_index] = Vector2(boxes[box_index]["position"])
	if pending_victory:
		pending_victory = false
		is_completed = true
		status = "Poziom ukończony!"
		_update_hud()
		hud.show_victory(moves, energy)
	queue_redraw()

func _is_level_solved() -> bool:
	if boxes.is_empty() or level.goals.is_empty() or boxes.size() != level.goals.size():
		return false
	for box in boxes:
		if not level.goals.has(box["position"]):
			return false
	return true

func _box_positions() -> Dictionary:
	var positions := {}
	for box in boxes:
		positions[box["position"]] = true
	return positions

func _box_at(position: Vector2i) -> int:
	for index in boxes.size():
		if boxes[index]["position"] == position:
			return index
	return -1

func _draw() -> void:
	draw_rect(Rect2(0, 0, 900, 680), Color("#17212b"))
	draw_string(ThemeDB.fallback_font, Vector2(28, 34), "SOKOBAN - model fizyczny", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#f0f4f8"))
	draw_string(ThemeDB.fallback_font, Vector2(28, 58), "WASD / strzalki: ruch   R: reset", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a9bac8"))

	for y in level.tiles.size():
		for x in level.tiles[y].length():
			_draw_tile(Vector2i(x, y))
	for goal in level.goals:
		_draw_goal(goal)
	for box_index in boxes.size():
		_draw_box(visual_box_positions[box_index], float(boxes[box_index]["mass"]))
	_draw_player(visual_player_position)

func _draw_tile(position: Vector2i) -> void:
	var tile := level.tile_at(position)
	var color := Color("#c59b6d")
	if tile == "#":
		color = Color("#34495e")
	elif tile == "I":
		color = Color("#73b7d8")
	elif tile == "S":
		color = Color("#c88b50")
	elif tile == "G":
		color = Color("#bb9bde")
	var rect := Rect2(BOARD_ORIGIN + Vector2(position) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
	draw_rect(rect, color)
	draw_rect(rect, Color("#17212b"), false, 2.0)

func _draw_goal(position: Vector2i) -> void:
	var center := BOARD_ORIGIN + Vector2(position) * TILE_SIZE + Vector2.ONE * TILE_SIZE / 2.0
	draw_circle(center, 12.0, Color("#f4d35e"))
	draw_circle(center, 7.0, Color("#bb9b6d"))

func _draw_box(position: Vector2, mass: float) -> void:
	var rect := Rect2(BOARD_ORIGIN + position * TILE_SIZE + Vector2(9, 9), Vector2.ONE * (TILE_SIZE - 18))
	draw_rect(rect, Color("#9b542f"))
	draw_rect(rect, Color("#f0b27a"), false, 3.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 26), "%d kg" % mass, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fff3e0"))

func _draw_player(position: Vector2) -> void:
	var center := BOARD_ORIGIN + position * TILE_SIZE + Vector2.ONE * TILE_SIZE / 2.0
	draw_circle(center, 17.0, Color("#49d17d"))
	draw_circle(center + Vector2(0, -5), 8.0, Color("#d9f7e3"))
	draw_line(center + Vector2(-10, 10), center + Vector2(10, 10), Color("#116b45"), 4.0)
