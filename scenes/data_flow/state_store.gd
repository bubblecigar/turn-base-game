extends Node

class_name StateStore

signal state_changed(state: Dictionary)
signal value_changed(key: StringName, value: Variant, previous_value: Variant)
signal entities_updated(entities: Dictionary, previous_entities: Variant)
signal board_init(board: Dictionary, previous_board: Variant)
signal character_initialized(character: Dictionary, previous_character: Variant)
signal entity_moved(entity_id: StringName, position: Vector2, previous_position: Variant)
signal entity_focus_changed(entity_id: StringName, focus: int, previous_focus: int)
signal cast_performed(caster_id: StringName, focus: int)
signal cast_resolved(caster_id: StringName, result: bool)
signal entity_selection_changed(entity_id: StringName, previous_entity_id: StringName)
signal selected_card_changed(entity_id: StringName, card_data: Dictionary)
signal entity_card_pools_changed(entity_card_pools: Dictionary, previous_entity_card_pools: Variant)

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
	if key == &"entity_card_pools" and value is Dictionary:
		entity_card_pools_changed.emit(value, previous_value)
	state_changed.emit(get_state())


func select_entity(entity_id: StringName) -> void:
	var previous_id := StringName(str(_state.get(&"selected_entity_id", &"")))
	if previous_id == entity_id:
		return
	_state[&"selected_entity_id"] = entity_id
	entity_selection_changed.emit(entity_id, previous_id)


func get_selected_entity_id() -> StringName:
	return StringName(str(_state.get(&"selected_entity_id", &"")))


func select_card(entity_id: StringName, card_data: Dictionary) -> void:
	var selected_cards: Dictionary = _state.get(&"selected_cards", {})
	selected_cards = selected_cards.duplicate()
	selected_cards[entity_id] = card_data.duplicate(true)
	_state[&"selected_cards"] = selected_cards
	selected_card_changed.emit(entity_id, card_data)


func get_selected_card(entity_id: StringName) -> Dictionary:
	var selected_cards: Dictionary = _state.get(&"selected_cards", {})
	return selected_cards.get(entity_id, {})


func set_entity_card_pool(entity_id: StringName, cards: Array[Dictionary]) -> void:
	if entity_id == &"":
		return

	var previous_card_pools: Dictionary = _state.get(&"entity_card_pools", {})
	var next_card_pools := previous_card_pools.duplicate(true)
	next_card_pools[entity_id] = cards.duplicate(true)
	set_value(&"entity_card_pools", next_card_pools)


func has_entity_card_pool(entity_id: StringName) -> bool:
	var card_pools: Dictionary = _state.get(&"entity_card_pools", {})
	return card_pools.has(entity_id)


func get_entity_card_pool(entity_id: StringName) -> Array[Dictionary]:
	var card_pools: Dictionary = _state.get(&"entity_card_pools", {})
	var raw_cards: Array = card_pools.get(entity_id, [])
	var cards: Array[Dictionary] = []
	for raw_card: Variant in raw_cards:
		if raw_card is Dictionary:
			cards.append(raw_card.duplicate(true))

	return cards


func init_entity(entity_type: StringName, spec: Dictionary, max_hp: int, i: int = 0, j: int = 0) -> StringName:
	var previous_character: Variant = {}
	if _character_index > 0:
		previous_character = _get_entity(StringName("character_%d" % _character_index))

	var next_entity := {
		&"id": _create_entity_id(entity_type),
		&"type": entity_type,
		&"max_hp": max_hp,
		&"current_hp": max_hp,
		&"focus": 0,
		&"state": &"idle",
		&"cast_args": {},
		&"spec": spec.duplicate(true),
	}
	_set_entity(next_entity)
	_place_entity_on_board(next_entity, i, j)
	select_entity(next_entity[&"id"])
	character_initialized.emit(next_entity, previous_character)
	return next_entity[&"id"]


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

	var previous_position: Variant = _get_entity_position(entity)
	var next_board := _move_entity_on_board(entity, i, j)
	if next_board.is_empty():
		return

	var position := _board_index_to_position(i, j)
	set_value(&"board", next_board)

	entity_moved.emit(entity.get(&"id", &""), position, previous_position)


