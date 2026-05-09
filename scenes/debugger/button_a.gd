extends Button

@onready var action_queue: Node = $"../../ActionQueue"
@onready var state_store: Node = $"../../StateStore"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var board: Dictionary = state_store.get_value(&"board", {})
	if board.is_empty():
		push_warning("Cannot move entity before board is spawned.")
		return

	var entity_id := _get_latest_entity_id()
	if entity_id == &"":
		push_warning("Cannot move entity before entity is spawned.")
		return

	action_queue.enQueue({
		"eventName": "move_entity",
		"payload": {
			"id": entity_id,
			"vector": Vector2i(
				randi_range(-int(board.get(&"cols", 1)) + 1, int(board.get(&"cols", 1)) - 1),
				randi_range(-int(board.get(&"rows", 1)) + 1, int(board.get(&"rows", 1)) - 1)
			),
		},
	})


func _get_latest_entity_id() -> StringName:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	var latest_entity_id := &""

	for entity_id: Variant in entities:
		latest_entity_id = entity_id

	return latest_entity_id


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
