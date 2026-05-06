extends Node

class_name StateStore

signal state_changed(state: Dictionary)
signal value_changed(key: StringName, value: Variant, previous_value: Variant)
signal entities_updated(entities: Dictionary, previous_entities: Variant)
signal board_init(board: Dictionary, previous_board: Variant)
signal character_initialized(character: Dictionary, previous_character: Variant)
signal entity_moved(entity_id: StringName, position: Vector2, previous_position: Variant)
signal entity_attack_pair_triggered(attacker_id: StringName, target_id: StringName)

const BOARD_CELL_SIZE := Vector2(72.0, 72.0)

@export var initial_state: Dictionary = {}

var _state: Dictionary = _get_default_state()
var _character_index := 0


func _ready() -> void:
	print('state store ready')
	reset()


func get_state() -> Dictionary:
	return _state.duplicate(true)


func has_value(key: StringName) -> bool:
	return _state.has(key)


func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return _state.get(key, default_value)


func set_value(key: StringName, value: Variant) -> void:
	var previous_value: Variant = _state.get(key)
	if previous_value == value:
		return

	_state[key] = value
	value_changed.emit(key, value, previous_value)
	if key == &"entities" and value is Dictionary:
		entities_updated.emit(value, previous_value)
	state_changed.emit(get_state())


func init_entity(entity_type: StringName, spec: Dictionary, i: int = 0, j: int = 0) -> void:
	var previous_character: Variant = {}
	if _character_index > 0:
		previous_character = _get_entity(StringName("character_%d" % _character_index))

	var next_entity := {
		&"id": _create_entity_id(entity_type),
		&"type": entity_type,
		&"spec": spec.duplicate(true),
	}
	_set_entity(next_entity)
	_place_entity_on_board(next_entity, i, j)
	character_initialized.emit(next_entity, previous_character)


func init_board(cols: int, rows: int) -> void:
	var previous_board: Variant = _state.get(&"board")
	var board := _create_board(cols, rows)
	set_value(&"board", board)
	board_init.emit(board, previous_board)


func move_entity_to(entity_id: StringName, i: int, j: int) -> void:
	var entity := _get_entity(entity_id)
	if entity.is_empty():
		push_warning("Cannot move missing entity: %s." % entity_id)
		return

	var previous_board: Dictionary = _state.get(&"board", {})
	var previous_position: Variant = _get_entity_position(entity)
	var next_board := _move_entity_on_board(entity, i, j)
	if next_board.is_empty():
		return

	var position := _board_index_to_position(i, j)
	set_value(&"board", next_board)
	board_init.emit(next_board, previous_board)
	entity_moved.emit(entity.get(&"id", &""), position, previous_position)


func attack_entity(attacker_id: StringName, target_id: StringName) -> void:
	var attacker := _get_entity(attacker_id)
	if attacker.is_empty():
		push_warning("Cannot attack with missing entity: %s." % attacker_id)
		return

	var target := _get_entity(target_id)
	if target.is_empty():
		push_warning("Cannot attack missing target: %s." % target_id)
		return

	entity_attack_pair_triggered.emit(attacker_id, target_id)


func patch(values: Dictionary) -> void:
	var changed := false

	for key: Variant in values:
		var state_key := StringName(str(key))
		var next_value: Variant = values[key]
		var previous_value: Variant = _state.get(state_key)

		if previous_value == next_value:
			continue

		_state[state_key] = next_value
		value_changed.emit(state_key, next_value, previous_value)
		if state_key == &"entities" and next_value is Dictionary:
			entities_updated.emit(next_value, previous_value)
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
	_character_index = 0
	_state = _get_default_state()

	for key: Variant in next_initial_state:
		_state[StringName(str(key))] = next_initial_state[key]

	state_changed.emit(get_state())


func _get_default_state() -> Dictionary:
	return {
		&"board": {},
		&"entities": {},
	}