func move_entity_by(entity_id: StringName, vector: Vector2i) -> void:
	var entity := _get_entity(entity_id)
	if entity.is_empty():
		push_warning("Cannot move missing entity: %s." % entity_id)
		return

	var board: Dictionary = _state.get(&"board", {})
	var board_index := _get_entity_board_index(board, entity)
	if board_index == Vector2i(-1, -1):
		push_warning("Cannot move entity outside board: %s." % entity_id)
		return

	move_entity_to(entity_id, board_index.x + vector.x, board_index.y + vector.y)


func has_entity(entity_id: StringName) -> bool:
	return not _get_entity(entity_id).is_empty()


func damage_entity(entity_id: StringName, damage: int) -> void:
	if damage <= 0:
		return

	var entity := _get_entity(entity_id)
	if entity.is_empty():
		push_warning("Cannot damage missing entity: %s." % entity_id)
		return

	var max_hp: int = max(int(entity.get(&"max_hp", 0)), 0)
	var current_hp: int = clamp(int(entity.get(&"current_hp", max_hp)), 0, max_hp)
	var next_hp: int = clamp(current_hp - damage, 0, max_hp)
	if next_hp == current_hp:
		return

	var next_entity := entity.duplicate(true)
	next_entity[&"current_hp"] = next_hp
	_set_entity(next_entity)
	if _is_entity_casting(next_entity):
		resolve_entity_cast(entity_id, false)

	print("damaged entity: %s -%d hp %d/%d" % [entity_id, damage, next_hp, max_hp])


func heal_entity(entity_id: StringName, amount: int) -> void:
	if amount <= 0:
		return

	var entity := _get_entity(entity_id)
	if entity.is_empty():
		push_warning("Cannot heal missing entity: %s." % entity_id)
		return

	var max_hp: int = max(int(entity.get(&"max_hp", 0)), 0)
	var current_hp: int = clamp(int(entity.get(&"current_hp", max_hp)), 0, max_hp)
	var next_hp: int = clamp(current_hp + amount, 0, max_hp)
	if next_hp == current_hp:
		return

	var next_entity := entity.duplicate(true)
	next_entity[&"current_hp"] = next_hp
	_set_entity(next_entity)
	print("healed entity: %s +%d hp %d/%d" % [entity_id, amount, next_hp, max_hp])


