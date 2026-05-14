extends Label

@onready var action_handler: Node = $"../../ActionHandler"


func _ready() -> void:
	text = "Idle"
	action_handler.processing_status_changed.connect(_on_processing_status_changed)


func _on_processing_status_changed(processing: bool, event: Dictionary) -> void:
	if processing:
		text = "Processing: %s" % event.get("eventName", "unknown")
	else:
		text = "Idle"
