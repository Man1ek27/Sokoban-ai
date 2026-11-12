class_name Campaign
extends RefCounted

## Ordered campaign levels and the player's persistent progress.
## Level N+1 unlocks only after level N has been completed.

const MANIFEST_PATH := "res://levels/campaign.json"
const PROGRESS_PATH := "user://progress.cfg"

var paths: Array[String] = []
var names: Array[String] = []
## Index of the first level that has not been completed yet (= highest unlocked level).
var unlocked_count := 1
## level index -> {"moves": int, "energy": float}
var best_results := {}
var progress_path := PROGRESS_PATH

static func level_paths() -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("Brak listy poziomów: %s" % MANIFEST_PATH)
		return result
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for path in parsed.get("levels", []):
			result.append(str(path))
	return result

func _init(save_path: String = PROGRESS_PATH) -> void:
	progress_path = save_path
	paths = level_paths()
	for path in paths:
		names.append(LevelData.from_file(path).name)
	load_progress()

func size() -> int:
	return paths.size()

func is_unlocked(index: int) -> bool:
	return index >= 0 and index < paths.size() and index < unlocked_count

func is_completed(index: int) -> bool:
	return best_results.has(index)

func display_name(index: int) -> String:
	var label := "%d. %s" % [index + 1, names[index]]
	if not is_unlocked(index):
		return label + "  — zablokowany"
	if is_completed(index):
		return label + "  — ukończony"
	return label

## Records a completed level; returns true when it unlocked a new level.
func complete(index: int, moves: int, energy: float) -> bool:
	if index < 0 or index >= paths.size():
		return false
	var best: Dictionary = best_results.get(index, {})
	if best.is_empty() or moves < int(best["moves"]) \
			or (moves == int(best["moves"]) and energy < float(best["energy"])):
		best_results[index] = {"moves": moves, "energy": energy}
	var unlocked_new := index + 1 >= unlocked_count and index + 1 < paths.size()
	unlocked_count = clampi(maxi(unlocked_count, index + 2), 1, paths.size())
	save_progress()
	return unlocked_new

func reset_progress() -> void:
	unlocked_count = 1
	best_results.clear()
	save_progress()

func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(progress_path) != OK:
		return
	unlocked_count = clampi(int(config.get_value("progress", "unlocked", 1)), 1, maxi(1, paths.size()))
	for index in paths.size():
		var key := "level_%d" % index
		if config.has_section_key("best", key):
			var value = config.get_value("best", key)
			if value is Dictionary and value.has("moves") and value.has("energy"):
				best_results[index] = {"moves": int(value["moves"]), "energy": float(value["energy"])}

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked", unlocked_count)
	for index in best_results:
		config.set_value("best", "level_%d" % index, best_results[index])
	var error := config.save(progress_path)
	if error != OK:
		push_error("Nie można zapisać postępu: %s" % error_string(error))
