extends Node

const MIN_CONSUME_SECONDS := 0.5
const MAX_CONSUME_SECONDS := 3.0

var _event_queue: Array[Dictionary] = []
var _current_event: Dictionary = {}
var _is_consuming := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	print('action queue ready');
	pass # Replace with function body.


func enQueue(event: Dictionary) -> void:
	if not _is_valid_event(event):
		push_error('Invalid action queue event. Expected { eventName: String, payload: Dictionary }.')
		return

	_event_queue.append(event)
	print(_event_queue);
	consume_next()


func _is_valid_event(event: Dictionary) -> bool:
	return (
		event.has('eventName')
		and event.has('payload')
		and typeof(event['eventName']) == TYPE_STRING
		and typeof(event['payload']) == TYPE_DICTIONARY
	)


func consume_next() -> void:
	if _is_consuming or _event_queue.is_empty():
		return

	_current_event = _event_queue.pop_front()
	_is_consuming = true
	print('start consume: ', _current_event)
	consume_current()


func consume_current() -> void:
	if not _is_consuming:
		return

	var consumed_event: Dictionary = _current_event
	var consume_seconds := randf_range(MIN_CONSUME_SECONDS, MAX_CONSUME_SECONDS)
	await get_tree().create_timer(consume_seconds).timeout

	if not _is_consuming or _current_event != consumed_event:
		return

	_current_event = {}
	_is_consuming = false
	print('consumed: ', consumed_event, ' in ', consume_seconds, 's')
	consume_next()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
