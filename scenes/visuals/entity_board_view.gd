extends Node2D

class_name EntityBoardView

const MOVE_ANIMATION_SECONDS := 1.75
const MOVE_ANIMATION_NAME := &"entity_move"
const WALK_STEP_SECONDS := 0.35

var _entity_id := &""
var _entity: Dictionary = {}
var _move_tween: Tween
var _move_animation_id := &""
var _is_moving := false
var _move_time := 0.0

@onready var state_store: Node = _find_node_in_ancestors(&"StateStore")
@onready var animation_tracker: Node = _find_node_in_ancestors(&"AnimationTracker")
@onready var board_view: Node = _find_node_in_ancestors(&"BoardView")


func _ready() -> void:
	if state_store == null:
		return

	state_store.entities_updated.connect(_on_entities_updated)
	state_store.board_init.connect(_on_board_init)
	state_store.entity_moved.connect(_on_entity_moved)
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
		var previous_index := _get_entity_board_index(previous_board)
		var next_index := _get_entity_board_index(board)
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


func _on_move_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _move_animation_id == animation_id:
		_move_animation_id = &""
		_move_tween = null
		_stop_move_animation()


func _consume_active_move_animation() -> void:
	if _move_animation_id == &"":
		return

	animation_tracker.consume_animation(_move_animation_id)
	_move_animation_id = &""
	_stop_move_animation()


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
	if board_view == null:
		return Vector2.INF

	var board: Dictionary = state_store.get_value(&"board", {})
	var board_index := _get_entity_board_index(board)
	if board_index == Vector2i(-1, -1):
		return Vector2.INF

	var visual_size := get_visual_size()
	return board_view.position + board_view.index_to_bottom_position(board_index.x, board_index.y) - Vector2(visual_size.x / 2.0, visual_size.y)


func _get_entity_board_index(board: Dictionary) -> Vector2i:
	if board.is_empty() or not board.has(&"cells"):
		return Vector2i(-1, -1)

	var cells: Array = board[&"cells"]
	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _is_same_entity(cell.get(&"entity")):
				return Vector2i(i, j)

	return Vector2i(-1, -1)


func _is_same_entity(entity_state: Variant) -> bool:
	return (
		entity_state is Dictionary
		and entity_state.get(&"id", &"") == _entity_id
	)


func _find_node_in_ancestors(node_name: StringName) -> Node:
	var current_node: Node = self
	while current_node != null:
		if current_node.has_node(NodePath(node_name)):
			return current_node.get_node(NodePath(node_name))

		current_node = current_node.get_parent()

	return null
