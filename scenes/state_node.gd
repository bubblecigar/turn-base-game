extends Node

class_name StateNode

signal state_changed(state: Dictionary)
signal value_changed(key: StringName, value: Variant, previous_value: Variant)

@export var initial_state: Dictionary = {}

var _state: Dictionary = {}


func _ready() -> void:
	reset()


func get_state() -> Dictionary:
	return _state.duplicate(true)


func has_value(key: StringName) -> bool:
	return _state.has(key)


func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return _state.get(key, default_value)


func set_value(key: StringName, value: Variant) -> void:
	var previous_value := _state.get(key)
	if previous_value == value:
		return

	_state[key] = value
	value_changed.emit(key, value, previous_value)
	state_changed.emit(get_state())


func patch(values: Dictionary) -> void:
	var changed := false

	for key: Variant in values:
		var state_key := StringName(str(key))
		var next_value: Variant = values[key]
		var previous_value := _state.get(state_key)

		if previous_value == next_value:
			continue

		_state[state_key] = next_value
		value_changed.emit(state_key, next_value, previous_value)
		changed = true

	if changed:
		state_changed.emit(get_state())


func erase_value(key: StringName) -> void:
	if not _state.has(key):
		return

	var previous_value: Variant = _state[key]
	_state.erase(key)
	value_changed.emit(key, null, previous_value)
	state_changed.emit(get_state())


func reset(next_initial_state: Dictionary = initial_state) -> void:
	_state = {}

	for key: Variant in next_initial_state:
		_state[StringName(str(key))] = next_initial_state[key]

	state_changed.emit(get_state())
