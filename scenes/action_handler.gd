extends Node

const MIN_CONSUME_SECONDS := 0.5
const MAX_CONSUME_SECONDS := 3.0
const MIN_CHARACTER_SIZE := 16
const MAX_CHARACTER_SIZE := 64

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
	print('start consume: ', _current_event)

	var consume_seconds := randf_range(MIN_CONSUME_SECONDS, MAX_CONSUME_SECONDS)
	await get_tree().create_timer(consume_seconds).timeout

	print('consumed: ', _current_event, ' in ', consume_seconds, 's')
	_handle_consumed_event(_current_event)
	_current_event = {}
	_is_consuming = false


func is_consuming() -> bool:
	return _is_consuming


func _handle_consumed_event(event: Dictionary) -> void:
	match event['eventName']:
		'spawn_character':
			_init_character(event['payload'])
		'debugger_button_pressed':
			_consume_debugger_button_pressed(event['payload'])
		_:
			push_warning('Unhandled consumed event: %s' % event['eventName'])


func _init_character(_payload: Dictionary) -> void:
	var character_state := {
		"width": randi_range(MIN_CHARACTER_SIZE, MAX_CHARACTER_SIZE),
		"height": randi_range(MIN_CHARACTER_SIZE, MAX_CHARACTER_SIZE),
	}
	state_store.set_value(&"character", character_state)
	print('initialized character: ', character_state)


func _consume_debugger_button_pressed(payload: Dictionary) -> void:
	print('handled debugger button: ', payload)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
