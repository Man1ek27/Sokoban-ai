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

func _ready() -> void:
	level_selector.add_item("Demo fizyki", 0)
	level_selector.add_item("Test zwycięstwa", 1)
	level_selector.select(0)
	level_selector.item_selected.connect(_on_level_selected)
	reset_button.pressed.connect(_on_reset_pressed)

func _on_level_selected(index: int) -> void:
	level_selected.emit(level_selector.get_item_id(index))

func _on_reset_pressed() -> void:
	reset_requested.emit()

func update_state(move_count: int, total_energy: float, max_force: float, latest_status: String) -> void:
	moves_value.text = str(move_count)
	energy_value.text = "%.1f J" % total_energy
	force_value.text = "%.0f N" % max_force
	status_value.text = latest_status
