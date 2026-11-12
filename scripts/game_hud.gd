class_name GameHud
extends CanvasLayer

signal reset_requested
signal level_selected(index: int)
signal next_level_requested
signal ai_solve_requested(cost_mode: int, heuristic_id: int)
signal ai_stop_requested
signal robot_force_changed(force: float)
signal ai_settings_changed

enum Heuristic { H1, H2, H3 }

@onready var level_selector: OptionButton = $Panel/Margin/Scroll/Content/LevelSelector
@onready var moves_value: Label = $Panel/Margin/Scroll/Content/Metrics/MovesRow/MovesValue
@onready var energy_value: Label = $Panel/Margin/Scroll/Content/Metrics/EnergyRow/EnergyValue
@onready var force_input: SpinBox = $Panel/Margin/Scroll/Content/ForceRow/ForceInput
@onready var status_value: Label = $Panel/Margin/Scroll/Content/StatusValue
@onready var reset_button: Button = $Panel/Margin/Scroll/Content/ResetButton
@onready var cost_selector: OptionButton = $Panel/Margin/Scroll/Content/AiSection/Settings/Cost/CostSelector
@onready var heuristic_selector: OptionButton = $Panel/Margin/Scroll/Content/AiSection/Settings/Heuristic/HeuristicSelector
@onready var ai_config_value: Label = $Panel/Margin/Scroll/Content/AiSection/AiConfigValue
@onready var solve_button: Button = $Panel/Margin/Scroll/Content/AiSection/AiButtons/SolveButton
@onready var stop_button: Button = $Panel/Margin/Scroll/Content/AiSection/AiButtons/StopButton
@onready var ai_status_value: Label = $Panel/Margin/Scroll/Content/AiSection/AiStatusValue
@onready var ai_stats_value: Label = $Panel/Margin/Scroll/Content/AiSection/AiStatsValue
@onready var victory_overlay: Control = $VictoryOverlay
@onready var victory_moves_value: Label = $VictoryOverlay/Center/VictoryPanel/Margin/Content/MovesValue
@onready var victory_energy_value: Label = $VictoryOverlay/Center/VictoryPanel/Margin/Content/EnergyValue
@onready var victory_progress_value: Label = $VictoryOverlay/Center/VictoryPanel/Margin/Content/ProgressValue
@onready var next_button: Button = $VictoryOverlay/Center/VictoryPanel/Margin/Content/Buttons/NextButton
@onready var replay_button: Button = $VictoryOverlay/Center/VictoryPanel/Margin/Content/Buttons/ReplayButton
@onready var close_button: Button = $VictoryOverlay/Center/VictoryPanel/Margin/Content/Buttons/CloseButton

var victory_tween: Tween
var parameters_locked := false

