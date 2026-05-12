extends Node2D

class_name EntityBoardView

signal entities_collided(entity_id: StringName, collided_entity_ids: Array[StringName], payload: Dictionary)

const MOVE_ANIMATION_SECONDS := 1.2
const MOVE_ANIMATION_NAME := &"entity_move"
const WALK_STEP_SECONDS := 0.35
const HIT_ANIMATION_SECONDS := 0.24
const HIT_ANIMATION_NAME := &"entity_hit"
const HIT_SHAKE_PIXELS := 7.0
const DAMAGE_LABEL_FONT_SIZE := 14.0
const DAMAGE_LABEL_HEIGHT := 18.0
const DAMAGE_LABEL_RISE_PIXELS := 20.0
const HP_BAR_HEIGHT := 5.0
const HP_BAR_MIN_WIDTH := 28.0
const HP_BAR_TOP_OFFSET := 12.0
const HP_TEXT_FONT_SIZE := 8.0
const HP_TEXT_HEIGHT := 12.0
const FOCUS_TEXT_FONT_SIZE := 8.0
const FOCUS_TEXT_HEIGHT := 12.0
const FOCUS_ANIMATION_SECONDS := 0.28
const FOCUS_ANIMATION_NAME := &"entity_focus"
const FOCUS_CHANGE_LABEL_FONT_SIZE := 12.0
const FOCUS_CHANGE_LABEL_HEIGHT := 16.0
const FOCUS_CHANGE_LABEL_RISE_PIXELS := 18.0
const FOCUS_GAIN_COLOR := Color(1.0, 0.88, 0.2, 1.0)
const FOCUS_SPEND_COLOR := Color(0.35, 0.75, 1.0, 1.0)
const CAST_ANIMATION_SECONDS := 1.75
const CAST_ANIMATION_NAME := &"entity_cast"
const CAST_FINISH_ANIMATION_SECONDS := 0.24
const CAST_FINISH_ANIMATION_NAME := &"entity_cast_finish"
const CAST_BOUNCE_PIXELS := 14.0
const CAST_GLOW_COLOR := Color(0.9, 0.85, 0.2, 1.0)
const CAST_RESULT_LABEL_FONT_SIZE := 12.0
const CAST_RESULT_LABEL_HEIGHT := 16.0
const CAST_RESULT_LABEL_RISE_PIXELS := 18.0
const CAST_RESULT_ANIMATION_SECONDS := 0.45
const CAST_RESULT_SUCCESS_COLOR := Color(0.25, 0.95, 0.45, 1.0)
const CAST_RESULT_INTERRUPTED_COLOR := Color(1.0, 0.35, 0.2, 1.0)
const PREPARE_ATTACK_ANIMATION_NAME := &"entity_prepare_attack"
const PREPARE_ATTACK_ANIMATION_SECONDS := 1.0
const PREPARE_ATTACK_TRAVEL_SECONDS := 0.4
const PREPARE_ATTACK_DWELL_SECONDS := 0.75
const ID_LABEL_FONT_SIZE := 8.0
const ID_LABEL_HEIGHT := 16.0
const ENTITY_AREA_NAME := "EntityArea"
const ENTITY_COLLISION_NAME := "EntityCollision"
const ENTITY_COLLISION_CELL_SCALE := 0.8
const COLLISION_PAYLOAD_ATTACK := &"attack"
const ENTITY_STATE_CASTING := &"casting"
const ATTACK_TYPE_BUMP := &"bump"
const ATTACK_TYPE_STRONG_BUMP := &"strong_bump"
const ATTACK_TYPE_THROW_PROJECTILE := &"throw_projectile"
const PROJECTILE_ATTACK_ANIMATION_NAME := &"entity_projectile_attack"
const PROJECTILE_ATTACK_SECONDS := 0.55
const PROJECTILE_ARC_HEIGHT := 52.0
const PROJECTILE_ROCK_COLOR := Color(0.35, 0.32, 0.28, 1.0)
const PROJECTILE_ROCK_BOTTOM_OFFSET := 11.0

var _entity_id := &""
var _entity: Dictionary = {}
var _entity_area: Area2D
var _entity_collision: CollisionShape2D
var _entity_collision_shape: RectangleShape2D
var _hp_bar_background: ColorRect
var _hp_bar_fill: ColorRect
var _hp_label: Label
var _focus_label: Label
var _focus_change_label: Label
var _id_label: Label
var _damage_label: Label
var _cast_result_label: Label
var _move_tween: Tween
var _hit_tween: Tween
var _damage_tween: Tween
var _focus_tween: Tween
var _focus_change_tween: Tween
var _cast_tween: Tween
var _cast_result_tween: Tween
var _prepare_attack_tween: Tween
var _projectile_tween: Tween
var _prepare_attack_mark: Node2D
var _projectile_node: Polygon2D
var _projectile_area: Area2D
var _projectile_collision: CollisionShape2D
var _projectile_collision_shape: RectangleShape2D
var _prepare_attack_animation_id := &""
var _projectile_animation_id := &""
var _move_animation_id := &""
var _hit_animation_id := &""
var _focus_animation_id := &""
var _cast_animation_id := &""
var _active_collision_payload: Dictionary = {}
var _active_collision_entity_ids: Dictionary = {}
var _active_collision_area: Area2D
var _is_moving := false
var _move_time := 0.0

@export var state_store_path: NodePath
@export var action_handler_path: NodePath
@export var animation_tracker_path: NodePath
@export var board_view_path: NodePath

