extends Node2D

const CHARACTER_SCENE := preload("res://scenes/visuals/CharacterScene.tscn")
const SLIME_SCENE := preload("res://scenes/visuals/SlimeScene.tscn")

const STATE_STORE_PATH := NodePath("../../../StateStore")
const ACTION_HANDLER_PATH := NodePath("../../../ActionHandler")
const ANIMATION_TRACKER_PATH := NodePath("../../../AnimationTracker")
const BOARD_VIEW_PATH := NodePath("../../BoardView")

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

		var entity: Variant = entities[entity_id]
		if not entity is Dictionary:
			continue

		var entity_scene: PackedScene = _get_entity_scene(entity)
		if entity_scene == null:
			continue

		var entity_view: EntityBoardView = entity_scene.instantiate() as EntityBoardView
		entity_view.state_store_path = STATE_STORE_PATH
		entity_view.action_handler_path = ACTION_HANDLER_PATH
		entity_view.animation_tracker_path = ANIMATION_TRACKER_PATH
		entity_view.board_view_path = BOARD_VIEW_PATH
		entity_view.set_entity_id(entity_id)
		entity_view.attack_target_cell_reached.connect(_on_attack_target_cell_reached)
		add_child(entity_view)
		_entity_views[entity_id] = entity_view

	var removed_entity_ids: Array = []
	for entity_id: Variant in _entity_views:
		if not entities.has(entity_id):
			removed_entity_ids.append(entity_id)

	for entity_id: Variant in removed_entity_ids:
		var character_view: Node = _entity_views[entity_id]
		_entity_views.erase(entity_id)
		remove_child(character_view)
		character_view.queue_free()


func _on_attack_target_cell_reached(attacker_id: StringName, target_cell: Dictionary, args: Dictionary) -> void:
	for entity_id: Variant in _entity_views:
		if StringName(str(entity_id)) == attacker_id:
			continue

		var entity_view: EntityBoardView = _entity_views[entity_id]
		if entity_view.is_in_board_cell(target_cell):
			entity_view.play_hit_visual(attacker_id, args)


func _get_entity_scene(entity: Dictionary) -> PackedScene:
	match entity.get(&"type", &""):
		&"character":
			return CHARACTER_SCENE
		&"slime":
			return SLIME_SCENE
		_:
			push_warning("Unsupported entity type: %s." % entity.get(&"type", &""))
			return null
