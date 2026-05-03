extends Node2D

const DRAW_SCALE := 1.0
const MOVE_ANIMATION_SECONDS := 1.75
const MOVE_ANIMATION_NAME := &"character_move"
const WALK_STEP_SECONDS := 0.35
const WALK_ARM_SWING_DEGREES := 12.0
const WALK_LEG_SWING_DEGREES := 10.0

var _entity_id := &""
var _character_spec: Dictionary = {}
var _character_size := Vector2.ZERO
var _move_tween: Tween
var _move_animation_id := &""
var _is_walking := false
var _walk_time := 0.0

@onready var state_store: Node = _find_node_in_ancestors(&"StateStore")
@onready var animation_tracker: Node = _find_node_in_ancestors(&"AnimationTracker")
@onready var board_view: Node = _find_node_in_ancestors(&"BoardView")
@onready var head: Node2D = $Head
@onready var head_label: Label = $Head/IdLabel
@onready var neck: Node2D = $Neck
@onready var body: Node2D = $Body
@onready var left_arm: Node2D = $LeftArm
@onready var right_arm: Node2D = $RightArm
@onready var left_leg: Node2D = $LeftLeg
@onready var right_leg: Node2D = $RightLeg


func _ready() -> void:
	if state_store == null:
		return

	state_store.entities_updated.connect(_on_entities_updated)
	state_store.board_init.connect(_on_board_init)
	state_store.character_initialized.connect(_on_character_initialized)
	state_store.character_moved.connect(_on_character_moved)
	_refresh_from_state()


func _process(delta: float) -> void:
	if not _is_walking:
		return

	_walk_time += delta
	_set_walk_pose(sin(_walk_time * TAU / WALK_STEP_SECONDS))


func _on_character_initialized(spec: Dictionary, _previous_character: Variant) -> void:
	if _entity_id != &"" and spec.get(&"id", &"") != _entity_id:
		return

	_set_character_spec(spec)
	_update_board_position()


func set_entity_id(entity_id: Variant) -> void:
	_entity_id = StringName(str(entity_id))
	_refresh_from_state()


func _on_entities_updated(entities: Dictionary, _previous_entities: Variant) -> void:
	if _entity_id == &"" or not entities.has(_entity_id):
		return

	_set_character_spec(entities[_entity_id])
	_update_board_position()


func _on_board_init(board: Dictionary, previous_board: Variant) -> void:
	if previous_board is Dictionary:
		var previous_index := _get_character_board_index(previous_board)
		var next_index := _get_character_board_index(board)
		if previous_index != Vector2i(-1, -1) and next_index != Vector2i(-1, -1) and previous_index != next_index:
			return

	_update_board_position()


func _on_character_moved(_next_position: Vector2, _previous_position: Variant) -> void:
	if animation_tracker == null or _entity_id == &"" or not _is_latest_character():
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
	_start_walk_animation()


func _on_move_tween_finished(animation_id: StringName) -> void:
	animation_tracker.consume_animation(animation_id)

	if _move_animation_id == animation_id:
		_move_animation_id = &""
		_move_tween = null
		_stop_walk_animation()


func _consume_active_move_animation() -> void:
	if _move_animation_id == &"":
		return

	animation_tracker.consume_animation(_move_animation_id)
	_move_animation_id = &""
	_stop_walk_animation()


func _start_walk_animation() -> void:
	_stop_walk_animation()
	_is_walking = true


func _stop_walk_animation() -> void:
	_is_walking = false
	_walk_time = 0.0
	_set_walk_pose(0.0)


func _set_walk_pose(direction: float) -> void:
	left_arm.rotation_degrees = WALK_ARM_SWING_DEGREES * direction
	right_arm.rotation_degrees = -WALK_ARM_SWING_DEGREES * direction
	left_leg.rotation_degrees = -WALK_LEG_SWING_DEGREES * direction
	right_leg.rotation_degrees = WALK_LEG_SWING_DEGREES * direction


