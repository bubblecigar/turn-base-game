extends Node

const STAGES_PATH := "res://scenes/stage_control/stages.json"

@export var stage_key: String = ""

@onready var action_queue: Node = $"../ActionQueue"


func _ready() -> void:
	var stages := _load_stages()
	if stages.is_empty():
		push_error("StageController: no stages found in %s." % STAGES_PATH)
		return

	var key := stage_key
	if key.is_empty() or not stages.has(key):
		var keys := stages.keys()
		key = keys[randi() % keys.size()]

	var template: Dictionary = stages.get(key, {})
	if template.is_empty():
		push_error("StageController: stage '%s' not found in %s." % [key, STAGES_PATH])
		return
	_init_from_template(template)


func _load_stages() -> Dictionary:
	var file := FileAccess.open(STAGES_PATH, FileAccess.READ)
	if file == null:
		push_error("StageController: could not open %s." % STAGES_PATH)
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("StageController: JSON parse error in %s." % STAGES_PATH)
		return {}
	return json.data


func _load_template(key: String) -> Dictionary:
	return _load_stages().get(key, {})


func _init_from_template(t: Dictionary) -> void:
	var board: Dictionary = t.get("board", {})
	action_queue.enQueue({
		"eventName": "spawn_board",
		"payload": {
			"i": int(board.get("cols", 4)),
			"j": int(board.get("rows", 4)),
		},
	})

	var entities: Array = t.get("entities", [])
	for entity in entities:
		if entity is Dictionary and entity.has("type") and entity.has("spec"):
			action_queue.enQueue({
				"eventName": "spawn_entity",
				"payload": {
					"type": entity["type"],
					"spec": entity["spec"],
				},
			})
