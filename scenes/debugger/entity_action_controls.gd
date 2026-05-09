extends Control

const DAMAGE_MIN := 1
const DAMAGE_MAX := 9
const RANDOM_MOVE_VECTORS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
const ACTION_CATEGORY_CAST := &"cast"
const ACTION_CATEGORY_MOVE := &"move"
const ACTION_CATEGORY_ATTACK := &"attack"
const ACTION_CATEGORY_ORDER := [
	ACTION_CATEGORY_CAST,
	ACTION_CATEGORY_MOVE,
	ACTION_CATEGORY_ATTACK,
]

@onready var action_queue: Node = $"../../ActionQueue"
@onready var state_store: Node = $"../../StateStore"
@onready var entity_select: OptionButton = $EntitySelect
@onready var move_left_button: Button = $MoveLeftButton
@onready var move_right_button: Button = $MoveRightButton
@onready var attack_left_button: Button = $AttackLeftButton
@onready var attack_right_button: Button = $AttackRightButton
@onready var batch_random_move_button: Button = $BatchRandomMoveButton
@onready var send_batch_button: Button = $SendBatchButton
@onready var action_stack_label: Label = $ActionStackLabel

var _selected_entity_id := &""
var _action_stack: Array[Dictionary] = []


func _ready() -> void:
	randomize()
	state_store.entities_updated.connect(_on_entities_updated)
	state_store.board_init.connect(_on_board_init)
	entity_select.item_selected.connect(_on_entity_selected)
	move_left_button.pressed.connect(_on_move_left_pressed)
	move_right_button.pressed.connect(_on_move_right_pressed)
	attack_left_button.pressed.connect(_on_attack_left_pressed)
	attack_right_button.pressed.connect(_on_attack_right_pressed)
	batch_random_move_button.pressed.connect(_on_batch_random_move_pressed)
	send_batch_button.pressed.connect(_on_send_batch_pressed)
	_refresh_entity_options()
	_update_action_stack_status()


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


func _on_batch_random_move_pressed() -> void:
	var move_options := _get_random_move_options()
	if move_options.size() < 2:
		push_warning("Cannot batch random moves before at least two entities are on the board.")
		return

	var selected_options := _get_distinct_target_move_options(move_options)
	if selected_options.is_empty():
		push_warning("Cannot batch random moves with distinct target cells.")
		return

	_stack_action(_create_move_action(selected_options[0]["entity_id"], selected_options[0]["vector"]))
	_stack_action(_create_move_action(selected_options[1]["entity_id"], selected_options[1]["vector"]))


func _on_send_batch_pressed() -> void:
	if _action_stack.is_empty():
		push_warning("Cannot send an empty debugger action batch.")
		return

	_enqueue_action_stack(_action_stack)
	_action_stack.clear()
	_update_action_stack_status()


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
	batch_random_move_button.disabled = entity_ids.size() < 2


func _move_selected_entity(delta_i: int) -> void:
	if _selected_entity_id == &"":
		push_warning("Select an entity before moving.")
		return

	_stack_action(_create_move_action(_selected_entity_id, Vector2i(delta_i, 0)))


func _create_move_action(entity_id: StringName, vector: Vector2i) -> Dictionary:
	return {
		"eventName": "move_entity",
		"payload": {
			"id": entity_id,
			"vector": vector,
		},
	}


func _attack_selected_cell(delta_i: int) -> void:
	if _selected_entity_id == &"":
		push_warning("Select an entity before attacking.")
		return

	_stack_action({
		"eventName": "perform_attack",
		"payload": {
			"id": _selected_entity_id,
			"args": {
				"damage": randi_range(DAMAGE_MIN, DAMAGE_MAX),
				"source": "debugger",
				"vector": Vector2i(delta_i, 0),
			},
		},
	})


func _stack_action(action: Dictionary) -> void:
	_action_stack.append(action)
	_update_action_stack_status()


func _enqueue_action_stack(action_stack: Array[Dictionary]) -> void:
	var action_batches := _create_ordered_action_batches(action_stack)
	for action_batch: Array[Dictionary] in action_batches:
		action_queue.enQueue(action_batch)


func _create_ordered_action_batches(action_stack: Array[Dictionary]) -> Array[Array]:
	var actions_by_category := {
		ACTION_CATEGORY_CAST: [],
		ACTION_CATEGORY_MOVE: [],
		ACTION_CATEGORY_ATTACK: [],
	}

	for action: Dictionary in action_stack:
		var category := _get_action_category(action)
		if category == &"":
			push_warning("Cannot categorize debugger action: %s." % action)
			continue

		actions_by_category[category].append(action)

	var action_batches: Array[Array] = []
	for category: StringName in ACTION_CATEGORY_ORDER:
		var category_actions: Array = actions_by_category[category]
		if category_actions.is_empty():
			continue

		action_batches.append(category_actions)

	return action_batches


func _get_action_category(action: Dictionary) -> StringName:
	if action.has("category"):
		return StringName(str(action["category"]))

	match action.get("eventName", ""):
		"cast", "perform_cast":
			return ACTION_CATEGORY_CAST
		"move_entity":
			return ACTION_CATEGORY_MOVE
		"perform_attack":
			return ACTION_CATEGORY_ATTACK
		_:
			return &""


func _update_action_stack_status() -> void:
	if action_stack_label != null:
		action_stack_label.text = "Stack: %d" % _action_stack.size()

	if send_batch_button != null:
		send_batch_button.disabled = _action_stack.is_empty()


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


func _get_random_move_options() -> Array[Dictionary]:
	var board: Dictionary = state_store.get_value(&"board", {})
	var options: Array[Dictionary] = []
	var cells: Array = board.get(&"cells", [])

	for i in cells.size():
		var col_cells: Array = cells[i]
		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			var entity_ids := _get_cell_entity_ids(cell)

			for entity_id: StringName in entity_ids:
				for vector: Vector2i in RANDOM_MOVE_VECTORS:
					var target_cell := Vector2i(i, j) + vector
					if _has_board_cell(board, target_cell):
						options.append({
							"entity_id": entity_id,
							"vector": vector,
							"target_cell": target_cell,
						})

	options.shuffle()
	return options


func _get_distinct_target_move_options(options: Array[Dictionary]) -> Array[Dictionary]:
	for first_option: Dictionary in options:
		for second_option: Dictionary in options:
			if first_option == second_option:
				continue

			if first_option["entity_id"] == second_option["entity_id"]:
				continue

			if first_option["target_cell"] == second_option["target_cell"]:
				continue

			return [first_option, second_option]

	return []


func _get_cell_entity_ids(cell: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for entity_id: Variant in cell.get(&"entity_ids", []):
		var entity_string_name := StringName(str(entity_id))
		if not result.has(entity_string_name):
			result.append(entity_string_name)

	var legacy_entity_id := StringName(str(cell.get(&"entity_id", &"")))
	if legacy_entity_id != &"" and not result.has(legacy_entity_id):
		result.append(legacy_entity_id)

	return result


func _has_board_cell(board: Dictionary, cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < int(board.get(&"cols", 0))
		and cell.y < int(board.get(&"rows", 0))
	)
