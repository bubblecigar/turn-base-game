extends Button

@onready var action_queue: Node = $"../../ActionQueue"
@onready var state_store: Node = $"../../StateStore"


func _ready() -> void:
	randomize()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var attack_pair := _get_attack_pair()
	if attack_pair.is_empty():
		push_warning("Cannot attack before at least two entities are spawned.")
		return

	action_queue.enQueue({
		"eventName": "attack_entity",
		"payload": attack_pair,
	})


func _get_attack_pair() -> Dictionary:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	if entities.size() < 2:
		return {}

	var entity_ids := _get_entity_ids(entities)
	var attacker_index := randi_range(0, entity_ids.size() - 1)
	var attacker_id: StringName = entity_ids[attacker_index]
	entity_ids.remove_at(attacker_index)
	var target_id: StringName = entity_ids[randi_range(0, entity_ids.size() - 1)]

	return {
		"attacker_id": attacker_id,
		"target_id": target_id,
	}


func _get_entity_ids(entities: Dictionary) -> Array[StringName]:
	var entity_ids: Array[StringName] = []

	for entity_id: Variant in entities:
		entity_ids.append(StringName(str(entity_id)))

	return entity_ids
