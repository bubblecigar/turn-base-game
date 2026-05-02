extends Node

class_name AnimationTracker

signal animation_registered(animation_id: StringName)
signal animation_consumed(animation_id: StringName)
signal active_animations_changed(animation_ids: Array[StringName])

var _active_animation_ids: Dictionary = {}
var _animation_index := 0


func register_animation(animation_name: StringName) -> StringName:
	var animation_id := _create_animation_id(animation_name)

	print("animation start: ", animation_id)
	_active_animation_ids[animation_id] = true
	animation_registered.emit(animation_id)
	active_animations_changed.emit(get_active_animation_ids())
	return animation_id


func consume_animation(animation_id: StringName) -> void:
	if not _active_animation_ids.has(animation_id):
		return

	print("animation end: ", animation_id)
	_active_animation_ids.erase(animation_id)
	animation_consumed.emit(animation_id)
	active_animations_changed.emit(get_active_animation_ids())


func has_animation(animation_id: StringName) -> bool:
	return _active_animation_ids.has(animation_id)


func has_active_animations() -> bool:
	return not _active_animation_ids.is_empty()


func get_active_animation_ids() -> Array[StringName]:
	var animation_ids: Array[StringName] = []

	for animation_id: StringName in _active_animation_ids:
		animation_ids.append(animation_id)

	return animation_ids


func _create_animation_id(animation_name: StringName) -> StringName:
	_animation_index += 1
	return StringName("%s_%d" % [animation_name, _animation_index])
