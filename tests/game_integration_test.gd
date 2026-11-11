extends SceneTree

## Run: Godot --headless --path . --script res://tests/game_integration_test.gd
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hud: GameHud = game.hud
	await process_frame
	await process_frame
	var scroll: ScrollContainer = hud.get_node("Panel/Margin/Scroll")
	var content: Control = scroll.get_node("Content")
	_check(content.size.x <= scroll.size.x, "HUD content must fit horizontally without clipping")
	_check(hud.get_node("Panel").position.x >= 664.0, "HUD must leave the demo board unobstructed")
	_check(content.size.y <= scroll.size.y, "HUD must fit vertically without scrolling")
	print("HUD scroll width=%.1f content width=%.1f" % [scroll.size.x, content.size.x])
	_check(hud.heuristic_selector.is_item_disabled(1) and hud.heuristic_selector.is_item_disabled(2), "h2/h3 must be disabled")
	hud.cost_selector.select(AStarSolver.CostMode.ENERGY)
	hud.cost_selector.item_selected.emit(AStarSolver.CostMode.ENERGY)
	_check(hud.heuristic_selector.get_selected_id() == GameHud.Heuristic.H1, "Cost mode must not change heuristic")
	_check(not game._heuristic_for(GameHud.Heuristic.H2, AStarSolver.CostMode.STEPS).is_valid(), "h2 must not fall back to h1")

	game._select_level(1)
	for key in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S, KEY_UP, KEY_W]:
		game._reset_level()
		var key_event := InputEventKey.new()
		key_event.keycode = key
		key_event.pressed = true
		game._unhandled_key_input(key_event)
		_check(game.moves == 1, "Movement key %d must perform one legal action" % key)
		var reset_event := InputEventKey.new()
		reset_event.keycode = KEY_R
		reset_event.pressed = true
		game._unhandled_key_input(reset_event)
		_check(game.moves == 0 and not game.is_animating, "R must reset an active movement")
	hud.force_input.value = 0.0
	_check(game.level.robot_force == 0.0 and game.physics.robot_force == 0.0, "HUD force must reach level and physics")
	_check(not game._try_move(Vector2i.UP) and game.moves == 0 and game.energy == 0.0, "Insufficient force must block manual push without charging energy")
	var no_solution: Dictionary = AStarSolver.new().solve(game.level)
	_check(no_solution["status"] == "no_solution", "Solver must use modified force")
	hud.show_ai_result(no_solution, AStarSolver.CostMode.STEPS, GameHud.Heuristic.H1)
	_check(hud.ai_stats_value.text.contains("Energia planu: —"), "Unsolved search must not display zero energy as a solution")
	game._reset_level()
	_check(game.level.robot_force == 300.0 and hud.force_input.value == 300.0, "Reset must restore JSON force")

	# Verify preview against a real multi-tile slide, including the landing goal.
	var sliding := LevelData.from_dictionary({"robot_force": 300.0, "map": ["#########", "#PBIIG..#", "#########"]})
	game.level = sliding
	game.physics = PhysicalModel.new(sliding.robot_force)
	game.player_position = sliding.player_start
	game.boxes = sliding.boxes.duplicate(true)
	game.visual_player_position = Vector2(sliding.player_start)
	game.visual_box_positions.assign([Vector2(sliding.boxes[0]["position"])])
	var start := BoardState.from_level(sliding)
	var start_key := start.state_key()
	for mode in [AStarSolver.CostMode.STEPS, AStarSolver.CostMode.ENERGY]:
		var result: Dictionary = AStarSolver.new().solve(sliding, start, mode, game._heuristic_for(GameHud.Heuristic.H1, mode))
		_check(result["success"], "Sliding fixture must solve in both modes")
		game.ai_plan.assign(result["actions"])
		_check(game._build_ai_preview(start), "Preview must accept sliding solution")
		var path: Array[Vector2i] = game.ai_preview[0]["box_path"]
		_check(path == [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)], "Preview must include every ice/landing cell and box origin")
		_check(start.state_key() == start_key and BoardState.new(game.player_position, game.boxes).state_key() == start_key, "Preview must not mutate live or initial state")
		var transition: Dictionary = game.physics.move(start, Vector2i.RIGHT, sliding)
		_check(is_equal_approx(float(result["energy"]), float(transition["energy"])), "Solver and physics energy must agree")
	game._change_robot_force(200.0)
	_check(game.ai_preview.is_empty() and game.ai_plan.is_empty(), "Force changes must invalidate preview and plan")
	var longer := LevelData.from_dictionary({"map": ["#######", "#..G..#", "#.....#", "#..B..#", "#.....#", "#..P..#", "#######"]})
	game.level = longer
	game.physics = PhysicalModel.new(longer.robot_force)
	game.player_position = longer.player_start
	game.boxes = longer.boxes.duplicate(true)
	game.visual_player_position = Vector2(longer.player_start)
	game.visual_box_positions.assign([Vector2(longer.boxes[0]["position"])])
	await game._start_ai(AStarSolver.CostMode.STEPS)
	_check(game.ai_plan.size() == 3 and game.ai_action_index == 1, "Longer solution must initially retain all preview transitions")
	game._change_robot_force(0.0)
	_check(game.level.robot_force == 300.0, "Force setter must reject changes during playback")
	await create_timer(0.23).timeout
	_check(game.ai_action_index == 2 and game.ai_preview.size() == 3 and game.ai_preview[1]["player_from"] == Vector2i(3, 4), "Playback must advance the preview suffix from the real next robot position")
	game._stop_ai()
	await create_timer(0.25).timeout
	_check(not game.is_completed and not game.is_animating and game.moves == 2, "Stop in mid-plan must prevent subsequent moves")
	_check(game.visual_player_position == Vector2(game.player_position) and game.visual_box_positions[0] == Vector2(game.boxes[0]["position"]), "Stopped push must leave visuals aligned")
	_check(game._try_move(Vector2i.LEFT), "Manual control must work after stopping AI")

	# A real playback is started, then interrupted while its tween is active.
	game._select_level(1)
	game._start_ai(AStarSolver.CostMode.STEPS, GameHud.Heuristic.H1)
	_check(game.ai_planning and not hud.force_input.editable and hud.heuristic_selector.disabled and hud.cost_selector.disabled, "Planning must lock parameters before yielding")
	game._change_robot_force(10.0)
	_check(game.level.robot_force == 300.0, "Force setter must reject calls during planning")
	await process_frame
	await process_frame
	_check(game.ai_playing and game.is_animating and game.ai_preview.size() == 1, "Solved plan must start animation with preview")
	game._stop_ai()
	_check(not game.ai_playing and game.is_animating and game.ai_preview.is_empty() and not hud.force_input.editable, "Stop must clear plan and let current animation finish")
	await create_timer(0.35).timeout
	_check(game.is_completed and game.visual_player_position == Vector2(game.player_position) and hud.force_input.editable, "Stop during final push must still complete consistently")
	game._select_level(0)
	_check(not game.is_completed and not hud.victory_overlay.visible and game.ai_preview.is_empty(), "Changing level after AI completion must clear victory and preview")
	game._select_level(1)
	_check(game._try_move(Vector2i.UP), "Manual push must work")
	game._reset_level()
	await create_timer(0.35).timeout
	_check(not game.is_animating and not game.is_completed and game.moves == 0 and game.energy == 0.0 and not hud.victory_overlay.visible, "Reset during animation must cancel stale completion")
	_check(game.visual_player_position == Vector2(game.player_position) and game.visual_box_positions[0] == Vector2(game.boxes[0]["position"]), "Reset must align visual and logical state")
	game._start_ai(AStarSolver.CostMode.STEPS)
	game._reset_level()
	await process_frame
	await process_frame
	_check(not game.ai_playing and not game.ai_planning and game.moves == 0 and hud.force_input.editable, "Reset before synchronous solve must invalidate pending run")
	await game._start_ai(AStarSolver.CostMode.ENERGY)
	await create_timer(0.35).timeout
	_check(game.is_completed and not game.ai_playing and game.ai_preview.is_empty(), "Uninterrupted ENERGY playback must complete and clear preview")

	var solver := AStarSolver.new()
	var demo := LevelData.from_file("res://levels/demo_level.json")
	var limited := solver.solve(demo, null, AStarSolver.CostMode.STEPS, Callable(), 1, 5000)
	_check(limited["status"] == "state_limit", "State limit fixture must reach state_limit")
	hud.show_ai_result(limited, AStarSolver.CostMode.STEPS, GameHud.Heuristic.H1)
	_check(hud.ai_status_value.text.contains("Limit stanów") and hud.ai_stats_value.text.contains("Długość: —"), "HUD must distinguish limits from solutions")
	var slow_heuristic := func(_state: BoardState, _level: LevelData) -> float:
		OS.delay_usec(2000)
		return 0.0
	var timed := solver.solve(demo, null, AStarSolver.CostMode.STEPS, slow_heuristic, 100000, 1)
	_check(timed["status"] == "time_limit", "Time limit fixture must reach time_limit")
	hud.show_ai_result(timed, AStarSolver.CostMode.STEPS, GameHud.Heuristic.H1)
	_check(hud.ai_status_value.text.contains("Limit czasu"), "HUD must show real time limit result")
	for mode in [AStarSolver.CostMode.STEPS, AStarSolver.CostMode.ENERGY]:
		var result := solver.solve(demo, null, mode, SokobanHeuristics.manhattan_for(demo, mode == AStarSolver.CostMode.ENERGY), 100000, 30000)
		_check(result["success"], "Existing demo must solve in mode %d (status: %s)" % [mode, result["status"]])
		print("demo mode=%d status=%s moves=%d energy=%.1f" % [mode, result["status"], result["moves"], result["energy"]])
		hud.show_ai_result(result, mode, GameHud.Heuristic.H1)
		await process_frame
		await process_frame
		_check(content.size.y <= scroll.size.y, "Full solver statistics must fit without scrolling")
	game.queue_free()
	await process_frame
	print("Integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
