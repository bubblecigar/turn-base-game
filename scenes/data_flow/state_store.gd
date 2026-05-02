extends Node

class_name StateStore

signal state_changed(state: Dictionary)
signal value_changed(key: StringName, value: Variant, previous_value: Variant)
signal board_init(board: Dictionary, previous_board: Variant)
signal character_initialized(character: Dictionary, previous_character: Variant)
signal character_moved(position: Vector2, previous_position: Variant)

const BOARD_CELL_SIZE := Vector2(72.0, 72.0)

@export var initial_state: Dictionary = {}

var _state: Dictionary = _get_default_state()


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
	state_changed.emit(get_state())


func init_character(character: Dictionary) -> void:
	var previous_character: Variant = _state.get(&"character")
	set_value(&"character", character)
	_place_character_on_board(character, 0, 0)
	character_initialized.emit(character, previous_character)


func init_board(cols: int, rows: int) -> void:
	var previous_board: Variant = _state.get(&"board")
	var board := _create_board(cols, rows)
	set_value(&"board", board)
	board_init.emit(board, previous_board)


func move_character_to(i: int, j: int) -> void:
	var character: Dictionary = _state.get(&"character", {})
	if character.is_empty():
		push_warning("Cannot move character before character is spawned.")
		return

	var previous_board: Dictionary = _state.get(&"board", {})
	var next_board := _move_character_on_board(character, i, j)
	if next_board.is_empty():
		return

	var previous_position: Variant = _state.get(&"character_position")
	var position := _board_index_to_position(i, j)
	set_value(&"board", next_board)
	set_value(&"character_position", position)
	board_init.emit(next_board, previous_board)
	character_moved.emit(position, previous_position)


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
	_state = _get_default_state()

	for key: Variant in next_initial_state:
		_state[StringName(str(key))] = next_initial_state[key]

	state_changed.emit(get_state())


func _get_default_state() -> Dictionary:
	return {
		&"board": {},
		&"character": {},
		&"character_position": Vector2.ZERO,
	}


func _create_board(cols: int, rows: int) -> Dictionary:
	var cells: Array[Array] = []

	for i in cols:
		var col_cells: Array[Variant] = []

		for j in rows:
			col_cells.append({
				&"i": i,
				&"j": j,
				&"entity": null,
			})

		cells.append(col_cells)

	return {
		&"cols": cols,
		&"rows": rows,
		&"cells": cells,
	}


func _place_character_on_board(character: Dictionary, i: int, j: int) -> void:
	var board: Dictionary = _state.get(&"board", {})
	if board.is_empty():
		return

	if not _has_board_cell(board, i, j):
		push_warning("Cannot place character outside board at (%d, %d)." % [i, j])
		return

	var previous_board: Dictionary = board
	var next_board := board.duplicate(true)
	var cells: Array = next_board[&"cells"]
	var cell: Dictionary = cells[i][j]
	cell[&"entity"] = character
	set_value(&"board", next_board)
	board_init.emit(next_board, previous_board)


func _move_character_on_board(character: Dictionary, next_i: int, next_j: int) -> Dictionary:
	var board: Dictionary = _state.get(&"board", {})
	if board.is_empty():
		push_warning("Cannot move character before board is spawned.")
		return {}

	if not _has_board_cell(board, next_i, next_j):
		push_warning("Cannot move character outside board to (%d, %d)." % [next_i, next_j])
		return {}

	var next_board := board.duplicate(true)
	var cells: Array = next_board[&"cells"]

	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if cell.get(&"entity") == character:
				cell[&"entity"] = null

	var next_cell: Dictionary = cells[next_i][next_j]
	next_cell[&"entity"] = character
	return next_board


func _has_board_cell(board: Dictionary, i: int, j: int) -> bool:
	return (
		board.has(&"cells")
		and i >= 0
		and j >= 0
		and i < int(board.get(&"cols", 0))
		and j < int(board.get(&"rows", 0))
	)


func _board_index_to_position(i: int, j: int) -> Vector2:
	return Vector2(
		(float(i) + 0.5) * BOARD_CELL_SIZE.x,
		(float(j) + 0.5) * BOARD_CELL_SIZE.y
	)
