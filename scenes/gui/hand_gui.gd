extends Control

const CARD_SIZE := Vector2(116.0, 158.0)
const CARD_OVERLAP_PIXELS := 34.0
const CARD_RAISE_PIXELS := 14.0
const CARD_COLORS := [
	Color(0.20, 0.28, 0.34, 1.0),
	Color(0.32, 0.24, 0.30, 1.0),
	Color(0.22, 0.34, 0.26, 1.0),
	Color(0.36, 0.30, 0.20, 1.0),
	Color(0.26, 0.26, 0.38, 1.0),
]

@onready var card_stack: Control = $CardStack

var _cards: Array[Dictionary] = [
	{"title": "Strike", "cost": "1", "body": "Deal damage"},
	{"title": "Guard", "cost": "0", "body": "Block damage"},
	{"title": "Heal", "cost": "1", "body": "Restore HP"},
	{"title": "Thunder", "cost": "1", "body": "Hit target"},
	{"title": "Focus", "cost": "0", "body": "Gain focus"},
]


func _ready() -> void:
	# set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_cards)
	_rebuild_cards()


func set_cards(cards: Array[Dictionary]) -> void:
	_cards = cards.duplicate(true)
	_rebuild_cards()


func _rebuild_cards() -> void:
	for child: Node in card_stack.get_children():
		child.queue_free()

	for index in _cards.size():
		var card := _create_card(_cards[index], index)
		card_stack.add_child(card)

	_layout_cards()


func _create_card(card_data: Dictionary, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.z_index = index

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLORS[index % CARD_COLORS.size()]
	style.border_color = Color(0.86, 0.88, 0.82, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)

	var title := Label.new()
	title.text = str(card_data.get("title", "Card"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)

	var cost := Label.new()
	cost.text = str(card_data.get("cost", "0"))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.add_theme_font_size_override("font_size", 14)
	header.add_child(cost)

	var body := Label.new()
	body.text = str(card_data.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 11)
	content.add_child(body)

	return card


func _layout_cards() -> void:
	if card_stack == null:
		return

	var card_count := card_stack.get_child_count()
	if card_count == 0:
		return

	var step := CARD_SIZE.x - CARD_OVERLAP_PIXELS
	var stack_width := CARD_SIZE.x + step * float(card_count - 1)
	var stack_height := CARD_SIZE.y + CARD_RAISE_PIXELS
	card_stack.size = Vector2.ZERO

	for index in card_count:
		var card := card_stack.get_child(index) as Control
		var centered_index := float(index) - float(card_count - 1) / 2.0
		card.size = CARD_SIZE
		card.position = Vector2(
			-stack_width / 2.0 + step * index,
			-CARD_SIZE.y / 2.0 + absf(centered_index) * CARD_RAISE_PIXELS * 0.35
		)
		card.rotation_degrees = centered_index * 4.0
