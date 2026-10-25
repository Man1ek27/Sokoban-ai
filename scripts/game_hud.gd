class_name GameHud
extends CanvasLayer

signal reset_requested
signal level_selected(index: int)
signal ai_solve_requested(cost_mode: int)
signal ai_stop_requested

@onready var level_selector: OptionButton = $Panel/Margin/Content/LevelSelector
@onready var moves_value: Label = $Panel/Margin/Content/MovesRow/MovesValue
@onready var energy_value: Label = $Panel/Margin/Content/EnergyRow/EnergyValue
@onready var force_value: Label = $Panel/Margin/Content/ForceRow/ForceValue
@onready var status_value: Label = $Panel/Margin/Content/StatusValue
@onready var reset_button: Button = $Panel/Margin/Content/ResetButton
@onready var cost_selector: OptionButton = $Panel/Margin/Content/AiSection/CostSelector
@onready var solve_button: Button = $Panel/Margin/Content/AiSection/AiButtons/SolveButton
@onready var stop_button: Button = $Panel/Margin/Content/AiSection/AiButtons/StopButton
@onready var ai_status_value: Label = $Panel/Margin/Content/AiSection/AiStatusValue
@onready var ai_stats_value: Label = $Panel/Margin/Content/AiSection/AiStatsValue
@onready var victory_overlay: Control = $VictoryOverlay
@onready var victory_moves_value: Label = $VictoryOverlay/Center/VictoryPanel/Margin/Content/MovesValue
@onready var victory_energy_value: Label = $VictoryOverlay/Center/VictoryPanel/Margin/Content/EnergyValue
@onready var replay_button: Button = $VictoryOverlay/Center/VictoryPanel/Margin/Content/Buttons/ReplayButton
@onready var close_button: Button = $VictoryOverlay/Center/VictoryPanel/Margin/Content/Buttons/CloseButton

var victory_tween: Tween

func _ready() -> void:
	level_selector.add_item("Demo fizyki", 0)
	level_selector.add_item("Test zwycięstwa", 1)
	level_selector.select(0)
	level_selector.item_selected.connect(_on_level_selected)
	reset_button.pressed.connect(_on_reset_pressed)
	cost_selector.add_item("Najmniej ruchów", AStarSolver.CostMode.STEPS)
	cost_selector.add_item("Najmniej energii", AStarSolver.CostMode.ENERGY)
	cost_selector.select(0)
	solve_button.pressed.connect(_on_solve_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	set_ai_playback(false)
	clear_ai_result()
	replay_button.pressed.connect(_on_replay_pressed)
	close_button.pressed.connect(hide_victory)
	hide_victory()

func _on_level_selected(index: int) -> void:
	level_selected.emit(level_selector.get_item_id(index))

func _on_reset_pressed() -> void:
	reset_requested.emit()

func _on_solve_pressed() -> void:
	ai_solve_requested.emit(cost_selector.get_selected_id())

func _on_stop_pressed() -> void:
	ai_stop_requested.emit()

func set_ai_playback(is_playing: bool) -> void:
	stop_button.disabled = not is_playing
	solve_button.disabled = is_playing
	cost_selector.disabled = is_playing

func set_ai_status(message: String) -> void:
	ai_status_value.text = message

func clear_ai_result() -> void:
	ai_status_value.text = "Gotowy do działania."
	ai_stats_value.text = "Brak wyniku."

func show_ai_result(result: Dictionary, cost_mode: int) -> void:
	var mode_name := "STEPS" if cost_mode == AStarSolver.CostMode.STEPS else "ENERGY"
	ai_stats_value.text = "Tryb: %s | Czas: %.1f ms\nRozwinięte: %d | Odkryte: %d\nRuchy: %d | Energia: %.1f J" % [
		mode_name, float(result["elapsed_ms"]), int(result["expanded_states"]),
		int(result["discovered_states"]), int(result["moves"]), float(result["energy"])
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

func show_victory(move_count: int, total_energy: float) -> void:
	if victory_tween != null and victory_tween.is_valid():
		victory_tween.kill()
	victory_moves_value.text = "Ruchy: %d" % move_count
	victory_energy_value.text = "Energia: %.1f J" % total_energy
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
	force_value.text = "%.0f N" % max_force
	status_value.text = latest_status
