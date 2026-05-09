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

	var attack_pair := _get_random_attack_pair()
	if attack_pair.is_empty():
		push_warning("Cannot perform attack before at least two entities are spawned.")
		return

	var target_cell := _get_entity_board_cell(board, attack_pair["target_id"])
	if target_cell.is_empty():
		push_warning("Cannot perform attack against entity outside board: %s." % attack_pair["target_id"])
		return

	action_queue.enQueue({
		"eventName": "perform_attack",
		"payload": {
			"id": attack_pair["attacker_id"],
			"args": {
				"damage": randi_range(1, 9),
				"source": "debugger",
				"target_id": attack_pair["target_id"],
				"target_cell": target_cell,
			},
		},
	})


func _get_random_attack_pair() -> Dictionary:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	if entities.size() < 2:
		return {}

	var entity_ids: Array[StringName] = []
	for entity_id: Variant in entities:
		entity_ids.append(StringName(str(entity_id)))

	var attacker_index := randi_range(0, entity_ids.size() - 1)
	var attacker_id := entity_ids[attacker_index]
	entity_ids.remove_at(attacker_index)
	var target_id := entity_ids[randi_range(0, entity_ids.size() - 1)]

	return {
		"attacker_id": attacker_id,
		"target_id": target_id,
	}


func _get_entity_board_cell(board: Dictionary, entity_id: StringName) -> Dictionary:
	var cells: Array = board.get(&"cells", [])
	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _cell_has_entity_id(cell, entity_id):
				return {
					"i": i,
					"j": j,
				}

	return {}


func _cell_has_entity_id(cell: Dictionary, entity_id: StringName) -> bool:
	var entity_ids: Array = cell.get(&"entity_ids", [])
	return entity_ids.has(entity_id) or cell.get(&"entity_id", &"") == entity_id
