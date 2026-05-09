extends Control

const DAMAGE_MIN := 1
const DAMAGE_MAX := 9

@onready var action_queue: Node = $"../../ActionQueue"
@onready var state_store: Node = $"../../StateStore"
@onready var entity_select: OptionButton = $EntitySelect
@onready var move_left_button: Button = $MoveLeftButton
@onready var move_right_button: Button = $MoveRightButton
@onready var attack_left_button: Button = $AttackLeftButton
@onready var attack_right_button: Button = $AttackRightButton

var _selected_entity_id := &""


func _ready() -> void:
	randomize()
	state_store.entities_updated.connect(_on_entities_updated)
	state_store.board_init.connect(_on_board_init)
	entity_select.item_selected.connect(_on_entity_selected)
	move_left_button.pressed.connect(_on_move_left_pressed)
	move_right_button.pressed.connect(_on_move_right_pressed)
	attack_left_button.pressed.connect(_on_attack_left_pressed)
	attack_right_button.pressed.connect(_on_attack_right_pressed)
	_refresh_entity_options()


func _on_entities_updated(_entities: Dictionary, _previous_entities: Variant) -> void:
	_refresh_entity_options()


func _on_board_init(_board: Dictionary, _previous_board: Variant) -> void:
	_refresh_entity_options()


func _on_entity_selected(index: int) -> void:
	_selected_entity_id = StringName(entity_select.get_item_text(index))


func _on_move_left_pressed() -> void:
	_move_selected_entity(-1)


func _on_move_right_pressed() -> void:
	_move_selected_entity(1)


func _on_attack_left_pressed() -> void:
	_attack_selected_cell(-1)


func _on_attack_right_pressed() -> void:
	_attack_selected_cell(1)


func _refresh_entity_options() -> void:
	var previous_selected_id := _selected_entity_id
	var entity_ids := _get_board_entity_ids()
	entity_select.clear()

	for entity_id: StringName in entity_ids:
		entity_select.add_item(str(entity_id))

	var selected_index := -1
	for index in entity_ids.size():
		if entity_ids[index] == previous_selected_id:
			selected_index = index
			break

	if selected_index == -1 and not entity_ids.is_empty():
		selected_index = 0

	if selected_index == -1:
		_selected_entity_id = &""
	else:
		entity_select.select(selected_index)
		_selected_entity_id = entity_ids[selected_index]

	var has_entity := _selected_entity_id != &""
	entity_select.disabled = not has_entity
	move_left_button.disabled = not has_entity
	move_right_button.disabled = not has_entity
	attack_left_button.disabled = not has_entity
	attack_right_button.disabled = not has_entity


func _move_selected_entity(delta_i: int) -> void:
	if _selected_entity_id == &"":
		push_warning("Select an entity before moving.")
		return

	action_queue.enQueue([{
		"eventName": "move_entity",
		"payload": {
			"id": _selected_entity_id,
			"vector": Vector2i(delta_i, 0),
		},
	}])


func _attack_selected_cell(delta_i: int) -> void:
	var selected_cell := _get_selected_entity_cell()
	if selected_cell.is_empty():
		push_warning("Select an entity on the board before attacking.")
		return

	var target_cell := _get_offset_cell(selected_cell, delta_i)
	if target_cell.is_empty():
		push_warning("Cannot attack outside the board with %s." % _selected_entity_id)
		return

	action_queue.enQueue([{
		"eventName": "perform_attack",
		"payload": {
			"id": _selected_entity_id,
			"args": {
				"damage": randi_range(DAMAGE_MIN, DAMAGE_MAX),
				"source": "debugger",
				"target_cell": target_cell,
			},
		},
	}])


func _get_board_entity_ids() -> Array[StringName]:
	var board: Dictionary = state_store.get_value(&"board", {})
	var entity_ids: Array[StringName] = []
	var cells: Array = board.get(&"cells", [])

	for col_cells: Array in cells:
		for cell: Dictionary in col_cells:
			for entity_id: Variant in cell.get(&"entity_ids", []):
				var entity_string_name := StringName(str(entity_id))
				if not entity_ids.has(entity_string_name):
					entity_ids.append(entity_string_name)

			var legacy_entity_id := StringName(str(cell.get(&"entity_id", &"")))
			if legacy_entity_id != &"" and not entity_ids.has(legacy_entity_id):
				entity_ids.append(legacy_entity_id)

	return entity_ids


func _get_selected_entity_cell() -> Dictionary:
	if _selected_entity_id == &"":
		return {}

	var board: Dictionary = state_store.get_value(&"board", {})
	var cells: Array = board.get(&"cells", [])
	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _cell_has_entity_id(cell, _selected_entity_id):
				return {
					"i": i,
					"j": j,
				}

	return {}


func _get_offset_cell(cell: Dictionary, delta_i: int) -> Dictionary:
	var board: Dictionary = state_store.get_value(&"board", {})
	var target_i := int(cell["i"]) + delta_i
	var target_j := int(cell["j"])
	if target_i < 0 or target_i >= int(board.get(&"cols", 0)):
		return {}

	if target_j < 0 or target_j >= int(board.get(&"rows", 0)):
		return {}

	return {
		"i": target_i,
		"j": target_j,
	}


func _cell_has_entity_id(cell: Dictionary, entity_id: StringName) -> bool:
	var entity_ids: Array = cell.get(&"entity_ids", [])
	return entity_ids.has(entity_id) or cell.get(&"entity_id", &"") == entity_id