func increase_entity_focus(entity_id: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return

	var entity := _get_entity(entity_id)
	if entity.is_empty():
		push_warning("Cannot increase focus for missing entity: %s." % entity_id)
		return

	var previous_focus: int = max(int(entity.get(&"focus", 0)), 0)
	var next_focus := previous_focus + amount
	var next_entity := entity.duplicate(true)
	next_entity[&"focus"] = next_focus
	_set_entity(next_entity)
	entity_focus_changed.emit(entity_id, next_focus, previous_focus)
	cast_performed.emit(entity_id, next_focus)
	print("increased entity focus: %s +%d focus %d" % [entity_id, amount, next_focus])


func spend_entity_focus(entity_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true

	var entity := _get_entity(entity_id)
	if entity.is_empty():
		push_warning("Cannot spend focus for missing entity: %s." % entity_id)
		return false

	var previous_focus: int = max(int(entity.get(&"focus", 0)), 0)
	if previous_focus < amount:
		push_warning("Cannot spend %d focus for %s with %d focus." % [amount, entity_id, previous_focus])
		return false

	var next_focus := previous_focus - amount
	var next_entity := entity.duplicate(true)
	next_entity[&"focus"] = next_focus
	_set_entity(next_entity)
	entity_focus_changed.emit(entity_id, next_focus, previous_focus)
	print("spent entity focus: %s -%d focus %d" % [entity_id, amount, next_focus])
	return true


func start_entity_casting(entity_id: StringName, args: Dictionary) -> void:
	var entity := _get_entity(entity_id)
	if entity.is_empty():
		push_warning("Cannot start casting for missing entity: %s." % entity_id)
		return

	var next_entity := entity.duplicate(true)
	next_entity[&"state"] = &"casting"
	next_entity[&"cast_args"] = args.duplicate(true)
	_set_entity(next_entity)
	print("entity started casting: %s %s" % [entity_id, args])


func resolve_entity_cast(entity_id: StringName, result: bool) -> void:
	var entity := _get_entity(entity_id)
	if entity.is_empty():
		push_warning("Cannot resolve casting for missing entity: %s." % entity_id)
		return

	if not _is_entity_casting(entity):
		print("ignored cast resolve for non-casting entity: %s" % entity_id)
		return

	var next_entity := entity.duplicate(true)
	next_entity[&"state"] = &"idle"
	next_entity[&"cast_args"] = {}
	_set_entity(next_entity)
	cast_resolved.emit(entity_id, result)
	print("entity cast resolved: %s result=%s" % [entity_id, result])


func _is_entity_casting(entity: Dictionary) -> bool:
	return StringName(str(entity.get(&"state", &"idle"))) == &"casting"


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
		if state_key == &"entity_card_pools" and next_value is Dictionary:
			entity_card_pools_changed.emit(next_value, previous_value)
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
		&"selected_entity_id": &"",
		&"selected_cards": {},
		&"entity_card_pools": {},
	}


func _create_board(cols: int, rows: int) -> Dictionary:
	var cells: Array[Array] = []

	for i in cols:
		var col_cells: Array[Variant] = []

		for j in rows:
			col_cells.append({
				&"i": i,
				&"j": j,
				&"entity_ids": [],
			})

		cells.append(col_cells)

	return {
		&"cols": cols,
		&"rows": rows,
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
	_add_entity_id_to_cell(cell, entity.get(&"id", &""))
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
			_remove_entity_id_from_cell(cell, entity.get(&"id", &""))

	var next_cell: Dictionary = cells[next_i][next_j]
	_add_entity_id_to_cell(next_cell, entity.get(&"id", &""))
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
			if _cell_has_entity_id(cell, entity.get(&"id", &"")):
				return Vector2i(i, j)

	return Vector2i(-1, -1)


func _add_entity_id_to_cell(cell: Dictionary, entity_id: StringName) -> void:
	var entity_ids: Array = _get_cell_entity_ids(cell)
	if not entity_ids.has(entity_id):
		entity_ids.append(entity_id)

	cell[&"entity_ids"] = entity_ids
	cell.erase(&"entity_id")


func _remove_entity_id_from_cell(cell: Dictionary, entity_id: StringName) -> void:
	var entity_ids: Array = _get_cell_entity_ids(cell)
	entity_ids.erase(entity_id)
	cell[&"entity_ids"] = entity_ids
	cell.erase(&"entity_id")


func _cell_has_entity_id(cell: Dictionary, entity_id: StringName) -> bool:
	return _get_cell_entity_ids(cell).has(entity_id)


func _get_cell_entity_ids(cell: Dictionary) -> Array:
	var entity_ids: Array = cell.get(&"entity_ids", [])
	var legacy_entity_id: StringName = cell.get(&"entity_id", &"")
	if legacy_entity_id != &"" and not entity_ids.has(legacy_entity_id):
		entity_ids.append(legacy_entity_id)

	return entity_ids





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
	var cell_size: Vector2 = board.get(&"cell_size", Vector2.ZERO)

	return Vector2(
		(float(i) + 0.5) * cell_size.x,
		(float(j) + 0.5) * cell_size.y
	)