func _ready() -> void:
	level_selector.item_selected.connect(_on_level_selected)
	reset_button.pressed.connect(_on_reset_pressed)
	cost_selector.add_item("STEPS — ruchy", AStarSolver.CostMode.STEPS)
	cost_selector.add_item("ENERGY — energia", AStarSolver.CostMode.ENERGY)
	cost_selector.select(0)
	heuristic_selector.add_item("h1 — Manhattan", Heuristic.H1)
	heuristic_selector.add_item("h2 — masa i tarcie", Heuristic.H2)
	heuristic_selector.add_item("h3 — Terrain-Aware", Heuristic.H3)
	for index in [1, 2]:
		heuristic_selector.set_item_disabled(index, true)
		heuristic_selector.set_item_tooltip(index, "Niedostępna: oczekuje na integrację heurystyki.")
	heuristic_selector.select(0)
	heuristic_selector.item_selected.connect(_on_ai_setting_selected)
	cost_selector.item_selected.connect(_on_ai_setting_selected)
	force_input.value_changed.connect(_on_force_changed)
	solve_button.pressed.connect(_on_solve_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	set_ai_activity(false, false, false)
	clear_ai_result()
	replay_button.pressed.connect(_on_replay_pressed)
	close_button.pressed.connect(hide_victory)
	next_button.pressed.connect(_on_next_pressed)
	hide_victory()

## Rebuilds the level list; locked levels stay visible but cannot be chosen.
func set_levels(labels: Array[String], unlocked: Array[bool], selected: int) -> void:
	level_selector.clear()
	for index in labels.size():
		level_selector.add_item(labels[index], index)
		level_selector.set_item_disabled(index, not unlocked[index])
		if not unlocked[index]:
			level_selector.set_item_tooltip(index, "Ukończ poprzedni poziom, aby odblokować.")
	if selected >= 0 and selected < labels.size():
		level_selector.select(selected)

func _on_level_selected(index: int) -> void:
	level_selected.emit(level_selector.get_item_id(index))

func _on_next_pressed() -> void:
	hide_victory()
	next_level_requested.emit()

func _on_reset_pressed() -> void:
	reset_requested.emit()

func _on_solve_pressed() -> void:
	if not parameters_locked:
		ai_solve_requested.emit(cost_selector.get_selected_id(), heuristic_selector.get_selected_id())

func _on_ai_setting_selected(_index: int) -> void:
	if not parameters_locked:
		ai_settings_changed.emit()
		clear_ai_result()

func _on_force_changed(force: float) -> void:
	if not parameters_locked:
		robot_force_changed.emit(force)

func _on_stop_pressed() -> void:
	ai_stop_requested.emit()

func set_ai_activity(is_planning: bool, is_playing: bool, is_animating: bool) -> void:
	parameters_locked = is_planning or is_playing or is_animating
	stop_button.disabled = not is_playing
	solve_button.disabled = parameters_locked
	cost_selector.disabled = parameters_locked
	heuristic_selector.disabled = parameters_locked
	force_input.editable = not parameters_locked
	if parameters_locked:
		force_input.get_line_edit().release_focus()
	# Keyboard reset can still invalidate the run before synchronous solve starts.
	level_selector.disabled = is_planning
	reset_button.disabled = is_planning

func heuristic_name(heuristic_id: int) -> String:
	var index := heuristic_selector.get_item_index(heuristic_id)
	return heuristic_selector.get_item_text(index) if index >= 0 else "Nieznana"

func _update_ai_config() -> void:
	ai_config_value.text = "%s\nOptymalizacja: %s" % [
		heuristic_name(heuristic_selector.get_selected_id()),
		"STEPS" if cost_selector.get_selected_id() == AStarSolver.CostMode.STEPS else "ENERGY"
	]

func set_ai_status(message: String) -> void:
	ai_status_value.text = message

func clear_ai_result() -> void:
	_update_ai_config()
	ai_status_value.text = "Gotowy do działania."
	ai_stats_value.text = "Czas: —\nRozwinięte: —    Odkryte: —\nDługość: —    Energia planu: —"

func show_ai_result(result: Dictionary, cost_mode: int, heuristic_id: int) -> void:
	var mode_name := "STEPS" if cost_mode == AStarSolver.CostMode.STEPS else "ENERGY"
	ai_config_value.text = "%s\nOptymalizacja: %s" % [heuristic_name(heuristic_id), mode_name]
	var solution_stats := "Długość: —    Energia planu: —"
	if bool(result["success"]):
		solution_stats = "Długość: %d ruchów    Energia planu: %.1f J" % [int(result["moves"]), float(result["energy"])]
	ai_stats_value.text = "Status: %s\nCzas: %.1f ms\nRozwinięte: %d    Odkryte: %d\n%s" % [
		str(result["status"]), float(result["elapsed_ms"]), int(result["expanded_states"]),
		int(result["discovered_states"]), solution_stats
	]
	match str(result["status"]):
		"solved":
			set_ai_status("Plan znaleziony.")
		"no_solution":
			set_ai_status("Brak rozwiązania po przeszukaniu stanów.")
		"time_limit":
			set_ai_status("Limit czasu. Nie wiadomo, czy istnieje rozwiązanie.")
		"state_limit":
			set_ai_status("Limit stanów. Nie wiadomo, czy istnieje rozwiązanie.")
		"invalid_input":
			set_ai_status("Nieprawidłowy poziom lub stan gry.")
		"invalid_heuristic":
			set_ai_status("Nieprawidłowa heurystyka.")
		_:
			set_ai_status("Nieznany status planera: %s" % result["status"])

func _on_replay_pressed() -> void:
	hide_victory()
	reset_requested.emit()

func show_victory(move_count: int, total_energy: float, progress_text: String = "", has_next: bool = false) -> void:
	if victory_tween != null and victory_tween.is_valid():
		victory_tween.kill()
	victory_moves_value.text = "Ruchy: %d" % move_count
	victory_energy_value.text = "Energia: %.1f J" % total_energy
	victory_progress_value.text = progress_text
	victory_progress_value.visible = progress_text != ""
	next_button.visible = has_next
	victory_overlay.modulate.a = 0.0
	victory_overlay.visible = true
	victory_tween = create_tween()
	victory_tween.tween_property(victory_overlay, "modulate:a", 1.0, 0.25)

func hide_victory() -> void:
	if victory_tween != null and victory_tween.is_valid():
		victory_tween.kill()
	victory_tween = null
	victory_overlay.visible = false
	victory_overlay.modulate.a = 0.0

func update_state(move_count: int, total_energy: float, max_force: float, latest_status: String) -> void:
	moves_value.text = str(move_count)
	energy_value.text = "%.1f J" % total_energy
	force_input.set_value_no_signal(max_force)
	status_value.text = latest_status