@onready var state_store: Node = get_node(state_store_path)
@onready var action_handler: Node = get_node(action_handler_path)
@onready var animation_tracker: Node = get_node(animation_tracker_path)
@onready var board_view: Node = get_node(board_view_path)


func _ready() -> void:
	if state_store == null:
		return

	_create_entity_area()
	_create_id_label()
	_create_hp_bar()
	state_store.entities_updated.connect(_on_entities_updated)
	state_store.board_init.connect(_on_board_init)
	state_store.entity_moved.connect(_on_entity_moved)
	state_store.entity_focus_changed.connect(_on_entity_focus_changed)
	state_store.cast_resolved.connect(_on_cast_resolved)
	action_handler.attack_performed.connect(_on_attack_performed)
	action_handler.attack_prepared.connect(_on_attack_prepared)
	_refresh_from_state()


func _process(delta: float) -> void:
	if not _is_moving:
		return

	_move_time += delta
	_set_move_pose(sin(_move_time * TAU / WALK_STEP_SECONDS))


func set_entity_id(entity_id: Variant) -> void:
	_entity_id = StringName(str(entity_id))
	_refresh_from_state()


func get_entity_id() -> StringName:
	return _entity_id


func get_entity() -> Dictionary:
	return _entity.duplicate(true)


func is_dead() -> bool:
	return int(_entity.get(&"current_hp", 1)) <= 0


func is_in_board_cell(cell_index: Dictionary) -> bool:
	if not cell_index.has("i") or not cell_index.has("j"):
		return false

	var board: Dictionary = state_store.get_value(&"board", {})
	var own_index := _get_entity_board_index(board, _entity_id)
	return own_index == Vector2i(int(cell_index["i"]), int(cell_index["j"]))


func play_hit_visual(attacker_id: StringName, args: Dictionary = {}) -> void:
	if animation_tracker == null:
		return

	if _hit_tween:
		_hit_tween.kill()
		_consume_active_hit_animation()

	_show_damage_number(args.get("damage", null))
	var start_position := position
	var hit_direction := position - _get_entity_board_position(attacker_id)
	if hit_direction == Vector2.ZERO or hit_direction == Vector2.INF:
		hit_direction = Vector2.RIGHT

	var shake_offset := hit_direction.normalized() * HIT_SHAKE_PIXELS
	var should_shake_position := not _is_position_animation_active()
	var animation_id: StringName = animation_tracker.register_animation(HIT_ANIMATION_NAME)
	_hit_animation_id = animation_id
	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(self, "modulate", Color(1.0, 0.55, 0.55), HIT_ANIMATION_SECONDS * 0.45)
	if should_shake_position:
		_hit_tween.tween_property(self, "position", start_position + shake_offset, HIT_ANIMATION_SECONDS * 0.3)
		_hit_tween.chain().tween_property(self, "position", start_position, HIT_ANIMATION_SECONDS * 0.7)
	_hit_tween.parallel().tween_property(self, "modulate", Color.WHITE, HIT_ANIMATION_SECONDS * 0.55)
	_hit_tween.finished.connect(_on_hit_tween_finished.bind(animation_id))


func get_visual_size() -> Vector2:
	return Vector2.ZERO


func _on_entity_updated(_entity_state: Dictionary) -> void:
	pass


func _set_move_pose(_direction: float) -> void:
	pass


func _play_bump_attack_performed_visual(_args: Dictionary) -> void:
	pass


func _play_attack_performed_visual_by_args(args: Dictionary) -> void:
	var visual_callbacks := {
		ATTACK_TYPE_BUMP: Callable(self, "_play_bump_attack_performed_visual"),
		ATTACK_TYPE_STRONG_BUMP: Callable(self, "_play_bump_attack_performed_visual"),
		ATTACK_TYPE_THROW_PROJECTILE: Callable(self, "_play_throw_projectile_attack_performed_visual"),
	}
	var attack_type := StringName(str(args.get("type", &"")))
	var callback: Callable = visual_callbacks.get(attack_type, Callable())
	if not callback.is_valid():
		push_warning("Unsupported attack performed visual type: %s." % attack_type)
		return

	callback.call(args)


func _play_throw_projectile_attack_performed_visual(args: Dictionary) -> void:
	if animation_tracker == null or board_view == null:
		return

	var target_position := _get_attack_target_ground_position(args)
	if target_position == Vector2.INF:
		return

	if _projectile_tween:
		_projectile_tween.kill()
		_consume_active_projectile_animation()

	if _projectile_node == null:
		_projectile_node = Polygon2D.new()
		_projectile_node.polygon = PackedVector2Array([
			Vector2(-9.0, -7.0),
			Vector2(7.0, -9.0),
			Vector2(11.0, 4.0),
			Vector2(2.0, 11.0),
			Vector2(-11.0, 5.0),
		])
		_projectile_node.color = PROJECTILE_ROCK_COLOR
		get_parent().add_child(_projectile_node)

	_ensure_projectile_area()
	var visual_size := get_visual_size()
	var start_position := position + Vector2(visual_size.x / 2.0, -visual_size.y / 2.0)
	_projectile_node.position = start_position
	_projectile_node.rotation = 0.0
	_projectile_node.show()
	_begin_projectile_attack_collision(args, start_position)

	var animation_id: StringName = animation_tracker.register_animation(PROJECTILE_ATTACK_ANIMATION_NAME)
	_projectile_animation_id = animation_id
	_projectile_tween = create_tween()
	_projectile_tween.set_parallel(true)
	_projectile_tween.tween_method(_set_projectile_position.bind(start_position, target_position), 0.0, 1.0, PROJECTILE_ATTACK_SECONDS)
	_projectile_tween.tween_property(_projectile_node, "rotation", TAU * 1.5, PROJECTILE_ATTACK_SECONDS)
	_projectile_tween.finished.connect(_on_projectile_attack_tween_finished.bind(animation_id, args))


