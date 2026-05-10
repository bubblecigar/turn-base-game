extends RichTextLabel

@onready var action_queue: Node = $"../../ActionQueue"
@onready var action_handler: Node = $"../../ActionHandler"

var _log: Array[String] = []


func _ready() -> void:
	_push_log("Action: idle")
	action_queue.batch_enqueued.connect(_on_batch_enqueued)
	action_queue.batch_started.connect(_on_batch_started)
	action_queue.queue_drained.connect(_on_queue_drained)
	action_handler.processing_status_changed.connect(_on_processing_status_changed)


func _on_batch_enqueued(events: Array, pending_batch_count: int) -> void:
	_push_log("Queued: %s (%d pending)" % [_summarize_events(events), pending_batch_count])


func _on_batch_started(events: Array, pending_batch_count: int) -> void:
	_push_log("Batch: %s (%d pending)" % [_summarize_events(events), pending_batch_count])


func _on_queue_drained() -> void:
	_push_log("Queue drained")


func _on_processing_status_changed(is_processing: bool, event: Dictionary) -> void:
	if is_processing:
		_push_log("Processing: %s" % event.get("eventName", "unknown"))


func _push_log(entry: String) -> void:
	_log.push_front(entry)
	text = "\n".join(_log)
	scroll_to_line(0)


func _summarize_events(events: Array) -> String:
	var event_names: Array[String] = []
	for event: Dictionary in events:
		event_names.append(str(event.get("eventName", "unknown")))

	return ", ".join(event_names)
