extends Node

var _event_queue: Array[Dictionary] = []
var _current_event: Dictionary = {}
var _is_consuming := false

@onready var action_handler: Node = $"../ActionHandler"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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
	consume_current()


func consume_current() -> void:
	if not _is_consuming:
		return

	var consumed_event: Dictionary = _current_event
	await action_handler.consume(consumed_event)

	if not _is_consuming or _current_event != consumed_event:
		return

	_current_event = {}
	_is_consuming = false
	consume_next()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