func _play_attack_prepared_visual(args: Dictionary) -> void:
	if animation_tracker == null or board_view == null:
		return

	if _prepare_attack_tween:
		_prepare_attack_tween.kill()
		_prepare_attack_tween = null
		if _prepare_attack_animation_id != &"":
			animation_tracker.consume_animation(_prepare_attack_animation_id)
			_prepare_attack_animation_id = &""

	var target_position := _get_attack_target_cell_center(args)
	if target_position == Vector2.INF:
		return

	var board: Dictionary = state_store.get_value(&"board", {})
	var board_index := _get_entity_board_index(board, _entity_id)
	var cell_size: Vector2 = board.get(&"cell_size", StateStore.BOARD_CELL_SIZE)
	var attacker_bottom: Vector2 = board_view.position + board_view.index_to_bottom_position(board_index.x, board_index.y)
	var start_position := attacker_bottom - Vector2(0.0, cell_size.y / 2.0)

	if _prepare_attack_mark == null:
		_prepare_attack_mark = preload("res://scenes/visuals/attack_mark.gd").new()
		get_parent().add_child(_prepare_attack_mark)

	_prepare_attack_mark.position = start_position
	_prepare_attack_mark.rotation = 0.0
	_prepare_attack_mark.modulate.a = 1.0
	_prepare_attack_mark.show()

	var animation_id: StringName = animation_tracker.register_animation(PREPARE_ATTACK_ANIMATION_NAME)
	_prepare_attack_animation_id = animation_id
	_prepare_attack_tween = create_tween()
	_prepare_attack_tween.set_parallel(true)
	_prepare_attack_tween.set_trans(Tween.TRANS_QUAD)
	_prepare_attack_tween.set_ease(Tween.EASE_IN_OUT)
	var total_seconds := PREPARE_ATTACK_TRAVEL_SECONDS + PREPARE_ATTACK_DWELL_SECONDS
	_prepare_attack_tween.tween_property(_prepare_attack_mark, "rotation", TAU * 1.0, total_seconds)
	_prepare_attack_tween.tween_property(_prepare_attack_mark, "position", target_position, PREPARE_ATTACK_TRAVEL_SECONDS)
	_prepare_attack_tween.tween_property(_prepare_attack_mark, "modulate:a", 0.0, PREPARE_ATTACK_DWELL_SECONDS * 0.35).set_delay(PREPARE_ATTACK_TRAVEL_SECONDS + PREPARE_ATTACK_DWELL_SECONDS * 0.65)
	_prepare_attack_tween.finished.connect(_on_prepare_attack_tween_finished.bind(animation_id))


func _tween_cast_finish_pose(_tween: Tween, _seconds: float) -> void:
	pass


func _play_cast_performed_visual() -> void:
	if animation_tracker == null:
		return

	if _cast_tween:
		_cast_tween.kill()
		_consume_active_cast_animation()

	var start_position := position
	var bounce_target := start_position - Vector2(0.0, CAST_BOUNCE_PIXELS)
	var animation_id: StringName = animation_tracker.register_animation(CAST_ANIMATION_NAME)
	_cast_animation_id = animation_id
	_cast_tween = create_tween()
	_cast_tween.set_trans(Tween.TRANS_QUAD)
	_cast_tween.set_ease(Tween.EASE_OUT)
	_cast_tween.set_parallel(true)
	_cast_tween.tween_property(self, "modulate", CAST_GLOW_COLOR, CAST_ANIMATION_SECONDS * 0.35)
	_cast_tween.tween_property(self, "position", bounce_target, CAST_ANIMATION_SECONDS * 0.35)
	_cast_tween.finished.connect(_on_cast_tween_finished.bind(animation_id))


func _on_entities_updated(entities: Dictionary, previous_entities: Variant) -> void:
	if _entity_id == &"" or not entities.has(_entity_id):
		return

	var next_entity: Dictionary = entities[_entity_id]
	var previous_entity := _get_previous_entity(previous_entities)
	_set_entity(next_entity)
	_update_board_position()
	if _should_play_cast_started_visual(next_entity, previous_entity):
		_play_cast_performed_visual()


func _on_board_init(board: Dictionary, previous_board: Variant) -> void:
	if previous_board is Dictionary:
		var previous_index := _get_entity_board_index(previous_board, _entity_id)
		var next_index := _get_entity_board_index(board, _entity_id)
		if previous_index != Vector2i(-1, -1) and next_index != Vector2i(-1, -1) and previous_index != next_index:
			return

	_update_board_position()
	_update_entity_area()


func _on_entity_moved(entity_id: StringName, _next_position: Vector2, _previous_position: Variant) -> void:
	if animation_tracker == null or _entity_id == &"" or entity_id != _entity_id:
		return

	var next_position := _get_board_position()
	if next_position == Vector2.INF:
		return

	if _move_tween:
		_move_tween.kill()
		_consume_active_move_animation()

	var animation_id: StringName = animation_tracker.register_animation(MOVE_ANIMATION_NAME)
	_move_animation_id = animation_id
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "position", next_position, MOVE_ANIMATION_SECONDS)
	_move_tween.finished.connect(_on_move_tween_finished.bind(animation_id))
	_start_move_animation()


func _on_entity_focus_changed(entity_id: StringName, focus: int, previous_focus: int) -> void:
	if _entity_id == &"" or entity_id != _entity_id:
		return

	_play_focus_visual()
	_show_focus_change_number(focus - previous_focus)


