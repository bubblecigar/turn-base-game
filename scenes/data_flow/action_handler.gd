extends Node

signal processing_status_changed(is_processing: bool, event: Dictionary)

const MIN_CONSUME_SECONDS := 0.5
const MAX_CONSUME_SECONDS := 3.0
const MIN_CHARACTER_SIZE := 16
const MAX_CHARACTER_SIZE := 64
const MIN_HEAD_RADIUS := 6
const MAX_HEAD_RADIUS := 14
const MIN_BOARD_SIZE := 3
const MAX_BOARD_SIZE := 5

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
		'spawn_board':
			_init_board(event['payload'])
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


func _init_board(payload: Dictionary) -> void:
	var cols := int(payload.get("i", randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE)))
	var rows := int(payload.get("j", randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE)))

	if not _is_board_size(cols) or not _is_board_size(rows):
		push_warning('Invalid spawn_board payload. Expected { i: int, j: int } between 3 and 5.')
		cols = randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE)
		rows = randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE)

	state_store.init_board(cols, rows)
	print('initialized board: ', cols, ' x ', rows)


func _is_board_size(value: int) -> bool:
	return value >= MIN_BOARD_SIZE and value <= MAX_BOARD_SIZE


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
	if not _is_board_position_payload(payload):
		push_warning('Invalid move_character payload. Expected { i: int, j: int }.')
		return

	var next_i := int(payload["i"])
	var next_j := int(payload["j"])
	state_store.move_character_to(next_i, next_j)
	print('moved character to board cell: ', Vector2i(next_i, next_j))


func _is_board_position_payload(payload: Dictionary) -> bool:
	return (
		payload.has("i")
		and payload.has("j")
		and typeof(payload["i"]) == TYPE_INT
		and typeof(payload["j"]) == TYPE_INT
	)


func _consume_debugger_button_pressed(payload: Dictionary) -> void:
	print('handled debugger button: ', payload)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
