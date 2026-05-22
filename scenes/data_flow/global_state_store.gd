extends Node

class_name GlobalStateStore

signal state_changed(state: Dictionary)

static var _persistent_state: Dictionary = {
	&"selected_entity": {},
}

var _state: Dictionary = _persistent_state.duplicate(true)


func get_state() -> Dictionary:
	return _state.duplicate(true)


func save_selected_entity(entity_id: StringName, entity_data: Dictionary, card_pool: Array[Dictionary]) -> void:
	_state[&"selected_entity"] = {
		&"id": entity_id,
		&"data": entity_data.duplicate(true),
		&"card_pool": card_pool.duplicate(true),
	}
	_persistent_state = _state.duplicate(true)
	state_changed.emit(get_state())


func clear_selected_entity() -> void:
	_state[&"selected_entity"] = {}
	_persistent_state = _state.duplicate(true)
	state_changed.emit(get_state())


func get_selected_entity() -> Dictionary:
	return _state.get(&"selected_entity", {}).duplicate(true)