func _create_board(cols: int, rows: int) -> Dictionary:
	var cells: Array[Array] = []

	for i in cols:
		var col_cells: Array[Variant] = []

		for j in rows:
			col_cells.append({
				&"i": i,
				&"j": j,
				&"entity_id": &"",
			})

		cells.append(col_cells)

	return {
		&"cols": cols,
		&"rows": rows,
		&"cell_size": BOARD_CELL_SIZE,
		&"cells": cells,
	}


func _create_entity_id(entity_type: StringName) -> StringName:
	_character_index += 1
	return StringName("%s_%d" % [entity_type, _character_index])


func _set_entity(entity: Dictionary) -> void:
	var entity_id: StringName = entity.get(&"id", &"")
	if entity_id == &"":
		push_error("Cannot set entity without an id.")
		return

	var previous_entities: Dictionary = _state.get(&"entities", {})
	var next_entities := previous_entities.duplicate(true)
	next_entities[entity_id] = entity
	set_value(&"entities", next_entities)

	print('entities: ', _state.get(&"entities", {}))


func _get_entity(entity_id: StringName) -> Dictionary:
	var entities: Dictionary = _state.get(&"entities", {})
	return entities.get(entity_id, {})


func _place_entity_on_board(entity: Dictionary, i: int, j: int) -> void:
	var board: Dictionary = _state.get(&"board", {})
	if board.is_empty():
		return

	if not _has_board_cell(board, i, j):
		push_warning("Cannot place entity outside board at (%d, %d)." % [i, j])
		return

	var previous_board: Dictionary = board
	var next_board := board.duplicate(true)
	var cells: Array = next_board[&"cells"]
	var cell: Dictionary = cells[i][j]
	cell[&"entity_id"] = entity.get(&"id", &"")
	set_value(&"board", next_board)
	board_init.emit(next_board, previous_board)


func _move_entity_on_board(entity: Dictionary, next_i: int, next_j: int) -> Dictionary:
	var board: Dictionary = _state.get(&"board", {})
	if board.is_empty():
		push_warning("Cannot move entity before board is spawned.")
		return {}

	if not _has_board_cell(board, next_i, next_j):
		push_warning("Cannot move entity outside board to (%d, %d)." % [next_i, next_j])
		return {}

	var next_board := board.duplicate(true)
	var cells: Array = next_board[&"cells"]

	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if cell.get(&"entity_id", &"") == entity.get(&"id", &""):
				cell[&"entity_id"] = &""

	var next_cell: Dictionary = cells[next_i][next_j]
	next_cell[&"entity_id"] = entity.get(&"id", &"")
	return next_board


func _get_entity_position(entity: Dictionary) -> Variant:
	var board: Dictionary = _state.get(&"board", {})
	var board_index := _get_entity_board_index(board, entity)
	if board_index == Vector2i(-1, -1):
		return null

	return _board_index_to_position(board_index.x, board_index.y)


func _get_entity_board_index(board: Dictionary, entity: Dictionary) -> Vector2i:
	if board.is_empty() or not board.has(&"cells"):
		return Vector2i(-1, -1)

	var cells: Array = board[&"cells"]
	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if cell.get(&"entity_id", &"") == entity.get(&"id", &""):
				return Vector2i(i, j)

	return Vector2i(-1, -1)





func _has_board_cell(board: Dictionary, i: int, j: int) -> bool:
	return (
		board.has(&"cells")
		and i >= 0
		and j >= 0
		and i < int(board.get(&"cols", 0))
		and j < int(board.get(&"rows", 0))
	)


func _board_index_to_position(i: int, j: int) -> Vector2:
	var board: Dictionary = _state.get(&"board", {})
	var cell_size: Vector2 = board.get(&"cell_size", BOARD_CELL_SIZE)

	return Vector2(
		(float(i) + 0.5) * cell_size.x,
		(float(j) + 0.5) * cell_size.y
	)
