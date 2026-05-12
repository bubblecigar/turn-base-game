extends RefCounted

signal attack_performed(attacker_id: StringName, args: Dictionary)
signal attack_prepared(attacker_id: StringName, args: Dictionary)

const ATTACK_TYPE_BUMP := &"bump"
const ATTACK_TYPE_STRONG_BUMP := &"strong_bump"
const STRONG_BUMP_FOCUS_COST := 3
const SCHEMAS := {
	"bump": {
		"required": ["type", "vector", "damage"],
		"fields": {
			"type": TYPE_STRING,
			"vector": TYPE_VECTOR2I,
			"damage": TYPE_INT,
			"source": TYPE_STRING,
		},
	},
	"strong_bump": {
		"required": ["type", "vector", "damage", "resource"],
		"fields": {
			"type": TYPE_STRING,
			"vector": TYPE_VECTOR2I,
			"damage": TYPE_INT,
			"resource": TYPE_INT,
			"source": TYPE_STRING,
		},
	},
	"throw_projectile": {
		"required": ["type", "vector", "damage", "resource"],
		"fields": {
			"type": TYPE_STRING,
			"vector": TYPE_VECTOR2I,
			"damage": TYPE_INT,
			"resource": TYPE_INT,
			"source": TYPE_STRING,
		},
	},
}

var _state_store: Node


func _init(state_store: Node) -> void:
	_state_store = state_store


func prepare_attack(payload: Dictionary) -> void:
	if not _is_attack_payload(payload):
		push_warning('Invalid prepare_attack payload. Check AttackHandler.SCHEMAS for supported attack args.')
		return

	var attacker_id := StringName(str(payload["id"]))
	if not _state_store.has_entity(attacker_id):
		push_warning("Cannot prepare attack with missing entity: %s." % attacker_id)
		return

	var args := _get_attack_args_with_target_cell(attacker_id, payload["args"])
	attack_prepared.emit(attacker_id, args)
	print('prepared attack: ', attacker_id, ' ', args)


func perform_attack(payload: Dictionary) -> void:
	if not _is_attack_payload(payload):
		push_warning('Invalid perform_attack payload. Check AttackHandler.SCHEMAS for supported attack args.')
		return

	var attacker_id := StringName(str(payload["id"]))
	if not _state_store.has_entity(attacker_id):
		push_warning("Cannot perform attack with missing entity: %s." % attacker_id)
		return

	var attacker_cell := _get_entity_board_index(attacker_id)
	if attacker_cell == Vector2i(-1, -1):
		push_warning("Cannot perform attack with entity outside board: %s." % attacker_id)
		return

	var args := _get_attack_args_with_target_cell(attacker_id, payload["args"])
	match StringName(str(args["type"])):
		ATTACK_TYPE_BUMP:
			pass
		ATTACK_TYPE_STRONG_BUMP:
			if not _perform_strong_bump_attack(attacker_id, args):
				return
		_:
			pass

	attack_performed.emit(attacker_id, args)
	print('performed attack: ', attacker_id, ' ', args)


func _perform_strong_bump_attack(attacker_id: StringName, args: Dictionary) -> bool:
	var focus_cost := int(args.get("resource", STRONG_BUMP_FOCUS_COST))
	if focus_cost != STRONG_BUMP_FOCUS_COST:
		push_warning("Invalid strong_bump resource cost: %d. Expected %d." % [focus_cost, STRONG_BUMP_FOCUS_COST])
		return false

	return _state_store.spend_entity_focus(attacker_id, focus_cost)


func _get_attack_args_with_target_cell(attacker_id: StringName, source_args: Dictionary) -> Dictionary:
	var args: Dictionary = source_args.duplicate(true)
	var attacker_cell := _get_entity_board_index(attacker_id)
	if attacker_cell == Vector2i(-1, -1):
		return args

	var attack_vector := _get_vector(args["vector"])
	var target_cell := attacker_cell + attack_vector
	args[&"target_cell"] = {
		"i": target_cell.x,
		"j": target_cell.y,
	}
	return args


func _is_attack_payload(payload: Dictionary) -> bool:
	return (
		payload.has("id")
		and payload.has("args")
		and (typeof(payload["id"]) == TYPE_STRING or typeof(payload["id"]) == TYPE_STRING_NAME)
		and payload["args"] is Dictionary
		and _is_attack_args(payload["args"])
	)


func _is_attack_args(args: Dictionary) -> bool:
	if not args.has("type") or typeof(args["type"]) != TYPE_STRING:
		return false

	var attack_type := str(args["type"])
	if not SCHEMAS.has(attack_type):
		return false

	var schema: Dictionary = SCHEMAS[attack_type]
	var required_fields: Array = schema.get("required", [])
	for field_name: String in required_fields:
		if not args.has(field_name):
			return false

	var fields: Dictionary = schema.get("fields", {})
	for field_name: String in fields:
		if not args.has(field_name):
			continue

		if typeof(args[field_name]) != int(fields[field_name]):
			return false

	return true


func _get_vector(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value

	var vector: Vector2 = value
	return Vector2i(int(vector.x), int(vector.y))


func _get_entity_board_index(entity_id: StringName) -> Vector2i:
	var board: Dictionary = _state_store.get_value(&"board", {})
	if board.is_empty() or not board.has(&"cells"):
		return Vector2i(-1, -1)

	var cells: Array = board[&"cells"]
	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _cell_has_entity_id(cell, entity_id):
				return Vector2i(i, j)

	return Vector2i(-1, -1)


func _cell_has_entity_id(cell: Dictionary, entity_id: StringName) -> bool:
	var entity_ids: Array = cell.get(&"entity_ids", [])
	return entity_ids.has(entity_id) or cell.get(&"entity_id", &"") == entity_id
