extends Node2D

const TILE_SIZE := 56.0
const BOARD_ORIGIN := Vector2(28.0, 76.0)
const LEVEL_PATH := "res://levels/demo_level.json"

@onready var hud: GameHud = $HUD

var level: LevelData
var physics: PhysicalModel
var player_position := Vector2i.ZERO
var boxes: Array[Dictionary] = []
var moves := 0
var energy := 0.0
var status := "Poruszaj sie strzalkami lub WASD."

func _ready() -> void:
	hud.reset_requested.connect(_reset_level)
	_load_level()
	queue_redraw()

func _load_level() -> void:
	level = LevelData.from_file(LEVEL_PATH)
	physics = PhysicalModel.new(level.robot_force)
	player_position = level.player_start
	boxes = level.boxes.duplicate(true)
	moves = 0
	energy = 0.0
	status = "Poruszaj sie strzalkami lub WASD."
	_update_hud()

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
	var next_position := player_position + direction
	var box_index := _box_at(next_position)
	if box_index == -1:
		if level.is_walkable(next_position):
			player_position = next_position
			moves += 1
			status = "Ruch wykonany."
		else:
			status = "Sciana blokuje przejscie."
	else:
		var occupied := _box_positions()
		var box: Dictionary = boxes[box_index]
		occupied.erase(next_position)
		var result := physics.push_box(
			next_position,
			direction,
			float(box["mass"]),
			level,
			occupied
		)
		if bool(result["success"]):
			boxes[box_index]["position"] = result["position"]
			player_position = next_position
			moves += 1
			energy += float(result["energy"])
			status = "Pchnieto skrzynie po podlozu: %s." % result["terrain"]
		else:
			status = str(result["reason"])
	_update_hud()
	queue_redraw()

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
	for box in boxes:
		_draw_box(box["position"], float(box["mass"]))
	_draw_player(player_position)

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

func _draw_box(position: Vector2i, mass: float) -> void:
	var rect := Rect2(BOARD_ORIGIN + Vector2(position) * TILE_SIZE + Vector2(9, 9), Vector2.ONE * (TILE_SIZE - 18))
	draw_rect(rect, Color("#9b542f"))
	draw_rect(rect, Color("#f0b27a"), false, 3.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 26), "%d kg" % mass, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fff3e0"))

func _draw_player(position: Vector2i) -> void:
	var center := BOARD_ORIGIN + Vector2(position) * TILE_SIZE + Vector2.ONE * TILE_SIZE / 2.0
	draw_circle(center, 17.0, Color("#49d17d"))
	draw_circle(center + Vector2(0, -5), 8.0, Color("#d9f7e3"))
	draw_line(center + Vector2(-10, 10), center + Vector2(10, 10), Color("#116b45"), 4.0)
