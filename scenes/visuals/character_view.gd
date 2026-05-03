extends "res://scenes/visuals/entity_base.gd"

const DRAW_SCALE := 1.0
const WALK_ARM_SWING_DEGREES := 12.0
const WALK_LEG_SWING_DEGREES := 10.0

var _character_size := Vector2.ZERO

@onready var head: Node2D = $Head
@onready var head_label: Label = $Head/IdLabel
@onready var neck: Node2D = $Neck
@onready var body: Node2D = $Body
@onready var left_arm: Node2D = $LeftArm
@onready var right_arm: Node2D = $RightArm
@onready var left_leg: Node2D = $LeftLeg
@onready var right_leg: Node2D = $RightLeg


func get_visual_size() -> Vector2:
	return _character_size


func _on_entity_updated(entity_state: Dictionary) -> void:
	_update_parts(entity_state)


func _set_move_pose(direction: float) -> void:
	left_arm.rotation_degrees = WALK_ARM_SWING_DEGREES * direction
	right_arm.rotation_degrees = -WALK_ARM_SWING_DEGREES * direction
	left_leg.rotation_degrees = -WALK_LEG_SWING_DEGREES * direction
	right_leg.rotation_degrees = WALK_LEG_SWING_DEGREES * direction


func _update_parts(entity_state: Dictionary) -> void:
	var character_spec: Dictionary = entity_state.get(&"spec", {})
	if character_spec.is_empty():
		return

	var head_size := _get_head_size(character_spec.get("head", {}))
	var neck_size := _get_part_size(character_spec.get("neck", {}))
	var body_size := _get_part_size(character_spec.get("body", {}))
	var arm_size := _get_part_size(character_spec.get("arms", {}))
	var leg_size := _get_part_size(character_spec.get("legs", {}))
	var width = max(
		body_size.x + arm_size.x * 2.0,
		head_size.x,
		neck_size.x,
		leg_size.x * 2.0
	)
	_character_size = Vector2(width, head_size.y + neck_size.y + body_size.y + leg_size.y)

	head.position = Vector2((width - head_size.x) / 2.0, 0.0)
	head_label.text = str(entity_state.get(&"id", ""))
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


func _get_head_size(spec: Dictionary) -> Vector2:
	var radius := float(spec.get("radius", 0.0)) * DRAW_SCALE
	return Vector2(radius * 2.0, radius * 2.0)


func _get_part_size(spec: Dictionary) -> Vector2:
	return Vector2(
		float(spec.get("width", 0.0)) * DRAW_SCALE,
		float(spec.get("height", 0.0)) * DRAW_SCALE
	)
