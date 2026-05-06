extends Button

@onready var action_queue: Node = $"../../ActionQueue"
@onready var state_store: Node = $"../../StateStore"


func _ready() -> void:
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

	var attacker_id := _get_first_entity_id_by_type(entities, &"character")
	if attacker_id == &"":
		attacker_id = _get_first_entity_id(entities)

	var target_id := _get_first_other_entity_id(entities, attacker_id)
	if target_id == &"":
		return {}

	return {
		"attacker_id": attacker_id,
		"target_id": target_id,
	}


func _get_first_entity_id_by_type(entities: Dictionary, entity_type: StringName) -> StringName:
	for entity_id: Variant in entities:
		var entity: Dictionary = entities[entity_id]
		if entity.get(&"type", &"") == entity_type:
			return StringName(str(entity_id))

	return &""


func _get_first_entity_id(entities: Dictionary) -> StringName:
	for entity_id: Variant in entities:
		return StringName(str(entity_id))

	return &""


func _get_first_other_entity_id(entities: Dictionary, attacker_id: StringName) -> StringName:
	for entity_id: Variant in entities:
		var next_entity_id := StringName(str(entity_id))
		if next_entity_id != attacker_id:
			return next_entity_id

	return &""
