extends Node

signal status_changed(status: String)

const DAMAGE_MIN := 1
const DAMAGE_MAX := 9
const ATTACK_TYPE_BUMP := "bump"
const ACTION_CATEGORY_CAST := &"cast"
const ACTION_CATEGORY_MOVE := &"move"
const ACTION_CATEGORY_ATTACK := &"attack"
const ACTION_CATEGORY_ORDER := [
	ACTION_CATEGORY_CAST,
	ACTION_CATEGORY_MOVE,
	ACTION_CATEGORY_ATTACK,
]
const ATTACK_VECTORS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
]
const MOVE_VECTORS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

@onready var action_queue: Node = $"../ActionQueue"
@onready var state_store: Node = $"../StateStore"

var _board_initialized := false
var _turn_in_progress := false
var _game_over := false
var _turn_index := 0
var _running := false


func _ready() -> void:
	randomize()
	_board_initialized = not state_store.get_value(&"board", {}).is_empty()
	state_store.board_init.connect(_on_board_init)
	action_queue.queue_drained.connect(_on_queue_drained)
	_emit_status("waiting to start")


func start() -> void:
	_running = true
	_emit_status("started")
	call_deferred("_maybe_start_next_turn")


func _on_board_init(_board: Dictionary, _previous_board: Variant) -> void:
	_board_initialized = true
	_emit_status("board ready")
	if _running:
		call_deferred("_maybe_start_next_turn")


func _on_queue_drained() -> void:
	if not _running:
		return

	if not _turn_in_progress:
		call_deferred("_maybe_start_next_turn")
		return

	_turn_in_progress = false
	if _check_for_winner():
		return

	call_deferred("_maybe_start_next_turn")


func _maybe_start_next_turn() -> void:
	if _game_over or _turn_in_progress or not _board_initialized or not action_queue.is_idle():
		return

	if _check_for_winner():
		return

	var action_stack := _create_turn_actions()
	var action_batches := _create_ordered_action_batches(action_stack)
	if action_batches.is_empty():
		return

	_turn_in_progress = true
	_turn_index += 1
	_emit_status("turn %d: queued %d actions" % [_turn_index, action_stack.size()])
	print("game loop turn %d actions: %s" % [_turn_index, action_stack])
	for action_batch: Array[Dictionary] in action_batches:
		action_queue.enQueue(action_batch)


func _create_turn_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var entities: Dictionary = state_store.get_value(&"entities", {})
	var alive_entity_ids := _get_alive_entity_ids()

	for entity_id: StringName in alive_entity_ids:
		var entity: Dictionary = entities.get(entity_id, {})
		if StringName(str(entity.get(&"state", &"idle"))) == &"casting":
			continue

		var action := _create_random_entity_action(entity_id, alive_entity_ids)
		if not action.is_empty():
			actions.append(action)

	return actions


func _create_random_entity_action(entity_id: StringName, alive_entity_ids: Array[StringName]) -> Dictionary:
	var options: Array[Dictionary] = []
	var attack_action := _create_random_attack_action(entity_id)
	if not attack_action.is_empty():
		options.append(attack_action)

	var move_action := _create_random_move_action(entity_id)
	if not move_action.is_empty():
		options.append(move_action)

	options.append(_create_cast_action(entity_id))
	options.shuffle()
	return options.front()


func _create_random_attack_action(entity_id: StringName) -> Dictionary:
	var board: Dictionary = state_store.get_value(&"board", {})
	var own_cell := _get_entity_board_index(entity_id)
	if own_cell == Vector2i(-1, -1):
		return {}

	var valid_vectors: Array[Vector2i] = []
	for vector: Vector2i in ATTACK_VECTORS:
		if _has_board_cell(board, own_cell + vector):
			valid_vectors.append(vector)

	if valid_vectors.is_empty():
		return {}

	return {
		"eventName": "perform_attack",
		"payload": {
			"id": entity_id,
			"args": {
				"type": ATTACK_TYPE_BUMP,
				"damage": randi_range(DAMAGE_MIN, DAMAGE_MAX),
				"source": "game_loop",
				"vector": valid_vectors[randi_range(0, valid_vectors.size() - 1)],
			},
		},
	}


func _create_random_move_action(entity_id: StringName) -> Dictionary:
	var board: Dictionary = state_store.get_value(&"board", {})
	var own_cell := _get_entity_board_index(entity_id)
	if own_cell == Vector2i(-1, -1):
		return {}

	var move_vectors: Array[Vector2i] = []
	for vector: Vector2i in MOVE_VECTORS:
		if _has_board_cell(board, own_cell + vector):
			move_vectors.append(vector)

	if move_vectors.is_empty():
		return {}

	return {
		"eventName": "move_entity",
		"payload": {
			"id": entity_id,
			"vector": move_vectors[randi_range(0, move_vectors.size() - 1)],
		},
	}


