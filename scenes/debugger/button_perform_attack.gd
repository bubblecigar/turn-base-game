extends Button

const ATTACK_TYPE_BUMP := "bump"

@onready var action_queue: Node = $"../../ActionQueue"
@onready var state_store: Node = $"../../BattleStateStore"


func _ready() -> void:
	randomize()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var board: Dictionary = state_store.get_value(&"board", {})
	if board.is_empty():
		push_warning("Cannot perform attack before board is spawned.")
		return

	var attacker_id := _get_random_attacker_id()
	if attacker_id == &"":
		push_warning("Cannot perform attack before an entity is spawned.")
		return

	var attack_vector := _get_random_attack_vector()
	if attack_vector == Vector2i.ZERO:
		push_warning("Cannot perform attack without an attack vector.")
		return

	action_queue.enQueue([{
		"eventName": "perform_attack",
		"payload": {
			"id": attacker_id,
			"args": {
				"type": ATTACK_TYPE_BUMP,
				"damage": randi_range(1, 9),
				"source": "debugger",
				"vector": attack_vector,
			},
		},
	}])


func _get_random_attacker_id() -> StringName:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	if entities.is_empty():
		return &""

	var entity_ids: Array[StringName] = []
	for entity_id: Variant in entities:
		entity_ids.append(StringName(str(entity_id)))

	return entity_ids[randi_range(0, entity_ids.size() - 1)]


func _get_random_attack_vector() -> Vector2i:
	var vectors := [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]
	return vectors[randi_range(0, vectors.size() - 1)]
