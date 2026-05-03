extends Node2D

const CHARACTER_SCENE := preload("res://scenes/visuals/CharacterScene.tscn")

@onready var state_store: Node = $"../../StateStore"

var _entity_views: Dictionary = {}


func _ready() -> void:
	state_store.entities_updated.connect(_on_entities_updated)
	sync_entities(state_store.get_value(&"entities", {}))


func _on_entities_updated(entities: Dictionary, _previous_entities: Variant) -> void:
	sync_entities(entities)


func sync_entities(entities: Dictionary) -> void:
	for entity_id: Variant in entities:
		if _entity_views.has(entity_id):
			continue

		var character_view: Node2D = CHARACTER_SCENE.instantiate()
		character_view.set_entity_id(entity_id)
		add_child(character_view)
		_entity_views[entity_id] = character_view

	var removed_entity_ids: Array = []
	for entity_id: Variant in _entity_views:
		if not entities.has(entity_id):
			removed_entity_ids.append(entity_id)

	for entity_id: Variant in removed_entity_ids:
		var character_view: Node = _entity_views[entity_id]
		_entity_views.erase(entity_id)
		remove_child(character_view)
		character_view.queue_free()