func _create_cast_action(entity_id: StringName) -> Dictionary:
	return {
		"eventName": "perform_cast",
		"payload": {
			"id": entity_id,
			"args": {
				"type": "focus",
				"value": 1,
			},
		},
	}


func _create_ordered_action_batches(action_stack: Array[Dictionary]) -> Array[Array]:
	var actions_by_category := {
		ACTION_CATEGORY_CAST: [],
		ACTION_CATEGORY_MOVE: [],
		ACTION_CATEGORY_ATTACK: [],
	}

	for action: Dictionary in action_stack:
		var category := _get_action_category(action)
		if category == &"":
			push_warning("Cannot categorize game loop action: %s." % action)
			continue

		actions_by_category[category].append(action)

	var action_batches: Array[Array] = []

	var attack_batch: Array = actions_by_category[ACTION_CATEGORY_ATTACK]
	var prepare_attack_batch := _create_prepare_attack_batch(attack_batch)

	var cast_move_batch: Array = []
	cast_move_batch.append_array(actions_by_category[ACTION_CATEGORY_CAST])
	cast_move_batch.append_array(actions_by_category[ACTION_CATEGORY_MOVE])
	cast_move_batch.append_array(prepare_attack_batch)
	if not cast_move_batch.is_empty():
		action_batches.append(cast_move_batch)

	if not attack_batch.is_empty():
		action_batches.append(attack_batch)

	var cast_success_batch := _create_cast_success_batch(action_stack)
	if not cast_success_batch.is_empty():
		action_batches.append(cast_success_batch)

	return action_batches


func _create_prepare_attack_batch(attack_actions: Array) -> Array[Dictionary]:
	var batch: Array[Dictionary] = []
	for action: Dictionary in attack_actions:
		var payload: Dictionary = action.get("payload", {})
		batch.append({
			"eventName": "prepare_attack",
			"payload": payload.duplicate(true),
		})
	return batch


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


func _create_resolve_cast_action(entity_id: StringName, result: bool) -> Dictionary:
	return {
		"eventName": "resolve_cast",
		"payload": {
			"entity_id": entity_id,
			"result": result,
		},
	}


func _get_action_category(action: Dictionary) -> StringName:
	match action.get("eventName", ""):
		"cast", "perform_cast", "resolve_cast":
			return ACTION_CATEGORY_CAST
		"move_entity":
			return ACTION_CATEGORY_MOVE
		"perform_attack":
			return ACTION_CATEGORY_ATTACK
		_:
			return &""


func _check_for_winner() -> bool:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	if entities.is_empty():
		return false

	var living_entity_ids := _get_alive_entity_ids()
	var dead_entity_ids: Array[StringName] = []
	for entity_id: Variant in entities:
		var entity_string_name := StringName(str(entity_id))
		if not living_entity_ids.has(entity_string_name):
			dead_entity_ids.append(entity_string_name)

	if dead_entity_ids.is_empty():
		return false

	_game_over = true
	if living_entity_ids.is_empty():
		print("game over: no winner")
		_emit_status("game over: no winner")
	else:
		print("game over winner: %s" % living_entity_ids)
		_emit_status("game over winner: %s" % living_entity_ids)

	return true


func _emit_status(status: String) -> void:
	status_changed.emit(status)
	print("game loop status: %s" % status)


func _get_alive_entity_ids() -> Array[StringName]:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	var alive_entity_ids: Array[StringName] = []

	for entity_id: Variant in entities:
		var entity: Dictionary = entities[entity_id]
		if int(entity.get(&"current_hp", 0)) > 0:
			alive_entity_ids.append(StringName(str(entity_id)))

	return alive_entity_ids


func _get_casting_entity_ids() -> Array[StringName]:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	var entity_ids: Array[StringName] = []

	for entity_id: Variant in entities:
		var entity: Dictionary = entities[entity_id]
		if StringName(str(entity.get(&"state", &"idle"))) == &"casting":
			entity_ids.append(StringName(str(entity_id)))

	return entity_ids


func _get_entity_board_index(entity_id: StringName) -> Vector2i:
	var board: Dictionary = state_store.get_value(&"board", {})
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


func _has_board_cell(board: Dictionary, cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < int(board.get(&"cols", 0))
		and cell.y < int(board.get(&"rows", 0))
	)
