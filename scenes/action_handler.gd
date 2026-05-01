extends Node

const MIN_CONSUME_SECONDS := 0.5
const MAX_CONSUME_SECONDS := 3.0

var _current_event: Dictionary = {}
var _is_consuming := false


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
	_current_event = {}
	_is_consuming = false


func is_consuming() -> bool:
	return _is_consuming


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
