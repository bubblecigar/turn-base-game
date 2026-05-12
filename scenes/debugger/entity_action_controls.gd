extends Control

const DAMAGE_MIN := 1
const DAMAGE_MAX := 9
const ATTACK_TYPE_BUMP := "bump"
const ATTACK_TYPE_STRONG_BUMP := "strong_bump"
const ATTACK_TYPE_THROW_PROJECTILE := "throw_projectile"
const STRONG_BUMP_FOCUS_COST := 3
const STRONG_BUMP_VECTOR_LENGTH := 3
const THROW_PROJECTILE_RESOURCE_COST := 0
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
@onready var strong_bump_button: Button = $StrongBumpButton
@onready var throw_projectile_button: Button = $ThrowProjectileButton
@onready var cast_button: Button = $CastButton
@onready var cast_success_button: Button = $CastSuccessButton
@onready var cast_interrupted_button: Button = $CastInterruptedButton
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
	strong_bump_button.pressed.connect(_on_strong_bump_pressed)
	throw_projectile_button.pressed.connect(_on_throw_projectile_pressed)
	cast_button.pressed.connect(_on_cast_pressed)
	cast_success_button.pressed.connect(_on_cast_success_pressed)
	cast_interrupted_button.pressed.connect(_on_cast_interrupted_pressed)
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


func _on_strong_bump_pressed() -> void:
	_strong_bump_selected_cell(STRONG_BUMP_VECTOR_LENGTH)


func _on_throw_projectile_pressed() -> void:
	_throw_projectile_selected_cell(1)


func _on_cast_pressed() -> void:
	_cast_selected_entity()


func _on_cast_success_pressed() -> void:
	_resolve_selected_cast(true)


func _on_cast_interrupted_pressed() -> void:
	_resolve_selected_cast(false)


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
	strong_bump_button.disabled = not has_entity
	throw_projectile_button.disabled = not has_entity
	cast_button.disabled = not has_entity
	cast_success_button.disabled = not has_entity
	cast_interrupted_button.disabled = not has_entity
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

	_stack_action(_create_attack_action(_selected_entity_id, ATTACK_TYPE_BUMP, Vector2i(delta_i, 0), randi_range(DAMAGE_MIN, DAMAGE_MAX)))


func _strong_bump_selected_cell(delta_i: int) -> void:
	if _selected_entity_id == &"":
		push_warning("Select an entity before attacking.")
		return

	_stack_action(_create_attack_action(_selected_entity_id, ATTACK_TYPE_STRONG_BUMP, Vector2i(delta_i, 0), randi_range(DAMAGE_MIN, DAMAGE_MAX), STRONG_BUMP_FOCUS_COST))


func _throw_projectile_selected_cell(delta_i: int) -> void:
	if _selected_entity_id == &"":
		push_warning("Select an entity before attacking.")
		return

	_stack_action(_create_attack_action(_selected_entity_id, ATTACK_TYPE_THROW_PROJECTILE, Vector2i(delta_i, 0), randi_range(DAMAGE_MIN, DAMAGE_MAX), THROW_PROJECTILE_RESOURCE_COST))


func _create_attack_action(entity_id: StringName, attack_type: String, vector: Vector2i, damage: int, resource: Variant = null) -> Dictionary:
	var args := {
		"type": attack_type,
		"damage": damage,
		"source": "debugger",
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


func _cast_selected_entity() -> void:
	if _selected_entity_id == &"":
		push_warning("Select an entity before casting.")
		return

	_stack_action({
		"eventName": "perform_cast",
		"payload": {
			"id": _selected_entity_id,
			"args": {
				"type": "focus",
				"value": 1,
			},
		},
	})


func _resolve_selected_cast(result: bool) -> void:
	if _selected_entity_id == &"":
		push_warning("Select an entity before resolving cast.")
		return

	_stack_action(_create_resolve_cast_action(_selected_entity_id, result))


func _create_resolve_cast_action(entity_id: StringName, result: bool) -> Dictionary:
	return {
		"eventName": "resolve_cast",
		"payload": {
			"entity_id": entity_id,
			"result": result,
		},
	}


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

	var cast_success_batch := _create_cast_success_batch(action_stack)
	if not cast_success_batch.is_empty():
		action_batches.append(cast_success_batch)

	return action_batches


func _create_cast_success_batch(action_stack: Array[Dictionary]) -> Array[Dictionary]:
	var entity_ids := _get_casting_entity_ids()

	for action: Dictionary in action_stack:
		if action.get("eventName", "") != "perform_cast":
			continue

		var payload: Dictionary = action.get("payload", {})
		var entity_id := StringName(str(payload.get("id", &"")))
		if entity_id != &"" and not entity_ids.has(entity_id):
			entity_ids.append(entity_id)

	var batch: Array[Dictionary] = []
	for entity_id: StringName in entity_ids:
		batch.append(_create_resolve_cast_action(entity_id, true))

	return batch


func _get_casting_entity_ids() -> Array[StringName]:
	var entity_ids: Array[StringName] = []
	var entities: Dictionary = state_store.get_value(&"entities", {})

	for entity_id: Variant in entities:
		var entity: Dictionary = entities[entity_id]
		if StringName(str(entity.get(&"state", &"idle"))) != &"casting":
			continue

		entity_ids.append(StringName(str(entity_id)))

	return entity_ids


func _get_action_category(action: Dictionary) -> StringName:
	if action.has("category"):
		return StringName(str(action["category"]))

	match action.get("eventName", ""):
		"cast", "perform_cast", "resolve_cast":
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
