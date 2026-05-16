extends RefCounted

const BUMP_DAMAGE_MIN := 1
const BUMP_DAMAGE_MAX := 9
const STRONG_BUMP_DAMAGE_MIN := 4
const STRONG_BUMP_DAMAGE_MAX := 9
const STRONG_BUMP_FOCUS_COST := 3
const STRONG_BUMP_VECTOR_LENGTH := 3
const THROW_PROJECTILE_DAMAGE_MIN := 1
const THROW_PROJECTILE_DAMAGE_MAX := 9
const THROW_PROJECTILE_RESOURCE_COST := 0

var _state_store: Node


func _init(state_store: Node) -> void:
	_state_store = state_store


func create_card_action(card_data: Dictionary, entity_id: StringName) -> Dictionary:
	var action_factory := str(card_data.get("action_factory", ""))
	if action_factory != "":
		return _create_action_from_factory(action_factory, entity_id, card_data.get("args", {}))

	push_warning("Card has no action_factory: %s." % card_data)
	return {}


func _create_action_from_factory(action_factory: String, entity_id: StringName, args: Dictionary = {}) -> Dictionary:
	match action_factory:
		"bump":
			return _create_attack_action(
				entity_id,
				"bump",
				_get_vector_to_target(entity_id, 1),
				randi_range(int(args.get("damage_min", BUMP_DAMAGE_MIN)), int(args.get("damage_max", BUMP_DAMAGE_MAX)))
			)
		"strong_bump":
			return _create_attack_action(
				entity_id,
				"strong_bump",
				_get_vector_to_target(entity_id, int(args.get("vector_length", STRONG_BUMP_VECTOR_LENGTH))),
				randi_range(int(args.get("damage_min", STRONG_BUMP_DAMAGE_MIN)), int(args.get("damage_max", STRONG_BUMP_DAMAGE_MAX))),
				int(args.get("resource", STRONG_BUMP_FOCUS_COST))
			)
		"throw_projectile":
			var source_cell := _get_entity_board_cell(entity_id)
			var target_cell := _get_first_other_board_cell(entity_id)
			var actual_length := 2
			if source_cell != Vector2i(-1, -1) and target_cell != Vector2i(-1, -1):
				var delta := target_cell - source_cell
				actual_length = clampi(maxi(absi(delta.x), absi(delta.y)), 2, 5)
			return _create_attack_action(
				entity_id,
				"throw_projectile",
				_get_vector_to_target(entity_id, actual_length),
				randi_range(int(args.get("damage_min", THROW_PROJECTILE_DAMAGE_MIN)), int(args.get("damage_max", THROW_PROJECTILE_DAMAGE_MAX))),
				int(args.get("resource", THROW_PROJECTILE_RESOURCE_COST))
			)
		"focus":
			return _create_cast_action(entity_id, "focus", args)
		"heal":
			return _create_cast_action(entity_id, "heal", args)
		"summon_thunder":
			return _create_cast_action(entity_id, "summon_thunder", args)
		"move_left":
			return _create_move_action(entity_id, Vector2i.LEFT)
		"move_right":
			return _create_move_action(entity_id, Vector2i.RIGHT)
		_:
			push_warning("Unsupported card action factory: %s." % action_factory)
			return {}


func _create_cast_action(entity_id: StringName, cast_type: String, args: Dictionary) -> Dictionary:
	var cast_args := {
		"type": cast_type,
		"source": "hand_gui",
	}
	if args.has("value"):
		cast_args["value"] = int(args["value"])
	if args.has("resource"):
		cast_args["resource"] = int(args["resource"])
	return {
		"eventName": "perform_cast",
		"payload": {
			"id": entity_id,
			"args": cast_args,
		},
	}


func _create_move_action(entity_id: StringName, vector: Vector2i) -> Dictionary:
	return {
		"eventName": "move_entity",
		"payload": {
			"id": entity_id,
			"vector": vector,
		},
	}


func _create_attack_action(entity_id: StringName, attack_type: String, vector: Vector2i, damage: int, resource: Variant = null) -> Dictionary:
	var args := {
		"type": attack_type,
		"damage": damage,
		"source": "hand_gui",
		"vector": vector,
	}
	if resource != null:
		args["resource"] = resource

	return {
		"eventName": "perform_attack",
		"payload": {
			"id": entity_id,
			"args": args,
		},
	}


func _get_vector_to_target(entity_id: StringName, vector_length: int) -> Vector2i:
	var source_cell := _get_entity_board_cell(entity_id)
	var target_cell := _get_first_other_board_cell(entity_id)
	if source_cell == Vector2i(-1, -1) or target_cell == Vector2i(-1, -1):
		return Vector2i.RIGHT * vector_length

	var delta := target_cell - source_cell
	if delta == Vector2i.ZERO:
		return _get_random_horizontal_direction() * vector_length

	var axis_direction := Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		axis_direction.x = _signi(delta.x)
	else:
		axis_direction.y = _signi(delta.y)

	if axis_direction == Vector2i.ZERO:
		axis_direction = _get_random_horizontal_direction()

	return axis_direction * vector_length


func _get_random_horizontal_direction() -> Vector2i:
	if randi_range(0, 1) == 0:
		return Vector2i.LEFT

	return Vector2i.RIGHT


func _get_entity_board_cell(entity_id: StringName) -> Vector2i:
	if _state_store == null:
		return Vector2i(-1, -1)

	var board: Dictionary = _state_store.get_value(&"board", {})
	var cells: Array = board.get(&"cells", [])
	for i in cells.size():
		var col_cells: Array = cells[i]
		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _cell_has_entity(cell, entity_id):
				return Vector2i(int(cell.get(&"i", i)), int(cell.get(&"j", j)))

	return Vector2i(-1, -1)


func _get_first_other_board_cell(entity_id: StringName) -> Vector2i:
	if _state_store == null:
		return Vector2i(-1, -1)

	var board: Dictionary = _state_store.get_value(&"board", {})
	var cells: Array = board.get(&"cells", [])
	for i in cells.size():
		var col_cells: Array = cells[i]
		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _cell_has_other_entity(cell, entity_id):
				return Vector2i(int(cell.get(&"i", i)), int(cell.get(&"j", j)))

	return Vector2i(-1, -1)


func _cell_has_entity(cell: Dictionary, entity_id: StringName) -> bool:
	for cell_entity_id: Variant in cell.get(&"entity_ids", []):
		if StringName(str(cell_entity_id)) == entity_id:
			return true

	return StringName(str(cell.get(&"entity_id", &""))) == entity_id


func _cell_has_other_entity(cell: Dictionary, entity_id: StringName) -> bool:
	for cell_entity_id: Variant in cell.get(&"entity_ids", []):
		var cell_entity_string_name := StringName(str(cell_entity_id))
		if cell_entity_string_name != &"" and cell_entity_string_name != entity_id:
			return true

	var legacy_entity_id := StringName(str(cell.get(&"entity_id", &"")))
	return legacy_entity_id != &"" and legacy_entity_id != entity_id


func _signi(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0
