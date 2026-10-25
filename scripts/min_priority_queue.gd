class_name MinPriorityQueue
extends RefCounted

## Binary min-heap
var _heap: Array[Dictionary] = []
var _sequence := 0

func is_empty() -> bool:
	return _heap.is_empty()

func push(value: Variant, priority: float) -> void:
	var entry := {"value": value, "priority": priority, "sequence": _sequence}
	_sequence += 1
	_heap.append(entry)
	var index := _heap.size() - 1
	while index > 0:
		var parent := (index - 1) / 2
		if not _less(entry, _heap[parent]):
			break
		_heap[index] = _heap[parent]
		index = parent
	_heap[index] = entry

func pop() -> Variant:
	var value: Variant = _heap[0]["value"]
	var last: Dictionary = _heap.pop_back()
	if _heap.is_empty():
		return value
	var index := 0
	while index * 2 + 1 < _heap.size():
		var child := index * 2 + 1
		if child + 1 < _heap.size() and _less(_heap[child + 1], _heap[child]):
			child += 1
		if not _less(_heap[child], last):
			break
		_heap[index] = _heap[child]
		index = child
	_heap[index] = last
	return value

func _less(a: Dictionary, b: Dictionary) -> bool:
	if a["priority"] == b["priority"]:
		return a["sequence"] < b["sequence"]
	return a["priority"] < b["priority"]