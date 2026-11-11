extends Node2D

const TILE_SIZE := 56.0
const BOARD_ORIGIN := Vector2(48.0, 164.0)
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
var status := "Poruszaj się strzałkami lub WASD."
var selected_level_index := 0
var is_completed := false
var is_animating := false
var pending_victory := false
var ai_plan: Array[Vector2i] = []
var ai_action_index := 0
var ai_playing := false
var ai_planning := false
var ai_generation := 0
# One entry per action; computed once on a detached board, then drawn as a suffix.
var ai_preview: Array[Dictionary] = []
var drawing_styles: Dictionary = {}

func _ready() -> void:
	hud.reset_requested.connect(_reset_level)
	hud.level_selected.connect(_select_level)
	hud.ai_solve_requested.connect(_start_ai)
	hud.ai_stop_requested.connect(_stop_ai)
	hud.robot_force_changed.connect(_change_robot_force)
	hud.ai_settings_changed.connect(_cancel_ai)
	_load_level()
	queue_redraw()

func _load_level() -> void:
	_cancel_ai()
	_cancel_animations()
	hud.hide_victory()
	hud.clear_ai_result()
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
	status = "Poruszaj się strzałkami lub WASD."
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

func _cancel_ai() -> void:
	ai_generation += 1
	ai_planning = false
	ai_playing = false
	ai_plan.clear()
	ai_preview.clear()
	ai_action_index = 0
	_update_ai_controls()
	queue_redraw()

func _update_ai_controls() -> void:
	hud.set_ai_activity(ai_planning, ai_playing, is_animating)

func _change_robot_force(force: float) -> void:
	if ai_planning or ai_playing or is_animating:
		_update_hud()
		return
	if not is_finite(force) or force < 0.0:
		_update_hud()
		return
	if force == level.robot_force:
		return
	_cancel_ai()
	level.robot_force = force
	physics.robot_force = force
	hud.clear_ai_result()
	status = "Zmieniono Fmax. Reset przywróci siłę z poziomu."
	_update_hud()

func _stop_ai() -> void:
	if not ai_playing:
		return
	_cancel_ai()
	hud.set_ai_status("Odtwarzanie zatrzymane.")

func _start_ai(cost_mode: int, heuristic_id: int = GameHud.Heuristic.H1) -> void:
	if ai_planning or ai_playing or is_animating:
		return
	if is_completed:
		hud.set_ai_status("Poziom jest już ukończony.")
		return
	var heuristic := _heuristic_for(heuristic_id, cost_mode)
	if not heuristic.is_valid():
		hud.set_ai_status("Wybrana heurystyka nie jest jeszcze dostępna.")
		return
	_cancel_ai()
	ai_planning = true
	_update_ai_controls()
	var run_generation := ai_generation
	hud.clear_ai_result()
	hud.set_ai_status("Planowanie...")
	# Let the status reach the viewport before synchronous search blocks this thread.
	await get_tree().process_frame
	if run_generation != ai_generation:
		return
	var initial_state := BoardState.new(player_position, boxes)
	var result: Dictionary = AStarSolver.new().solve(
		level, initial_state, cost_mode, heuristic, 100000, 30000
	)
	if run_generation != ai_generation:
		return
	ai_planning = false
	_update_ai_controls()
	hud.show_ai_result(result, cost_mode, heuristic_id)
	if not bool(result["success"]):
		return
	ai_plan.assign(result["actions"])
	ai_action_index = 0
	if not _build_ai_preview(initial_state):
		_cancel_ai()
		hud.set_ai_status("Plan odrzucony: niespójny z przejściami fizyki.")
		return
	if ai_plan.is_empty():
		hud.set_ai_status("Plan ukończony: plansza jest już rozwiązana.")
		return
	ai_playing = true
	_update_ai_controls()
	hud.set_ai_status("Odtwarzanie planu: 0/%d" % ai_plan.size())
	_play_next_ai_action()

func _heuristic_for(heuristic_id: int, cost_mode: int) -> Callable:
	# Future h2/h3 factories must return Callable(state: BoardState, level: LevelData).
	match heuristic_id:
		GameHud.Heuristic.H1:
			return SokobanHeuristics.manhattan_for(level, cost_mode == AStarSolver.CostMode.ENERGY)
	return Callable()

