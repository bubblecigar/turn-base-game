extends Control

@export var action_handler_path: NodePath

@onready var action_handler: Node = get_node_or_null(action_handler_path)
@onready var result_label: Label = $Center/Panel/Margin/Content/ResultLabel
@onready var detail_label: Label = $Center/Panel/Margin/Content/DetailLabel
@onready var reward_label: Label = $Center/Panel/Margin/Content/RewardLabel
@onready var reward_cards: HBoxContainer = $Center/Panel/Margin/Content/RewardCards
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
	_set_reward_cards(payload.get("reward_cards", []))
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


func _set_reward_cards(cards: Array) -> void:
	for child: Node in reward_cards.get_children():
		child.queue_free()

	var has_reward_cards := not cards.is_empty()
	reward_label.text = "Choose a card"
	reward_label.visible = has_reward_cards
	reward_cards.visible = has_reward_cards
	next_battle_button.disabled = has_reward_cards
	if not has_reward_cards:
		return

	var reward_button_count := 0
	for raw_card: Variant in cards:
		if not raw_card is Dictionary:
			continue

		var card_data := (raw_card as Dictionary).duplicate(true)
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 92)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _get_card_button_text(card_data)
		button.pressed.connect(_on_reward_card_pressed.bind(card_data))
		reward_cards.add_child(button)
		reward_button_count += 1

	next_battle_button.disabled = reward_button_count > 0


func _get_card_button_text(card_data: Dictionary) -> String:
	var title := str(card_data.get("title", card_data.get("id", "Card")))
	var body := str(card_data.get("body", ""))
	if body.is_empty():
		return title

	return "%s\n%s" % [title, body]


func _on_reward_card_pressed(card_data: Dictionary) -> void:
	if action_handler != null and action_handler.has_method("select_battle_reward_card"):
		action_handler.select_battle_reward_card(card_data)

	for child: Node in reward_cards.get_children():
		if child is Button:
			(child as Button).disabled = true
	reward_label.text = "Card added"
	next_battle_button.disabled = false