func _on_attack_prepared(attacker_id: StringName, _args: Dictionary) -> void:
	if _entity_id != attacker_id:
		return

	_play_attack_prepared_visual(_args)


func _on_attack_performed(attacker_id: StringName, _args: Dictionary) -> void:
	if _entity_id != attacker_id:
		return

	print("attack performed by %s with args %s" % [attacker_id, _args])
	_play_attack_performed_visual_by_args(_args)


func _on_cast_resolved(caster_id: StringName, result: bool) -> void:
	if _entity_id == &"" or caster_id != _entity_id:
		return

	_finish_cast_visual(result)


func _on_move_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _move_animation_id == animation_id:
		_move_animation_id = &""
		_move_tween = null
		_stop_move_animation()


func _on_hit_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _hit_animation_id == animation_id:
		_hit_animation_id = &""
		_hit_tween = null
		modulate = Color.WHITE
		if not _is_position_animation_active():
			_update_board_position()


func _on_focus_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _focus_animation_id == animation_id:
		_focus_animation_id = &""
		_focus_tween = null
		if _focus_label:
			_focus_label.modulate = Color.WHITE
			_focus_label.scale = Vector2.ONE


func _on_cast_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _cast_animation_id == animation_id:
		_cast_animation_id = &""
		_cast_tween = null


func _on_cast_finish_tween_finished(animation_id: StringName, result: bool) -> void:
	if _cast_animation_id == animation_id:
		_cast_tween = null
		modulate = Color.WHITE
		_update_board_position()
		_show_cast_result_text(result, animation_id)


func _consume_active_move_animation() -> void:
	if _move_animation_id == &"":
		return

	animation_tracker.consume_animation(_move_animation_id)
	_move_animation_id = &""
	_stop_move_animation()


func _consume_active_hit_animation() -> void:
	if _hit_animation_id == &"":
		return

	animation_tracker.consume_animation(_hit_animation_id)
	_hit_animation_id = &""
	modulate = Color.WHITE


func _consume_active_focus_animation() -> void:
	if _focus_animation_id == &"":
		return

	animation_tracker.consume_animation(_focus_animation_id)
	_focus_animation_id = &""
	if _focus_label:
		_focus_label.modulate = Color.WHITE
		_focus_label.scale = Vector2.ONE


func _consume_active_projectile_animation() -> void:
	if _projectile_animation_id == &"":
		return

	animation_tracker.consume_animation(_projectile_animation_id)
	_projectile_animation_id = &""
	if _projectile_node:
		_projectile_node.hide()
	_finish_projectile_attack_collision()


func _consume_active_cast_animation() -> void:
	if _cast_tween:
		_cast_tween.kill()
		_cast_tween = null

	if _cast_animation_id == &"":
		return

	animation_tracker.consume_animation(_cast_animation_id)
	_cast_animation_id = &""
	modulate = Color.WHITE


func _finish_cast_visual(result: bool) -> void:
	if _cast_tween:
		_cast_tween.kill()
		_cast_tween = null

	if _cast_animation_id != &"":
		animation_tracker.consume_animation(_cast_animation_id)
		_cast_animation_id = &""

	if animation_tracker == null:
		modulate = Color.WHITE
		_update_board_position()
		_show_cast_result_text(result)
		return

	var target_position := _get_board_position()
	if target_position == Vector2.INF:
		target_position = position

	var animation_id: StringName = animation_tracker.register_animation(CAST_FINISH_ANIMATION_NAME)
	_cast_animation_id = animation_id
	_cast_tween = create_tween()
	_cast_tween.set_trans(Tween.TRANS_QUAD)
	_cast_tween.set_ease(Tween.EASE_OUT)
	_cast_tween.set_parallel(true)
	_cast_tween.tween_property(self, "position", target_position, CAST_FINISH_ANIMATION_SECONDS)
	_cast_tween.tween_property(self, "modulate", Color.WHITE, CAST_FINISH_ANIMATION_SECONDS)
	_tween_cast_finish_pose(_cast_tween, CAST_FINISH_ANIMATION_SECONDS)
	_cast_tween.finished.connect(_on_cast_finish_tween_finished.bind(animation_id, result))


func _is_position_animation_active() -> bool:
	return _move_tween != null or _has_active_collision()


func _show_damage_number(damage: Variant) -> void:
	if damage == null:
		return

	if _damage_tween:
		_damage_tween.kill()

	if _damage_label == null:
		_damage_label = Label.new()
		_damage_label.layout_mode = 0
		_damage_label.add_theme_font_size_override("font_size", DAMAGE_LABEL_FONT_SIZE)
		_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_damage_label)

	var visual_size := get_visual_size()
	var start_position := Vector2(0.0, -DAMAGE_LABEL_HEIGHT)
	_damage_label.text = str(damage)
	_damage_label.position = start_position
	_damage_label.size = Vector2(max(visual_size.x, 1.0), DAMAGE_LABEL_HEIGHT)
	_damage_label.modulate = Color(1.0, 0.1, 0.1, 1.0)
	_damage_label.show()

	_damage_tween = create_tween()
	_damage_tween.set_parallel(true)
	_damage_tween.tween_property(_damage_label, "position", start_position - Vector2(0.0, DAMAGE_LABEL_RISE_PIXELS), HIT_ANIMATION_SECONDS)
	_damage_tween.tween_property(_damage_label, "modulate", Color(1.0, 0.1, 0.1, 0.0), HIT_ANIMATION_SECONDS)
	_damage_tween.finished.connect(_on_damage_tween_finished)


