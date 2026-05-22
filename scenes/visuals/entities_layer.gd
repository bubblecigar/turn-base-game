extends Node2D

const CHARACTER_SCENE := preload("res://scenes/visuals/CharacterScene.tscn")
const SLIME_SCENE := preload("res://scenes/visuals/SlimeScene.tscn")

const STATE_STORE_PATH := NodePath("../../../BattleStateStore")
const ACTION_HANDLER_PATH := NodePath("../../../ActionHandler")
const ANIMATION_TRACKER_PATH := NodePath("../../../AnimationTracker")
const BOARD_VIEW_PATH := NodePath("../../BoardView")
const COLLISION_PAYLOAD_ATTACK := &"attack"
const CAST_TYPE_SUMMON_THUNDER := "summon_thunder"
const THUNDER_STRIKE_ANIMATION_NAME := &"thunder_strike"
const THUNDER_STRIKE_SECONDS := 0.32
const THUNDER_STRIKE_COLOR := Color(0.95, 0.98, 1.0, 1.0)
const THUNDER_FLASH_COLOR := Color(0.45, 0.75, 1.0, 0.35)

@onready var state_store: Node = $"../../BattleStateStore"
@onready var action_handler: Node = $"../../ActionHandler"
@onready var animation_tracker: Node = $"../../AnimationTracker"
@onready var board_view: Node = $"../BoardView"

var _entity_views: Dictionary = {}


func _ready() -> void:
	state_store.entities_updated.connect(_on_entities_updated)
	action_handler.cast_resolved.connect(_on_cast_resolved)
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
		entity_view.entities_collided.connect(_on_entities_collided)
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


func _on_entities_collided(entity_id: StringName, collided_entity_ids: Array[StringName], payload: Dictionary) -> void:
	match payload.get(&"type", &""):
		COLLISION_PAYLOAD_ATTACK:
			_apply_attack_collision(entity_id, collided_entity_ids, payload.get(&"args", {}))


func _apply_attack_collision(attacker_id: StringName, target_entity_ids: Array[StringName], args: Dictionary) -> void:
	var damage := int(args.get("damage", 0))

	for target_entity_id: StringName in target_entity_ids:
		if target_entity_id == attacker_id:
			continue

		if not _entity_views.has(target_entity_id):
			continue

		var entity_view: EntityBoardView = _entity_views[target_entity_id]
		state_store.damage_entity(target_entity_id, damage)
		entity_view.play_hit_visual(attacker_id, args)


func _on_cast_resolved(caster_id: StringName, args: Dictionary, result: bool) -> void:
	if not result or str(args.get("type", "")) != CAST_TYPE_SUMMON_THUNDER:
		return

	_play_thunder_strike_visual(args)
	_play_summon_thunder_hit_visual(caster_id, args)


func _play_summon_thunder_hit_visual(caster_id: StringName, args: Dictionary) -> void:
	var target_entity_id := StringName(str(args.get(&"target_entity_id", &"")))
	if target_entity_id == &"" or not _entity_views.has(target_entity_id):
		return

	var hit_args := args.duplicate(true)
	hit_args["damage"] = int(args.get("value", 0))
	var entity_view: EntityBoardView = _entity_views[target_entity_id]
	entity_view.play_hit_visual(caster_id, hit_args)


func _play_thunder_strike_visual(args: Dictionary) -> void:
	if animation_tracker == null or board_view == null:
		return

	var target_position := _get_cast_target_cell_center(args)
	if target_position == Vector2.INF:
		return

	var board: Dictionary = state_store.get_value(&"board", {})
	var cell_size: Vector2 = board.get(&"cell_size", Vector2.ZERO)
	var strike_height := cell_size.y * 1.8
	var half_width := cell_size.x * 0.28
	var root := Node2D.new()
	root.position = target_position
	add_child(root)

	var bolt := Line2D.new()
	bolt.width = 5.0
	bolt.default_color = THUNDER_STRIKE_COLOR
	bolt.points = PackedVector2Array([
		Vector2(-half_width * 0.4, -strike_height),
		Vector2(half_width * 0.25, -strike_height * 0.62),
		Vector2(-half_width * 0.15, -strike_height * 0.28),
		Vector2(half_width * 0.18, cell_size.y * 0.16),
	])
	root.add_child(bolt)

	var flash := Polygon2D.new()
	flash.color = THUNDER_FLASH_COLOR
	flash.polygon = PackedVector2Array([
		Vector2(0.0, -cell_size.y * 0.28),
		Vector2(cell_size.x * 0.36, 0.0),
		Vector2(0.0, cell_size.y * 0.28),
		Vector2(-cell_size.x * 0.36, 0.0),
	])
	root.add_child(flash)

	var animation_id: StringName = animation_tracker.register_animation(THUNDER_STRIKE_ANIMATION_NAME)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 0.0, THUNDER_STRIKE_SECONDS)
	tween.tween_property(root, "scale", Vector2(1.18, 1.18), THUNDER_STRIKE_SECONDS)
	tween.finished.connect(_on_thunder_strike_finished.bind(root, animation_id))


func _on_thunder_strike_finished(root: Node2D, animation_id: StringName) -> void:
	if root != null:
		root.queue_free()

	if animation_tracker != null:
		animation_tracker.consume_animation(animation_id)


func _get_cast_target_cell_center(args: Dictionary) -> Vector2:
	var target_cell: Variant = args.get("target_cell", {})
	if not (target_cell is Dictionary and target_cell.has("i") and target_cell.has("j")):
		return Vector2.INF

	var i := int(target_cell["i"])
	var j := int(target_cell["j"])
	return board_view.position + board_view.index_to_position(i, j)


func _get_entity_scene(entity: Dictionary) -> PackedScene:
	match entity.get(&"type", &""):
		&"character":
			return CHARACTER_SCENE
		&"slime":
			return SLIME_SCENE
		_:
			push_warning("Unsupported entity type: %s." % entity.get(&"type", &""))
			return null
