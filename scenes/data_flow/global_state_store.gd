extends Node

class_name GlobalStateStore

signal state_changed(state: Dictionary)

var _state: Dictionary = {
	&"selected_entity": {},
}


func get_state() -> Dictionary:
	return _state.duplicate(true)


func save_selected_entity(entity_id: StringName, entity_data: Dictionary) -> void:
	_state[&"selected_entity"] = {
		&"id": entity_id,
		&"data": entity_data.duplicate(true),
	}
	state_changed.emit(get_state())


func get_selected_entity() -> Dictionary:
	return _state.get(&"selected_entity", {}).duplicate(true)