func _show_focus_change_number(focus_delta: int) -> void:
	if focus_delta == 0:
		return

	if _focus_change_tween:
		_focus_change_tween.kill()

	if _focus_change_label == null:
		_focus_change_label = Label.new()
		_focus_change_label.layout_mode = 0
		_focus_change_label.add_theme_font_size_override("font_size", FOCUS_CHANGE_LABEL_FONT_SIZE)
		_focus_change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_focus_change_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_focus_change_label)

	var visual_size := get_visual_size()
	var start_position := Vector2(0.0, -FOCUS_CHANGE_LABEL_HEIGHT - HP_TEXT_HEIGHT - FOCUS_TEXT_HEIGHT)
	_focus_change_label.text = "%+d" % focus_delta
	_focus_change_label.position = start_position
	_focus_change_label.size = Vector2(max(visual_size.x, HP_BAR_MIN_WIDTH), FOCUS_CHANGE_LABEL_HEIGHT)
	_focus_change_label.modulate = FOCUS_GAIN_COLOR if focus_delta > 0 else FOCUS_SPEND_COLOR
	_focus_change_label.show()

	_focus_change_tween = create_tween()
	_focus_change_tween.set_parallel(true)
	_focus_change_tween.tween_property(_focus_change_label, "position", start_position - Vector2(0.0, FOCUS_CHANGE_LABEL_RISE_PIXELS), FOCUS_ANIMATION_SECONDS)
	_focus_change_tween.tween_property(_focus_change_label, "modulate:a", 0.0, FOCUS_ANIMATION_SECONDS)
	_focus_change_tween.finished.connect(_on_focus_change_tween_finished)


func _show_cast_result_text(result: bool, pending_animation_id: StringName = &"") -> void:
	if _cast_result_tween:
		_cast_result_tween.kill()

	if _cast_result_label == null:
		_cast_result_label = Label.new()
		_cast_result_label.layout_mode = 0
		_cast_result_label.add_theme_font_size_override("font_size", CAST_RESULT_LABEL_FONT_SIZE)
		_cast_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cast_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_cast_result_label)

	var visual_size := get_visual_size()
	var start_position := Vector2(0.0, -CAST_RESULT_LABEL_HEIGHT)
	_cast_result_label.text = "Cast success" if result else "Cast interrupted"
	_cast_result_label.position = start_position
	_cast_result_label.size = Vector2(max(visual_size.x, HP_BAR_MIN_WIDTH), CAST_RESULT_LABEL_HEIGHT)
	_cast_result_label.modulate = CAST_RESULT_SUCCESS_COLOR if result else CAST_RESULT_INTERRUPTED_COLOR
	_cast_result_label.show()

	_cast_result_tween = create_tween()
	_cast_result_tween.set_parallel(true)
	_cast_result_tween.tween_property(_cast_result_label, "position", start_position - Vector2(0.0, CAST_RESULT_LABEL_RISE_PIXELS), CAST_RESULT_ANIMATION_SECONDS)
	_cast_result_tween.tween_property(_cast_result_label, "modulate:a", 0.0, CAST_RESULT_ANIMATION_SECONDS)
	_cast_result_tween.finished.connect(_on_cast_result_tween_finished.bind(pending_animation_id))


func _play_focus_visual() -> void:
	if animation_tracker == null or _focus_label == null:
		return

	if _focus_tween:
		_focus_tween.kill()
		_consume_active_focus_animation()

	var animation_id: StringName = animation_tracker.register_animation(FOCUS_ANIMATION_NAME)
	_focus_animation_id = animation_id
	_focus_label.modulate = Color(1.0, 0.88, 0.2, 1.0)
	_focus_label.scale = Vector2(1.25, 1.25)
	_focus_tween = create_tween()
	_focus_tween.set_parallel(true)
	_focus_tween.tween_property(_focus_label, "modulate", Color.WHITE, FOCUS_ANIMATION_SECONDS)
	_focus_tween.tween_property(_focus_label, "scale", Vector2.ONE, FOCUS_ANIMATION_SECONDS)
	_focus_tween.finished.connect(_on_focus_tween_finished.bind(animation_id))


func _on_damage_tween_finished() -> void:
	if _damage_label:
		_damage_label.hide()

	_damage_tween = null


func _on_focus_change_tween_finished() -> void:
	if _focus_change_label:
		_focus_change_label.hide()

	_focus_change_tween = null


func _on_cast_result_tween_finished(pending_animation_id: StringName = &"") -> void:
	if _cast_result_label:
		_cast_result_label.hide()

	_cast_result_tween = null

	if pending_animation_id != &"" and animation_tracker != null:
		animation_tracker.consume_animation(pending_animation_id)

	if _cast_animation_id == pending_animation_id:
		_cast_animation_id = &""


func _on_prepare_attack_tween_finished(animation_id: StringName) -> void:
	if _prepare_attack_mark:
		_prepare_attack_mark.hide()

	_prepare_attack_tween = null

	if animation_tracker != null:
		animation_tracker.consume_animation(animation_id)

	if _prepare_attack_animation_id == animation_id:
		_prepare_attack_animation_id = &""


func _set_projectile_position(progress: float, start_position: Vector2, target_position: Vector2) -> void:
	if _projectile_node == null:
		return

	var arc_offset := Vector2(0.0, -sin(progress * PI) * PROJECTILE_ARC_HEIGHT)
	var projectile_position := start_position.lerp(target_position, progress) + arc_offset
	_projectile_node.position = projectile_position
	_set_projectile_collision_position(projectile_position)


