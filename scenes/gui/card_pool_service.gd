extends RefCounted

const ENTITY_CARD_POOL_SIZE := 5

var _state_store: Node
var _cards: Array[Dictionary] = _load_card_templates()


func _init(state_store: Node) -> void:
	_state_store = state_store


static func _load_card_templates() -> Array[Dictionary]:
	var file := FileAccess.open("res://scenes/gui/card_templates.json", FileAccess.READ)
	if file == null:
		push_error("Failed to open card_templates.json")
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("card_templates.json must be a JSON object")
		return []
	var result: Array[Dictionary] = []
	for id: String in (parsed as Dictionary):
		var item: Variant = (parsed as Dictionary)[id]
		if item is Dictionary:
			var entry := (item as Dictionary).duplicate()
			entry["id"] = id
			result.append(entry)
	return result


func set_cards(cards: Array[Dictionary]) -> void:
	_cards = cards.duplicate(true)


func ensure_card_pool_for_entity(entity_id: StringName) -> void:
	if _state_store == null or entity_id == &"":
		return
	if _state_store.has_entity_card_pool(entity_id):
		return
	_state_store.set_entity_card_pool(entity_id, _create_random_card_pool())


func ensure_card_pools_for_entities(entities: Dictionary) -> void:
	if _state_store == null:
		return

	for raw_entity_id: Variant in entities:
		var entity_id := StringName(str(raw_entity_id))
		if entity_id == &"" or _state_store.has_entity_card_pool(entity_id):
			continue

		_state_store.set_entity_card_pool(entity_id, _create_random_card_pool())


func get_cards_by_ids(ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: Variant in ids:
		var id_str := str(id)
		for card: Dictionary in _cards:
			if card.get("id", "") == id_str:
				result.append(card.duplicate(true))
				break
			
	return result


func get_current_entity_cards(entity_id: StringName) -> Array[Dictionary]:
	if _state_store == null:
		return _cards.duplicate(true)
	if entity_id == &"":
		return []

	return _state_store.get_entity_card_pool(entity_id)


func _create_random_card_pool() -> Array[Dictionary]:
	var card_pool: Array[Dictionary] = []
	var available_cards := _cards.duplicate(true)
	available_cards.shuffle()

	var count := mini(ENTITY_CARD_POOL_SIZE, available_cards.size())
	for index in count:
		var card: Dictionary = available_cards[index]
		card_pool.append(card.duplicate(true))

	return card_pool
