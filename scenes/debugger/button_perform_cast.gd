extends Button

@onready var action_queue: Node = $"../../ActionQueue"
@onready var state_store: Node = $"../../StateStore"


func _ready() -> void:
	randomize()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var board: Dictionary = state_store.get_value(&"board", {})
	if board.is_empty():
		push_warning("Cannot perform cast before board is spawned.")
		return

	var caster_id := _get_random_entity_id()
	if caster_id == &"":
		push_warning("Cannot perform cast before an entity is spawned.")
		return

	action_queue.enQueue([{
		"eventName": "perform_cast",
		"payload": {
			"id": caster_id,
			"args": {
				"type": "focus",
				"value": randi_range(1, 9),
			},
		},
	}])


func _get_random_entity_id() -> StringName:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	if entities.is_empty():
		return &""

	var entity_ids: Array[StringName] = []
	for entity_id: Variant in entities:
		entity_ids.append(StringName(str(entity_id)))

	return entity_ids[randi_range(0, entity_ids.size() - 1)]