func _build_ai_preview(initial_state: BoardState) -> bool:
	ai_preview.clear()
	var simulated := initial_state.copy()
	for direction in ai_plan:
		var result := physics.move(simulated, direction, level)
		if not bool(result["success"]):
			ai_preview.clear()
			return false
		var next_state: BoardState = result["state"]
		var box_path: Array[Vector2i] = []
		var box_index := int(result["box_index"])
		if box_index >= 0:
			box_path.append(simulated.boxes[box_index]["position"])
			box_path.append_array(result["path"])
		ai_preview.append({
			"player_from": simulated.player_position,
			"player_to": next_state.player_position,
			"box_path": box_path
		})
		simulated = next_state
	queue_redraw()
	return true

func _play_next_ai_action() -> void:
	if not ai_playing or is_animating:
		return
	if ai_action_index >= ai_plan.size():
		_cancel_ai()
		if not is_completed:
			hud.set_ai_status("Niespójność odtwarzania: plan zakończony, ale poziom nie jest rozwiązany.")
		return
	var direction := ai_plan[ai_action_index]
	if not _try_move(direction):
		var failed_action_number := ai_action_index + 1
		var failure_reason := status
		_cancel_ai()
		hud.set_ai_status("Odtwarzanie przerwane: ruch %d nie powiódł się (%s)." % [failed_action_number, failure_reason])
		return
	ai_action_index += 1
	queue_redraw()
	hud.set_ai_status("Odtwarzanie planu: %d/%d" % [ai_action_index, ai_plan.size()])

func _update_hud() -> void:
	hud.update_state(moves, energy, physics.robot_force, status)
	_update_ai_controls()

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
		if ai_planning or ai_playing:
			return
		_try_move(direction)