func _update_parts() -> void:
	if _character_spec.is_empty():
		return

	var head_size := _get_head_size(_character_spec.get("head", {}))
	var neck_size := _get_part_size(_character_spec.get("neck", {}))
	var body_size := _get_part_size(_character_spec.get("body", {}))
	var arm_size := _get_part_size(_character_spec.get("arms", {}))
	var leg_size := _get_part_size(_character_spec.get("legs", {}))
	var width = max(
		body_size.x + arm_size.x * 2.0,
		head_size.x,
		neck_size.x,
		leg_size.x * 2.0
	)
	_character_size = Vector2(width, head_size.y + neck_size.y + body_size.y + leg_size.y)

	head.position = Vector2((width - head_size.x) / 2.0, 0.0)
	head_label.text = str(_character_spec.get(&"id", ""))
	head_label.position = Vector2.ZERO
	head_label.size = head_size
	neck.position = Vector2((width - neck_size.x) / 2.0, head_size.y)
	body.position = Vector2((width - body_size.x) / 2.0, head_size.y + neck_size.y)
	left_arm.position = Vector2(0.0, body.position.y + body_size.y * 0.05)
	right_arm.position = Vector2(width - arm_size.x, body.position.y + body_size.y * 0.05)
	left_leg.position = Vector2(width * 0.25, body.position.y + body_size.y)
	right_leg.position = Vector2(width * 0.53, body.position.y + body_size.y)

	head.set_part(head_size, Color.CORNFLOWER_BLUE)
	neck.set_part(neck_size, Color.LIGHT_SKY_BLUE)
	body.set_part(body_size, Color.SEA_GREEN)
	left_arm.set_part(arm_size, Color.GOLDENROD)
	right_arm.set_part(arm_size, Color.GOLDENROD)
	left_leg.set_part(leg_size, Color.INDIAN_RED)
	right_leg.set_part(leg_size, Color.INDIAN_RED)


func _update_board_position() -> void:
	if _character_spec.is_empty() or board_view == null:
		return

	var board: Dictionary = state_store.get_value(&"board", {})
	var board_index := _get_character_board_index(board)
	if board_index == Vector2i(-1, -1):
		return

	position = _get_board_position()


func _get_board_position() -> Vector2:
	if board_view == null:
		return Vector2.INF

	var board: Dictionary = state_store.get_value(&"board", {})
	var board_index := _get_character_board_index(board)
	if board_index == Vector2i(-1, -1):
		return Vector2.INF

	return board_view.position + board_view.index_to_bottom_position(board_index.x, board_index.y) - Vector2(_character_size.x / 2.0, _character_size.y)


func _get_character_board_index(board: Dictionary) -> Vector2i:
	if board.is_empty() or not board.has(&"cells"):
		return Vector2i(-1, -1)

	var cells: Array = board[&"cells"]
	for i in cells.size():
		var col_cells: Array = cells[i]

		for j in col_cells.size():
			var cell: Dictionary = col_cells[j]
			if _is_same_character_entity(cell.get(&"entity")):
				return Vector2i(i, j)

	return Vector2i(-1, -1)


func _is_same_character_entity(entity: Variant) -> bool:
	return (
		entity is Dictionary
		and entity.get(&"id", &"") == _entity_id
	)


func _refresh_from_state() -> void:
	if state_store == null or _entity_id == &"":
		return

	var entities: Dictionary = state_store.get_value(&"entities", {})
	if not entities.has(_entity_id):
		return

	_set_character_spec(entities[_entity_id])
	_update_board_position()


func _set_character_spec(spec: Dictionary) -> void:
	_character_spec = spec
	_update_parts()


func _is_latest_character() -> bool:
	var entities: Dictionary = state_store.get_value(&"entities", {})
	var latest_entity_id := &""

	for entity_id: Variant in entities:
		latest_entity_id = entity_id

	return latest_entity_id == _entity_id


func _find_node_in_ancestors(node_name: StringName) -> Node:
	var current_node: Node = self
	while current_node != null:
		if current_node.has_node(NodePath(node_name)):
			return current_node.get_node(NodePath(node_name))

		current_node = current_node.get_parent()

	return null


func _get_head_size(spec: Dictionary) -> Vector2:
	var radius := float(spec.get("radius", 0.0)) * DRAW_SCALE
	return Vector2(radius * 2.0, radius * 2.0)


func _get_part_size(spec: Dictionary) -> Vector2:
	return Vector2(
		float(spec.get("width", 0.0)) * DRAW_SCALE,
		float(spec.get("height", 0.0)) * DRAW_SCALE
	)
