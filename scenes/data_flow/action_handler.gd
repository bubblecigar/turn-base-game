extends Node

signal processing_status_changed(is_processing: bool, event: Dictionary)

const MIN_CONSUME_SECONDS := 0.5
const MAX_CONSUME_SECONDS := 3.0
const MIN_CHARACTER_SIZE := 16
const MAX_CHARACTER_SIZE := 64
const MIN_HEAD_RADIUS := 6
const MAX_HEAD_RADIUS := 14

var _current_event: Dictionary = {}
var _is_consuming := false

@onready var state_store: Node = $"../StateStore"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	pass # Replace with function body.


func consume(event: Dictionary) -> void:
	if _is_consuming:
		push_error('Action handler is already consuming an event.')
		return

	_current_event = event
	_is_consuming = true
	print('start consume action : ', _current_event)
	processing_status_changed.emit(true, _current_event)


	print('action consumed: ', _current_event)
	_handle_consumed_event(_current_event)
	_current_event = {}
	_is_consuming = false
	processing_status_changed.emit(false, {})


func is_consuming() -> bool:
	return _is_consuming


func _handle_consumed_event(event: Dictionary) -> void:
	match event['eventName']:
		'spawn_character':
			_init_character(event['payload'])
		'move_character':
			_move_character(event['payload'])
		'debugger_button_pressed':
			_consume_debugger_button_pressed(event['payload'])
		_:
			push_warning('Unhandled consumed event: %s' % event['eventName'])


func _init_character(payload: Dictionary) -> void:
	var character_state := payload.duplicate(true) if _is_character_spec(payload) else _random_character_spec()
	state_store.init_character(character_state)
	print('initialized character: ', character_state)


func _random_character_spec() -> Dictionary:
	return {
		"head": {
			"radius": randi_range(MIN_HEAD_RADIUS, MAX_HEAD_RADIUS),
		},
		"neck": _random_part_size(),
		"body": _random_part_size(),
		"arms": _random_part_size(),
		"legs": _random_part_size(),
	}


func _random_part_size() -> Dictionary:
	return {
		"width": randi_range(MIN_CHARACTER_SIZE, MAX_CHARACTER_SIZE),
		"height": randi_range(MIN_CHARACTER_SIZE, MAX_CHARACTER_SIZE),
	}


func _is_character_spec(spec: Dictionary) -> bool:
	return (
		_is_head_spec(spec.get("head", {}))
		and _is_part_spec(spec.get("neck", {}))
		and _is_part_spec(spec.get("body", {}))
		and _is_part_spec(spec.get("arms", {}))
		and _is_part_spec(spec.get("legs", {}))
	)


func _is_head_spec(spec: Variant) -> bool:
	return spec is Dictionary and spec.has("radius")


func _is_part_spec(spec: Variant) -> bool:
	return spec is Dictionary and spec.has("width") and spec.has("height")


func _move_character(payload: Dictionary) -> void:
	if not _is_position_payload(payload):
		push_warning('Invalid move_character payload. Expected { x: number, y: number }.')
		return

	var next_position := Vector2(float(payload["x"]), float(payload["y"]))
	state_store.move_character_to(next_position)
	print('moved character to: ', next_position)


func _is_position_payload(payload: Dictionary) -> bool:
	return (
		payload.has("x")
		and payload.has("y")
		and (typeof(payload["x"]) == TYPE_INT or typeof(payload["x"]) == TYPE_FLOAT)
		and (typeof(payload["y"]) == TYPE_INT or typeof(payload["y"]) == TYPE_FLOAT)
	)


func _consume_debugger_button_pressed(payload: Dictionary) -> void:
	print('handled debugger button: ', payload)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
