extends Button

@onready var action_queue: Node = $"../../ActionQueue"
@onready var state_store: Node = $"../../StateStore"


func _ready() -> void:
	randomize()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var board: Dictionary = state_store.get_value(&"board", {})
	if board.is_empty():
		push_warning("Cannot perform attack before board is spawned.")
		return

	var attacker_id := _get_random_entity_id()
	if attacker_id == &"":
		push_warning("Cannot perform attack before an entity is spawned.")
		return

	var target_cell := _get_random_board_cell(board)
	action_queue.enQueue({
		"eventName": "perform_attack",
		"payload": {
			"id": attacker_id,
			"args": {
				"source": "debugger",
				"target_cell": target_cell,
			},
		},
	})


func _get_random_entity_id() -> StringName:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	if entities.is_empty():
		return &""

	var entity_ids: Array[StringName] = []
	for entity_id: Variant in entities:
		entity_ids.append(StringName(str(entity_id)))

	return entity_ids[randi_range(0, entity_ids.size() - 1)]


func _get_random_board_cell(board: Dictionary) -> Dictionary:
	return {
		"i": randi_range(0, int(board.get(&"cols", 1)) - 1),
		"j": randi_range(0, int(board.get(&"rows", 1)) - 1),
	}
