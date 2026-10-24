class_name GameHud
extends CanvasLayer

signal reset_requested
signal level_selected(index: int)

@onready var level_selector: OptionButton = $Panel/Margin/Content/LevelSelector
@onready var moves_value: Label = $Panel/Margin/Content/MovesRow/MovesValue
@onready var energy_value: Label = $Panel/Margin/Content/EnergyRow/EnergyValue
@onready var force_value: Label = $Panel/Margin/Content/ForceRow/ForceValue
@onready var status_value: Label = $Panel/Margin/Content/StatusValue
@onready var reset_button: Button = $Panel/Margin/Content/ResetButton
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
	replay_button.pressed.connect(_on_replay_pressed)
	close_button.pressed.connect(hide_victory)
	hide_victory()

func _on_level_selected(index: int) -> void:
	level_selected.emit(level_selector.get_item_id(index))

func _on_reset_pressed() -> void:
	reset_requested.emit()

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