func _on_projectile_attack_tween_finished(animation_id: StringName, _args: Dictionary) -> void:
	if _projectile_node:
		_projectile_node.hide()

	_projectile_tween = null
	_finish_projectile_attack_collision()

	if animation_tracker != null:
		animation_tracker.consume_animation(animation_id)

	if _projectile_animation_id == animation_id:
		_projectile_animation_id = &""


func _start_move_animation() -> void:
	_stop_move_animation()
	_is_moving = true


func _stop_move_animation() -> void:
	_is_moving = false
	_move_time = 0.0
	_set_move_pose(0.0)


func _refresh_from_state() -> void:
	if state_store == null or _entity_id == &"":
		return

	var entities: Dictionary = state_store.get_value(&"entities", {})
	if not entities.has(_entity_id):
		return

	_set_entity(entities[_entity_id])
	_update_board_position()


func _set_entity(entity_state: Dictionary) -> void:
	_entity = entity_state
	_on_entity_updated(_entity)
	_update_id_label()
	_update_hp_bar()
	_update_focus_label()


func _get_previous_entity(previous_entities: Variant) -> Dictionary:
	if not previous_entities is Dictionary:
		return {}

	return previous_entities.get(_entity_id, {})


func _should_play_cast_started_visual(next_entity: Dictionary, previous_entity: Dictionary) -> bool:
	if previous_entity.is_empty():
		return false

	var next_state := StringName(str(next_entity.get(&"state", &"idle")))
	if next_state != ENTITY_STATE_CASTING:
		return false

	var previous_state := StringName(str(previous_entity.get(&"state", &"idle")))
	if previous_state != ENTITY_STATE_CASTING:
		return true

	return next_entity.get(&"cast_args", {}) != previous_entity.get(&"cast_args", {})


func _update_board_position() -> void:
	if _entity.is_empty() or board_view == null:
		return

	var next_position := _get_board_position()
	if next_position != Vector2.INF:
		position = next_position


func _create_entity_area() -> void:
	_entity_area = Area2D.new()
	_entity_area.name = ENTITY_AREA_NAME
	_entity_area.area_entered.connect(_on_entity_area_entered)
	add_child(_entity_area)

	_entity_collision_shape = RectangleShape2D.new()
	_entity_collision = CollisionShape2D.new()
	_entity_collision.name = ENTITY_COLLISION_NAME
	_entity_collision.shape = _entity_collision_shape
	_entity_area.add_child(_entity_collision)


func _update_entity_area() -> void:
	if _entity_area == null or _entity_collision_shape == null:
		return

	var board: Dictionary = state_store.get_value(&"board", {})
	var cell_size: Vector2 = board.get(&"cell_size", Vector2.ZERO)
	if cell_size == Vector2.ZERO:
		_entity_collision.disabled = true
		return

	_entity_collision.disabled = false
	_entity_collision_shape.size = cell_size * ENTITY_COLLISION_CELL_SCALE
	_sync_projectile_collision_shape(cell_size)
	var visual_size := get_visual_size()
	_entity_area.position = Vector2(visual_size.x / 2.0, visual_size.y - cell_size.y / 2.0)


func _on_entity_area_entered(area: Area2D) -> void:
	var other_entity_view := area.get_parent() as EntityBoardView
	if other_entity_view == null:
		return

	if other_entity_view.get_entity_id() == _entity_id:
		return

	var collided_entity_ids := _get_collided_entity_ids()
	if collided_entity_ids.is_empty():
		return

	print("entity collision list for %s: %s" % [_entity_id, collided_entity_ids])
	_emit_active_collisions(collided_entity_ids)

	if other_entity_view._has_active_collision():
		other_entity_view._emit_active_collisions(other_entity_view._get_collided_entity_ids())


func _get_collided_entity_ids() -> Array[StringName]:
	var collided_entity_ids: Array[StringName] = []
	var collision_area := _get_collision_area()
	if collision_area == null:
		return collided_entity_ids

	for overlapping_area: Area2D in collision_area.get_overlapping_areas():
		var overlapping_entity_view := overlapping_area.get_parent() as EntityBoardView
		if overlapping_entity_view == null:
			continue

		var overlapping_entity_id := overlapping_entity_view.get_entity_id()
		if overlapping_entity_id == _entity_id:
			continue

		collided_entity_ids.append(overlapping_entity_id)

	return collided_entity_ids


func _has_active_collision() -> bool:
	return not _active_collision_payload.is_empty()


func _emit_active_collisions(collided_entity_ids: Array[StringName]) -> void:
	if _active_collision_payload.is_empty():
		return

	var newly_collided_entity_ids: Array[StringName] = []
	for collided_entity_id: StringName in collided_entity_ids:
		if _active_collision_entity_ids.has(collided_entity_id):
			continue

		_active_collision_entity_ids[collided_entity_id] = true
		newly_collided_entity_ids.append(collided_entity_id)

	if newly_collided_entity_ids.is_empty():
		return

	entities_collided.emit(_entity_id, newly_collided_entity_ids, _active_collision_payload)


func _begin_collision(payload: Dictionary, collision_area: Area2D = null) -> void:
	_active_collision_payload = payload
	_active_collision_entity_ids.clear()
	_active_collision_area = collision_area
	_emit_current_active_collisions()
	call_deferred("_emit_current_active_collisions")


func _emit_current_active_collisions() -> void:
	if _active_collision_payload.is_empty() or _entity_area == null:
		return

	var collided_entity_ids := _get_collided_entity_ids()
	if collided_entity_ids.is_empty():
		return

	print("entity collision list for %s: %s" % [_entity_id, collided_entity_ids])
	_emit_active_collisions(collided_entity_ids)


