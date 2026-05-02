extends Node2D

const DRAW_SCALE := 5.0
const MOVE_ANIMATION_SECONDS := 1.75
const MOVE_ANIMATION_NAME := &"character_move"
const WALK_STEP_SECONDS := 0.35
const WALK_ARM_SWING_DEGREES := 12.0
const WALK_LEG_SWING_DEGREES := 10.0

var _character_spec: Dictionary = {}
var _move_tween: Tween
var _move_animation_id := &""
var _is_walking := false
var _walk_time := 0.0

@onready var state_store: Node = $"../../StateStore"
@onready var animation_tracker: Node = $"../../AnimationTracker"
@onready var head: Node2D = $Head
@onready var neck: Node2D = $Neck
@onready var body: Node2D = $Body
@onready var left_arm: Node2D = $LeftArm
@onready var right_arm: Node2D = $RightArm
@onready var left_leg: Node2D = $LeftLeg
@onready var right_leg: Node2D = $RightLeg


func _ready() -> void:
	state_store.character_initialized.connect(_on_character_initialized)
	state_store.character_moved.connect(_on_character_moved)


func _process(delta: float) -> void:
	if not _is_walking:
		return

	_walk_time += delta
	_set_walk_pose(sin(_walk_time * TAU / WALK_STEP_SECONDS))


func _on_character_initialized(spec: Dictionary, _previous_character: Variant) -> void:
	_character_spec = spec
	_update_parts()


func _on_character_moved(next_position: Vector2, _previous_position: Variant) -> void:
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

	head.position = Vector2((width - head_size.x) / 2.0, 0.0)
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


func _get_head_size(spec: Dictionary) -> Vector2:
	var radius := float(spec.get("radius", 0.0)) * DRAW_SCALE
	return Vector2(radius * 2.0, radius * 2.0)


func _get_part_size(spec: Dictionary) -> Vector2:
	return Vector2(
		float(spec.get("width", 0.0)) * DRAW_SCALE,
		float(spec.get("height", 0.0)) * DRAW_SCALE
	)
