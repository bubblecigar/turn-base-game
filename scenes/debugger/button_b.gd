extends Button

@onready var action_queue: Node = $"../../ActionQueue"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	action_queue.enQueue([{
		"eventName": "spawn_entity",
		"payload": {
			"type": "character",
			"max_hp": 20,
			"spec": _get_character_spec(),
		},
	}])


func _get_character_spec() -> Dictionary:
	return {
		"head": {
			"radius": int($"../HeadRadiusSpinBox".value),
		},
		"neck": _get_part_spec("Neck"),
		"body": _get_part_spec("Body"),
		"arms": _get_part_spec("Arms"),
		"legs": _get_part_spec("Legs"),
	}


func _get_part_spec(part_name: String) -> Dictionary:
	return {
		"width": int(get_node("../%sWidthSpinBox" % part_name).value),
		"height": int(get_node("../%sHeightSpinBox" % part_name).value),
	}


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