func _finish_collision() -> void:
	_active_collision_payload = {}
	_active_collision_entity_ids.clear()
	_active_collision_area = null


func _begin_attack_collision(args: Dictionary) -> void:
	_begin_collision({
		&"type": COLLISION_PAYLOAD_ATTACK,
		&"args": args,
	})


func _finish_attack_collision() -> void:
	_finish_collision()


func _begin_projectile_attack_collision(args: Dictionary, start_position: Vector2) -> void:
	if _projectile_area == null or _projectile_collision == null:
		return

	_set_projectile_collision_position(start_position)
	_projectile_collision.disabled = false
	_projectile_area.monitoring = true
	_projectile_area.monitorable = true
	_begin_collision({
		&"type": COLLISION_PAYLOAD_ATTACK,
		&"args": args,
	}, _projectile_area)


func _finish_projectile_attack_collision() -> void:
	_finish_attack_collision()
	if _projectile_collision:
		_projectile_collision.disabled = true
	if _projectile_area:
		_projectile_area.monitoring = false
		_projectile_area.monitorable = false


func _set_projectile_collision_position(projectile_position: Vector2) -> void:
	if _projectile_area == null or get_parent() == null:
		return

	_projectile_area.position = to_local(get_parent().to_global(projectile_position))


func _get_collision_area() -> Area2D:
	if _active_collision_area != null:
		return _active_collision_area

	return _entity_area


func _ensure_projectile_area() -> void:
	if _projectile_area != null:
		return

	_projectile_area = Area2D.new()
	_projectile_area.name = "ProjectileArea"
	_projectile_area.monitoring = false
	_projectile_area.monitorable = false
	_projectile_area.area_entered.connect(_on_entity_area_entered)
	add_child(_projectile_area)

	_projectile_collision_shape = RectangleShape2D.new()
	_projectile_collision = CollisionShape2D.new()
	_projectile_collision.name = "ProjectileCollision"
	_projectile_collision.shape = _projectile_collision_shape
	_projectile_collision.disabled = true
	_projectile_area.add_child(_projectile_collision)

	var board: Dictionary = state_store.get_value(&"board", {})
	var cell_size: Vector2 = board.get(&"cell_size", StateStore.BOARD_CELL_SIZE)
	_sync_projectile_collision_shape(cell_size)


func _sync_projectile_collision_shape(cell_size: Vector2) -> void:
	if _projectile_collision_shape == null:
		return

	_projectile_collision_shape.size = cell_size * ENTITY_COLLISION_CELL_SCALE


func _create_id_label() -> void:
	_id_label = Label.new()
	_id_label.layout_mode = 0
	_id_label.add_theme_font_size_override("font_size", ID_LABEL_FONT_SIZE)
	_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_id_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_id_label)


func _create_hp_bar() -> void:
	_hp_bar_background = ColorRect.new()
	_hp_bar_background.color = Color(0.12, 0.12, 0.12, 0.9)
	add_child(_hp_bar_background)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.25, 0.9, 0.25, 1.0)
	add_child(_hp_bar_fill)

	_hp_label = Label.new()
	_hp_label.layout_mode = 0
	_hp_label.add_theme_font_size_override("font_size", HP_TEXT_FONT_SIZE)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_hp_label)

	_focus_label = Label.new()
	_focus_label.layout_mode = 0
	_focus_label.add_theme_font_size_override("font_size", FOCUS_TEXT_FONT_SIZE)
	_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_focus_label)


func _update_id_label() -> void:
	if _id_label == null:
		return

	var visual_size := get_visual_size()
	_id_label.text = str(_entity.get(&"id", ""))
	_id_label.position = Vector2.ZERO
	_id_label.size = Vector2(max(visual_size.x, 1.0), ID_LABEL_HEIGHT)


func _update_hp_bar() -> void:
	if _hp_bar_background == null or _hp_bar_fill == null or _hp_label == null:
		return

	var max_hp: int = max(int(_entity.get(&"max_hp", 0)), 0)
	var current_hp: int = clamp(int(_entity.get(&"current_hp", max_hp)), 0, max_hp)
	var visual_size := get_visual_size()
	var bar_width: float = max(visual_size.x, HP_BAR_MIN_WIDTH)
	var bar_position := Vector2((visual_size.x - bar_width) / 2.0, -HP_BAR_TOP_OFFSET - HP_BAR_HEIGHT)
	var hp_ratio := 0.0
	if max_hp > 0:
		hp_ratio = float(current_hp) / float(max_hp)

	_hp_bar_background.position = bar_position
	_hp_bar_background.size = Vector2(bar_width, HP_BAR_HEIGHT)
	_hp_bar_fill.position = bar_position
	_hp_bar_fill.size = Vector2(bar_width * hp_ratio, HP_BAR_HEIGHT)
	_hp_bar_fill.color = _get_hp_bar_color(hp_ratio)
	_hp_label.text = "%d/%d" % [current_hp, max_hp]
	_hp_label.position = bar_position - Vector2(0.0, HP_TEXT_HEIGHT)
	_hp_label.size = Vector2(bar_width, HP_TEXT_HEIGHT)


