extends Control

@export var action_handler_path: NodePath

@onready var action_handler: Node = get_node_or_null(action_handler_path)
@onready var result_label: Label = $Center/Panel/Margin/Content/ResultLabel
@onready var detail_label: Label = $Center/Panel/Margin/Content/DetailLabel
@onready var next_battle_button: Button = $Center/Panel/Margin/Content/NextBattleButton


func _ready() -> void:
	visible = false
	if action_handler != null:
		action_handler.end_battle.connect(_on_end_battle)
	if next_battle_button != null:
		next_battle_button.pressed.connect(_on_next_battle_pressed)


func _on_end_battle(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	result_label.text = str(payload.get("result", "Battle ended"))
	detail_label.text = _get_detail_text(payload)
	visible = true
	move_to_front()


func _get_detail_text(payload: Dictionary) -> String:
	var winner_entity_ids: Array = payload.get("winner_entity_ids", [])
	var defeated_entity_ids: Array = payload.get("defeated_entity_ids", [])
	if winner_entity_ids.is_empty():
		return "No winners remain. Defeated: %s" % defeated_entity_ids

	return "Winner: %s\nDefeated: %s" % [winner_entity_ids, defeated_entity_ids]


func _on_next_battle_pressed() -> void:
	get_tree().reload_current_scene()