func _try_move(direction: Vector2i) -> bool:
	if is_completed or is_animating:
		return false
	var result := physics.move(BoardState.new(player_position, boxes), direction, level)
	if bool(result["success"]):
		var next_state: BoardState = result["state"]
		player_position = next_state.player_position
		boxes = next_state.boxes
		moves += 1
		energy += float(result["energy"])
		var box_index: int = result["box_index"]
		if box_index >= 0:
			status = "Pchnięto skrzynię po podłożu: %s." % result["terrain"]
			pending_victory = _is_level_solved()
			_animate_push(box_index, result["path"])
		else:
			status = "Ruch wykonany."
			_animate_player()
	else:
		status = str(result["reason"])
	_update_hud()
	queue_redraw()
	return bool(result["success"])

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
	_update_ai_controls()
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
	if ai_playing:
		if is_completed:
			_cancel_ai()
			hud.set_ai_status("Plan wykonany. Poziom ukończony!")
		else:
			call_deferred("_play_next_ai_action")

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
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#0d1520"))
	draw_line(Vector2(32, 87), Vector2(get_viewport_rect().size.x - 32, 87), Color("#253543"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(36, 48), "SOKOBAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#edf5f8"))
	_draw_rounded_rect(Rect2(218, 24, 44, 29), Color("#163f40"), 7)
	draw_string(ThemeDB.fallback_font, Vector2(228, 45), "AI", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#67e0cb"))
	draw_string(ThemeDB.fallback_font, Vector2(790, 53), "WASD / STRZAŁKI    ruch       R    reset", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8fa5b5"))
	_draw_rounded_rect(Rect2(32, 104, 648, 596), Color("#141f2c"), 14, Color("#2a3a49"))
	draw_string(ThemeDB.fallback_font, Vector2(50, 132), "PLANSZA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#67e0cb"))
	var level_name := "Demo fizyki" if selected_level_index == 0 else "Test zwycięstwa"
	draw_string(ThemeDB.fallback_font, Vector2(426, 132), level_name, HORIZONTAL_ALIGNMENT_RIGHT, 234, 14, Color("#b9cbd6"))

	for y in level.tiles.size():
		for x in level.tiles[y].length():
			_draw_tile(Vector2i(x, y))
	_draw_ai_preview()
	for goal in level.goals:
		_draw_goal(goal)
	for box_index in boxes.size():
		_draw_box(visual_box_positions[box_index], float(boxes[box_index]["mass"]))
	_draw_player(visual_player_position)
	_draw_rounded_rect(Rect2(32, 716, 648, 60), Color("#141f2c"), 12, Color("#2a3a49"))
	_draw_terrain_key(Vector2(52, 746), Color("#3e505b"), "Drewno", 0)
	_draw_terrain_key(Vector2(192, 746), Color("#60bdd4"), "Lód", 1)
	_draw_terrain_key(Vector2(300, 746), Color("#c7a16a"), "Piasek", 2)
	_draw_terrain_key(Vector2(442, 746), Color("#67e0cb"), "Cel", 3)
	draw_string(ThemeDB.fallback_font, Vector2(550, 751), "1 pole = %.0f m" % PhysicalModel.TILE_SIZE_METERS, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8fa5b5"))

func _board_origin() -> Vector2:
	var columns := 0
	for row in level.tiles:
		columns = maxi(columns, row.length())
	return BOARD_ORIGIN + Vector2(11 - columns, 9 - level.tiles.size()) * TILE_SIZE / 2.0

func _draw_rounded_rect(rect: Rect2, fill: Color, radius: int, border: Color = Color.TRANSPARENT) -> void:
	var key := "%s/%d/%s" % [fill.to_html(), radius, border.to_html()]
	if not drawing_styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.set_corner_radius_all(radius)
		style.border_color = border
		style.set_border_width_all(1 if border.a > 0.0 else 0)
		drawing_styles[key] = style
	draw_style_box(drawing_styles[key], rect)

func _draw_terrain_key(center: Vector2, color: Color, label: String, kind: int) -> void:
	if kind == 3:
		draw_arc(center, 7, 0, TAU, 24, color, 2, true)
	else:
		_draw_rounded_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), color.darkened(0.4), 3, color)
		if kind == 1:
			draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), color, 1, true)
		elif kind == 2:
			draw_circle(center, 1.5, color)
	draw_string(ThemeDB.fallback_font, center + Vector2(18, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b9cbd6"))

func _draw_ai_preview() -> void:
	# Keep the active transition visible until its animation reaches the logical state.
	var first_action := maxi(0, ai_action_index - 1) if ai_playing and is_animating else ai_action_index
	for index in range(first_action, ai_preview.size()):
		var step: Dictionary = ai_preview[index]
		# Different offsets keep overlapping routes legible; actors/goals draw above.
		_draw_plan_segment(step["player_from"], step["player_to"], Vector2(17, 17), Color("#78baff"), false)
		var path: Array[Vector2i] = step["box_path"]
		for path_index in range(1, path.size()):
			_draw_plan_segment(path[path_index - 1], path[path_index], Vector2(39, 39), Color("#d99df5"), true)

func _draw_plan_segment(from: Vector2i, to: Vector2i, offset: Vector2, color: Color, dashed: bool) -> void:
	var start := _board_origin() + Vector2(from) * TILE_SIZE + offset
	var end := _board_origin() + Vector2(to) * TILE_SIZE + offset
	if dashed:
		draw_dashed_line(start, end, color, 2.0, 5.0)
	else:
		draw_line(start, end, color, 2.0, true)
	var direction := (end - start).normalized()
	var tip := start.lerp(end, 0.7)
	draw_line(tip, tip - direction.rotated(0.5) * 7.0, color, 2.0, true)
	draw_line(tip, tip - direction.rotated(-0.5) * 7.0, color, 2.0, true)

func _draw_tile(position: Vector2i) -> void:
	var tile := level.tile_at(position)
	var rect := Rect2(_board_origin() + Vector2(position) * TILE_SIZE + Vector2.ONE, Vector2.ONE * (TILE_SIZE - 2))
	if tile == LevelData.WALL:
		_draw_rounded_rect(rect, Color("#1b2a38"), 4, Color("#304454"))
		draw_line(rect.position + Vector2(6, 6), rect.position + Vector2(48, 6), Color("#3a5060"), 2)
		draw_line(rect.position + Vector2(6, 28), rect.position + Vector2(48, 28), Color("#243746"), 1)
		draw_line(rect.position + Vector2(27, 7), rect.position + Vector2(27, 27), Color("#243746"), 1)
		return
	var floor_color := Color("#33434b") if (position.x + position.y) % 2 == 0 else Color("#303f48")
	if tile == LevelData.ICE:
		floor_color = Color("#285264")
	elif tile == LevelData.SAND:
		floor_color = Color("#655239")
	_draw_rounded_rect(rect, floor_color, 3)
	if tile == LevelData.ICE:
		for index in 3:
			var start := rect.position + Vector2(9 + index * 13, 38)
			draw_line(start, start + Vector2(10, -22), Color("#5f96a8"), 1, true)
	elif tile == LevelData.SAND:
		for index in 9:
			var dot := Vector2(9 + (index * 17) % 39, 9 + (index * 13) % 37)
			draw_circle(rect.position + dot, 1, Color("#a08559"))
	else:
		for index in [18, 36]:
			draw_line(rect.position + Vector2(4, index), rect.position + Vector2(50, index), Color("#3a4a52"), 1)

func _draw_goal(position: Vector2i) -> void:
	var center := _board_origin() + Vector2(position) * TILE_SIZE + Vector2.ONE * TILE_SIZE / 2.0
	draw_circle(center, 20, Color(0.3, 0.9, 0.75, 0.1))
	draw_arc(center, 14, 0, TAU, 40, Color("#67e0cb"), 2, true)
	draw_circle(center, 4, Color("#67e0cb"))
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + direction * 18, center + direction * 22, Color("#67e0cb"), 2, true)

func _draw_box(position: Vector2, mass: float) -> void:
	var rect := Rect2(_board_origin() + position * TILE_SIZE + Vector2(6, 6), Vector2(44, 44))
	_draw_rounded_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color("#111d25"), 6)
	var on_goal := level.goals.has(Vector2i(position.round())) and position.is_equal_approx(position.round())
	var edge := Color("#67e0cb") if on_goal else Color("#e6b873")
	_draw_rounded_rect(rect, Color("#926339"), 5, edge)
	_draw_rounded_rect(rect.grow(-4), Color("#b17c45"), 2)
	draw_line(rect.position + Vector2(6, 6), rect.end - Vector2(6, 6), edge.darkened(0.15), 3, true)
	draw_line(rect.position + Vector2(38, 6), rect.position + Vector2(6, 38), edge.darkened(0.15), 3, true)
	for corner in [Vector2(4, 4), Vector2(40, 4), Vector2(4, 40), Vector2(40, 40)]:
		draw_circle(rect.position + corner, 1.5, edge)
	_draw_rounded_rect(Rect2(rect.position + Vector2(3, 16), Vector2(38, 16)), Color("#382c24"), 3)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(3, 28), "%d kg" % mass, HORIZONTAL_ALIGNMENT_CENTER, 38, 11, Color("#fff0d9"))

func _draw_player(position: Vector2) -> void:
	var center := _board_origin() + position * TILE_SIZE + Vector2.ONE * TILE_SIZE / 2.0
	draw_circle(center + Vector2(0, 5), 22, Color(0.02, 0.06, 0.08, 0.4))
	for side in [-1, 1]:
		_draw_rounded_rect(Rect2(center + Vector2(side * 17 - 4, -10), Vector2(8, 26)), Color("#101e29"), 3, Color("#476274"))
	_draw_rounded_rect(Rect2(center - Vector2(16, 17), Vector2(32, 35)), Color("#c3e3df"), 9, Color("#f0fffa"))
	_draw_rounded_rect(Rect2(center + Vector2(-13, -11), Vector2(26, 17)), Color("#14323d"), 5)
	for side in [-1, 1]:
		draw_circle(center + Vector2(side * 6, -3), 3, Color("#71f3dd"))
	draw_line(center + Vector2(-6, 12), center + Vector2(6, 12), Color("#448c86"), 2, true)
	draw_line(center + Vector2(0, -17), center + Vector2(0, -23), Color("#b9d7dc"), 2, true)
	draw_circle(center + Vector2(0, -23), 3, Color("#67e0cb"))