func _update_focus_label() -> void:
	if _focus_label == null:
		return

	var focus: int = max(int(_entity.get(&"focus", 0)), 0)
	var visual_size := get_visual_size()
	var label_width: float = max(visual_size.x, HP_BAR_MIN_WIDTH)
	var bar_position := Vector2((visual_size.x - label_width) / 2.0, -HP_BAR_TOP_OFFSET - HP_BAR_HEIGHT)
	_focus_label.text = "Focus: %d" % focus
	_focus_label.position = bar_position - Vector2(0.0, HP_TEXT_HEIGHT + FOCUS_TEXT_HEIGHT)
	_focus_label.size = Vector2(label_width, FOCUS_TEXT_HEIGHT)
	_focus_label.pivot_offset = _focus_label.size / 2.0


func _get_hp_bar_color(hp_ratio: float) -> Color:
	if hp_ratio <= 0.25:
		return Color(0.9, 0.15, 0.12, 1.0)

	if hp_ratio <= 0.5:
		return Color(0.95, 0.72, 0.15, 1.0)

	return Color(0.25, 0.9, 0.25, 1.0)


func _get_board_position() -> Vector2:
	return _get_entity_board_position(_entity_id)


func _get_attack_target_position(args: Dictionary) -> Vector2:
	if board_view == null:
		return Vector2.INF

	var target_cell: Variant = args.get("target_cell", {})
	if target_cell is Dictionary and target_cell.has("i") and target_cell.has("j"):
		var visual_size := get_visual_size()
		var i := int(target_cell["i"])
		var j := int(target_cell["j"])
		var bottom_position: Vector2 = board_view.position + board_view.index_to_bottom_position(i, j)
		return bottom_position - Vector2(visual_size.x / 2.0, visual_size.y)

	var vector: Vector2i = args.get("vector", Vector2i.ZERO)
	if vector == Vector2i.ZERO:
		return Vector2.INF

	var board: Dictionary = state_store.get_value(&"board", {})
	var cell_size: Vector2 = board.get(&"cell_size", StateStore.BOARD_CELL_SIZE)
	return position + Vector2(vector.x * cell_size.x, vector.y * cell_size.y)


func _get_attack_target_cell_center(args: Dictionary) -> Vector2:
	if board_view == null:
		return Vector2.INF

	var target_cell: Variant = args.get("target_cell", {})
	if target_cell is Dictionary and target_cell.has("i") and target_cell.has("j"):
		var i := int(target_cell["i"])
		var j := int(target_cell["j"])
		var bottom_position: Vector2 = board_view.position + board_view.index_to_bottom_position(i, j)
		var board: Dictionary = state_store.get_value(&"board", {})
		var cell_size: Vector2 = board.get(&"cell_size", StateStore.BOARD_CELL_SIZE)
		return bottom_position - Vector2(0.0, cell_size.y / 2.0)

	var vector: Vector2i = args.get("vector", Vector2i.ZERO)
	if vector == Vector2i.ZERO:
		return Vector2.INF

	var board: Dictionary = state_store.get_value(&"board", {})
	var cell_size: Vector2 = board.get(&"cell_size", StateStore.BOARD_CELL_SIZE)
	return position + Vector2(vector.x * cell_size.x, vector.y * cell_size.y) - Vector2(0.0, cell_size.y / 2.0)


func _get_attack_target_ground_position(args: Dictionary) -> Vector2:
	if board_view == null:
		return Vector2.INF

	var target_cell: Variant = args.get("target_cell", {})
	if target_cell is Dictionary and target_cell.has("i") and target_cell.has("j"):
		var i := int(target_cell["i"])
		var j := int(target_cell["j"])
		return board_view.position + board_view.index_to_bottom_position(i, j) - Vector2(0.0, PROJECTILE_ROCK_BOTTOM_OFFSET)

	var vector: Vector2i = args.get("vector", Vector2i.ZERO)
	if vector == Vector2i.ZERO:
		return Vector2.INF

	var board: Dictionary = state_store.get_value(&"board", {})
	var cell_size: Vector2 = board.get(&"cell_size", StateStore.BOARD_CELL_SIZE)
	return position + Vector2(vector.x * cell_size.x, vector.y * cell_size.y) + Vector2(0.0, cell_size.y / 2.0 - PROJECTILE_ROCK_BOTTOM_OFFSET)


func _get_entity_board_position(entity_id: StringName) -> Vector2:
	var bottom_position := _get_entity_board_bottom_position(entity_id)
	if bottom_position == Vector2.INF:
		return Vector2.INF

	var visual_size := get_visual_size()
	return bottom_position - Vector2(visual_size.x / 2.0, visual_size.y)


func _get_entity_board_bottom_position(entity_id: StringName) -> Vector2:
	if board_view == null:
		return Vector2.INF

	var board: Dictionary = state_store.get_value(&"board", {})
	var board_index := _get_entity_board_index(board, entity_id)
	if board_index == Vector2i(-1, -1):
		return Vector2.INF

	return board_view.position + board_view.index_to_bottom_position(board_index.x, board_index.y)


func _get_entity_board_index(board: Dictionary, entity_id: StringName) -> Vector2i:
	if board.is_empty() or not board.has(&"cells"):
		return Vector2i(-1, -1)

	var cells: Array = board[&"cells"]
	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _cell_has_entity_id(cell, entity_id):
				return Vector2i(i, j)

	return Vector2i(-1, -1)


func _cell_has_entity_id(cell: Dictionary, entity_id: StringName) -> bool:
	var entity_ids: Array = cell.get(&"entity_ids", [])
	return entity_ids.has(entity_id) or cell.get(&"entity_id", &"") == entity_id


func _has_board_cell(board: Dictionary, i: int, j: int) -> bool:
	return (
		board.has(&"cells")
		and i >= 0
		and j >= 0
		and i < int(board.get(&"cols", 0))
		and j < int(board.get(&"rows", 0))
	)
