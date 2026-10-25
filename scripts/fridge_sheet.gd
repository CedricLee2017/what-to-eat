class_name FridgeSheet
extends Control

signal closed
signal changed

var state: MealGameState

var _grid: GridContainer
var _cap_label: Label
var _budget_label: Label
var _cards: Dictionary = {}
var _sort_order := {"protein": 0, "veg": 1, "grain": 2, "dairy": 3, "fruit": 4}


func _ready() -> void:
	modulate.a = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.13, 0.1, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var sheet := PanelContainer.new()
	sheet.anchor_left = 0.0
	sheet.anchor_right = 1.0
	sheet.anchor_top = 1.0
	sheet.anchor_bottom = 1.0
	sheet.offset_left = 0.0
	sheet.offset_right = 0.0
	sheet.offset_top = -920.0
	sheet.offset_bottom = 0.0
	var sheet_style := UIKit.box(UIKit.PAPER, 0, 24)
	sheet_style.corner_radius_top_left = 34
	sheet_style.corner_radius_top_right = 34
	sheet_style.content_margin_left = 22.0
	sheet_style.content_margin_right = 22.0
	sheet_style.content_margin_top = 14.0
	sheet_style.content_margin_bottom = 18.0
	sheet.add_theme_stylebox_override("panel", sheet_style)
	add_child(sheet)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	sheet.add_child(box)

	var grabber_center := CenterContainer.new()
	var grabber := UIKit.panel(UIKit.LINE, 999, 0, Color.TRANSPARENT, 0, 0)
	grabber.custom_minimum_size = Vector2(52, 5)
	grabber_center.add_child(grabber)
	box.add_child(grabber_center)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(UIKit.label("雪櫃", 29, UIKit.INK, true))
	var subtitle := HBoxContainer.new()
	subtitle.add_theme_constant_override("separation", 10)
	title_box.add_child(subtitle)
	_cap_label = UIKit.label("", 13, UIKit.MUTED, false)
	subtitle.add_child(_cap_label)
	_budget_label = UIKit.label("", 13, Color("#3F7D5F"), true)
	subtitle.add_child(_budget_label)

	var close_button := UIKit.ghost_button("×", UIKit.MUTED, 28, Vector2(44, 44))
	close_button.pressed.connect(_close)
	header.add_child(close_button)

	var hint := UIKit.label("%s · 特價 %s -30%%\n買定食材，雪櫃存到聽日；煮飯時會先用雪櫃存貨。" % [state.market_note(), "、".join(state.sale_names())], 12, UIKit.MUTED, false)
	hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scroll_theme := Theme.new()
	scroll_theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	scroll_theme.set_stylebox("grabber", "VScrollBar", UIKit.box(UIKit.LINE, 3))
	scroll_theme.set_stylebox("grabber_highlight", "VScrollBar", UIKit.box(UIKit.MUTED.lightened(0.25), 3))
	scroll.theme = scroll_theme
	box.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(_grid)

	var items: Array = MealData.INGREDIENTS.keys()
	items.sort_custom(func(a: String, b: String) -> bool:
		var cat_a := int(_sort_order.get(str(MealData.INGREDIENTS[a].get("cat", "veg")), 9))
		var cat_b := int(_sort_order.get(str(MealData.INGREDIENTS[b].get("cat", "veg")), 9))
		if cat_a != cat_b:
			return cat_a < cat_b
		return state.ingredient_price(a) < state.ingredient_price(b)
	)
	for item_id in items:
		var card := _make_card(str(item_id))
		_grid.add_child(card)
		_cards[str(item_id)] = card

	content.add_child(UIKit.gap(0, 16))

	_refresh()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _make_card(item_id: String) -> Button:
	var info: Dictionary = MealData.INGREDIENTS[item_id]
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 86)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 18, 2, UIKit.LINE, 1))
	card.add_theme_stylebox_override("hover", UIKit.box(UIKit.MINT_SOFT, 18, 4, UIKit.LINE, 1))
	card.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND.lightened(0.2), 18, 2, UIKit.LINE, 1))
	card.add_theme_stylebox_override("disabled", UIKit.box(UIKit.PAPER, 18, 0, UIKit.LINE, 1))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(_buy.bind(item_id))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var badge := UIKit.panel(MealData.ingredient_soft_color(item_id), 999, 0, Color.TRANSPARENT, 0, 0)
	badge.custom_minimum_size = Vector2(38, 38)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var badge_label := UIKit.label(MealData.ingredient_initial(item_id), 17, MealData.ingredient_color(item_id), true)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)
	var name_label := UIKit.label(str(info.name), 15, UIKit.INK, true)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(name_label)
	var price_label := UIKit.label("", 13, UIKit.MUTED, false)
	text_box.add_child(price_label)
	var count_label := UIKit.label("", 12, UIKit.MUTED, false)
	text_box.add_child(count_label)

	var plus := UIKit.panel(UIKit.SUN_SOFT, 999, 0, Color.TRANSPARENT, 0, 0)
	plus.custom_minimum_size = Vector2(30, 30)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(plus)
	var plus_label := UIKit.label("＋", 18, Color("#9A6C12"), true)
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_child(plus_label)

	card.set_meta("price_label", price_label)
	card.set_meta("count_label", count_label)
	card.set_meta("name_label", name_label)
	return card


func _buy(item_id: String) -> void:
	if not state.can_buy_ingredient(item_id):
		Sfx.play("click")
		_refresh()
		return
	if state.buy_ingredient(item_id):
		Sfx.play("coin")
		changed.emit()
		_refresh()


func _refresh() -> void:
	if state == null:
		return
	_cap_label.text = "容量 %d / %d" % [state.fridge_total(), MealGameState.FRIDGE_CAPACITY]
	_budget_label.text = "預算剩 $%d" % state.remaining()
	_budget_label.add_theme_color_override("font_color", UIKit.CORAL if state.remaining() <= 14 else Color("#3F7D5F"))
	var full := state.fridge_total() >= MealGameState.FRIDGE_CAPACITY
	for item_id in _cards:
		var card: Button = _cards[item_id]
		var price := state.ingredient_price(item_id)
		var count := state.fridge_count(item_id)
		var affordable := price <= state.remaining() and not full
		card.disabled = not affordable
		card.modulate = Color(1, 1, 1, 1.0 if affordable else 0.5)
		var price_label: Label = card.get_meta("price_label")
		var count_label: Label = card.get_meta("count_label")
		var sale := state.sale_ids.has(item_id)
		price_label.text = "$%d%s" % [price, " · 特價" if sale else ""]
		price_label.add_theme_color_override("font_color", Color("#3F7D5F") if sale else UIKit.MUTED)
		count_label.text = ("雪櫃有 %d" % count) if count > 0 else ("雪櫃滿了" if full else "撳一下買")
		count_label.add_theme_color_override("font_color", UIKit.MUTED if count > 0 else UIKit.LINE.darkened(0.25))


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _close() -> void:
	Sfx.play("click")
	closed.emit()
