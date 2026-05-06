extends Node2D

class_name EntityBoardView

const MOVE_ANIMATION_SECONDS := 1.75
const MOVE_ANIMATION_NAME := &"entity_move"
const WALK_STEP_SECONDS := 0.35
const ATTACK_ANIMATION_SECONDS := 0.28
const ATTACK_ANIMATION_NAME := &"entity_attack"
const ATTACK_LUNGE_PIXELS := 28.0
const HIT_ANIMATION_SECONDS := 0.32
const HIT_ANIMATION_NAME := &"entity_hit"
const HIT_SHAKE_PIXELS := 8.0

var _entity_id := &""
var _entity: Dictionary = {}
var _move_tween: Tween
var _attack_tween: Tween
var _hit_tween: Tween
var _move_animation_id := &""
var _attack_animation_id := &""
var _hit_animation_id := &""
var _is_moving := false
var _move_time := 0.0

@export var state_store_path: NodePath
@export var animation_tracker_path: NodePath
@export var board_view_path: NodePath

@onready var state_store: Node = get_node(state_store_path)
@onready var animation_tracker: Node = get_node(animation_tracker_path)
@onready var board_view: Node = get_node(board_view_path)


func _ready() -> void:
	if state_store == null:
		return

	state_store.entities_updated.connect(_on_entities_updated)
	state_store.board_init.connect(_on_board_init)
	state_store.entity_moved.connect(_on_entity_moved)
	state_store.entity_attack_pair_triggered.connect(_on_entity_attack_pair_triggered)
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


func get_visual_size() -> Vector2:
	return Vector2.ZERO


func _on_entity_updated(_entity_state: Dictionary) -> void:
	pass


func _set_move_pose(_direction: float) -> void:
	pass


func _on_entities_updated(entities: Dictionary, _previous_entities: Variant) -> void:
	if _entity_id == &"" or not entities.has(_entity_id):
		return

	_set_entity(entities[_entity_id])
	_update_board_position()


func _on_board_init(board: Dictionary, previous_board: Variant) -> void:
	if previous_board is Dictionary:
		var previous_index := _get_entity_board_index(previous_board, _entity_id)
		var next_index := _get_entity_board_index(board, _entity_id)
		if previous_index != Vector2i(-1, -1) and next_index != Vector2i(-1, -1) and previous_index != next_index:
			return

	_update_board_position()


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


func _on_entity_attack_pair_triggered(attacker_id: StringName, target_id: StringName) -> void:
	if _entity_id == attacker_id:
		print("attacker visual received attack signal: ", attacker_id, " -> ", target_id)
		_play_attack_animation(target_id)
	elif _entity_id == target_id:
		print("receiver visual received attack signal: ", attacker_id, " -> ", target_id)
		_play_hit_animation(attacker_id)


func _on_move_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _move_animation_id == animation_id:
		_move_animation_id = &""
		_move_tween = null
		_stop_move_animation()


func _on_attack_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _attack_animation_id == animation_id:
		_attack_animation_id = &""
		_attack_tween = null
		_update_board_position()


func _on_hit_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _hit_animation_id == animation_id:
		_hit_animation_id = &""
		_hit_tween = null
		modulate = Color.WHITE
		_update_board_position()


func _consume_active_move_animation() -> void:
	if _move_animation_id == &"":
		return

	animation_tracker.consume_animation(_move_animation_id)
	_move_animation_id = &""
	_stop_move_animation()


func _consume_active_attack_animation() -> void:
	if _attack_animation_id == &"":
		return

	animation_tracker.consume_animation(_attack_animation_id)
	_attack_animation_id = &""


func _consume_active_hit_animation() -> void:
	if _hit_animation_id == &"":
		return

	animation_tracker.consume_animation(_hit_animation_id)
	_hit_animation_id = &""
	modulate = Color.WHITE


func _play_attack_animation(target_id: StringName) -> void:
	if animation_tracker == null:
		return

	var target_bottom_position := _get_entity_board_bottom_position(target_id)
	var own_bottom_position := _get_entity_board_bottom_position(_entity_id)
	if target_bottom_position == Vector2.INF or own_bottom_position == Vector2.INF:
		return

	if _attack_tween:
		_attack_tween.kill()
		_consume_active_attack_animation()

	var start_position := position
	var attack_offset := target_bottom_position - own_bottom_position
	if attack_offset.length() > ATTACK_LUNGE_PIXELS:
		attack_offset = attack_offset.normalized() * ATTACK_LUNGE_PIXELS

	var animation_id: StringName = animation_tracker.register_animation(ATTACK_ANIMATION_NAME)
	_attack_animation_id = animation_id
	_attack_tween = create_tween()
	_attack_tween.set_trans(Tween.TRANS_QUAD)
	_attack_tween.set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(self, "position", start_position + attack_offset, ATTACK_ANIMATION_SECONDS * 0.45)
	_attack_tween.tween_property(self, "position", start_position, ATTACK_ANIMATION_SECONDS * 0.55)
	_attack_tween.finished.connect(_on_attack_tween_finished.bind(animation_id))


func _play_hit_animation(attacker_id: StringName) -> void:
	if animation_tracker == null:
		return

	var attacker_bottom_position := _get_entity_board_bottom_position(attacker_id)
	var own_bottom_position := _get_entity_board_bottom_position(_entity_id)
	if attacker_bottom_position == Vector2.INF or own_bottom_position == Vector2.INF:
		return

	if _hit_tween:
		_hit_tween.kill()
		_consume_active_hit_animation()

	var start_position := position
	var hit_direction := own_bottom_position - attacker_bottom_position
	if hit_direction == Vector2.ZERO:
		hit_direction = Vector2.RIGHT

	var shake_offset := hit_direction.normalized() * HIT_SHAKE_PIXELS
	var animation_id: StringName = animation_tracker.register_animation(HIT_ANIMATION_NAME)
	_hit_animation_id = animation_id
	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(self, "modulate", Color(1.0, 0.55, 0.55), HIT_ANIMATION_SECONDS * 0.5)
	_hit_tween.tween_property(self, "position", start_position + shake_offset, HIT_ANIMATION_SECONDS * 0.25)
	_hit_tween.chain().tween_property(self, "position", start_position - shake_offset * 0.55, HIT_ANIMATION_SECONDS * 0.25)
	_hit_tween.chain().tween_property(self, "position", start_position, HIT_ANIMATION_SECONDS * 0.25)
	_hit_tween.parallel().tween_property(self, "modulate", Color.WHITE, HIT_ANIMATION_SECONDS * 0.25)
	_hit_tween.finished.connect(_on_hit_tween_finished.bind(animation_id))


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


func _update_board_position() -> void:
	if _entity.is_empty() or board_view == null:
		return

	var next_position := _get_board_position()
	if next_position != Vector2.INF:
		position = next_position


func _get_board_position() -> Vector2:
	return _get_entity_board_position(_entity_id)


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
			if cell.get(&"entity_id", &"") == entity_id:
				return Vector2i(i, j)

	return Vector2i(-1, -1)
