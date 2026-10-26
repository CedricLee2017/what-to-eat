class_name DishPicker
extends Control

signal dish_chosen(recipe_id: String)
signal free_cook_pressed
signal closed

var state: MealGameState
var slot := 0

var _sheet: PanelContainer


func _ready() -> void:
	modulate.a = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.13, 0.1, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	_sheet = PanelContainer.new()
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 0.0
	_sheet.offset_right = 0.0
	_sheet.offset_top = -840.0
	_sheet.offset_bottom = 0.0
	var sheet_style := UIKit.box(UIKit.PAPER, 0, 24)
	sheet_style.corner_radius_top_left = 34
	sheet_style.corner_radius_top_right = 34
	sheet_style.content_margin_left = 24.0
	sheet_style.content_margin_right = 24.0
	sheet_style.content_margin_top = 16.0
	sheet_style.content_margin_bottom = 20.0
	_sheet.add_theme_stylebox_override("panel", sheet_style)
	add_child(_sheet)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_sheet.add_child(box)

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
	title_box.add_child(UIKit.label("%s食咩好？" % MealData.MEAL_NAMES[slot], 29, UIKit.INK, true))
	var subtitle := "預算剩 $%d · 雪櫃 %d 件 · %s · 特價 %s" % [state.remaining(), state.fridge_total(), state.market_note(), "、".join(state.sale_names())]
	var subtitle_label := UIKit.wrapped(subtitle, 13, UIKit.MUTED, false)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	title_box.add_child(subtitle_label)

	var close_button := UIKit.ghost_button("×", UIKit.MUTED, 28, Vector2(44, 44))
	close_button.pressed.connect(_close)
	header.add_child(close_button)

	box.add_child(_make_free_entry())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	var scroll_theme := Theme.new()
	scroll_theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	scroll_theme.set_stylebox("grabber", "VScrollBar", UIKit.box(UIKit.LINE, 3))
	scroll_theme.set_stylebox("grabber_highlight", "VScrollBar", UIKit.box(UIKit.MUTED.lightened(0.25), 3))
	scroll_theme.set_stylebox("grabber_pressed", "VScrollBar", UIKit.box(UIKit.MUTED, 3))
	scroll.theme = scroll_theme
	box.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)

	var grid := GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)

	var recipes := MealData.visible_recipes().duplicate()
	recipes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var price_a := state.price_of(a.id)
		var price_b := state.price_of(b.id)
		var afford_a := price_a <= state.remaining()
		var afford_b := price_b <= state.remaining()
		if afford_a != afford_b:
			return afford_a
		var sale_a := state.on_sale(a.id)
		var sale_b := state.on_sale(b.id)
		if sale_a != sale_b:
			return sale_a
		return price_a < price_b
	)
	for recipe in recipes:
		grid.add_child(_make_card(recipe))

	content.add_child(UIKit.gap(0, 18))

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _make_free_entry() -> PanelContainer:
	var free_panel := UIKit.panel(UIKit.CORAL_SOFT, 20, 0, UIKit.CORAL, 2, 0)
	free_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var free_button := Button.new()
	free_button.flat = true
	free_button.focus_mode = Control.FOCUS_NONE
	free_button.custom_minimum_size = Vector2(0, 62)
	free_button.add_theme_stylebox_override("normal", UIKit.box(Color(1, 1, 1, 0), 20))
	free_button.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 1, 0.35), 20))
	free_button.add_theme_stylebox_override("pressed", UIKit.box(Color(1, 1, 1, 0.18), 20))
	free_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	free_button.pressed.connect(func() -> void:
		Sfx.play("click")
		free_cook_pressed.emit()
	)
	free_panel.add_child(free_button)
	var free_box := VBoxContainer.new()
	free_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	free_box.alignment = BoxContainer.ALIGNMENT_CENTER
	free_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	free_button.add_child(free_box)
	var free_row := HBoxContainer.new()
	free_row.alignment = BoxContainer.ALIGNMENT_CENTER
	free_row.add_theme_constant_override("separation", 8)
	free_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	free_box.add_child(free_row)
	var free_title := UIKit.label("＋ 自由創作", 19, UIKit.CORAL, true)
	free_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	free_row.add_child(free_title)
	var free_note := UIKit.label("自己揀材料 × 煎炸炆燉焗蒸", 11, UIKit.MUTED, false)
	free_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	free_row.add_child(free_note)
	return free_panel


func _make_card(recipe: Dictionary) -> Button:
	var price := state.price_of(recipe.id)
	var affordable := state.can_cook(slot, recipe.id)
	var on_sale := state.on_sale(recipe.id)
	var repeat := state.week_count(recipe.id)
	var covered := state.fridge_covered(recipe.id)
	var required := state.required_count(recipe.id)
	var reserve := state.reserve_for_slot(slot)

	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 166)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not affordable
	var border := UIKit.MINT if on_sale else UIKit.LINE
	var border_width := 2 if on_sale else 1
	var bg := UIKit.PAPER
	card.add_theme_stylebox_override("normal", UIKit.box(bg, 22, 5, border, border_width))
	card.add_theme_stylebox_override("hover", UIKit.box(UIKit.MINT_SOFT, 22, 8, border, border_width))
	card.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND.lightened(0.2), 22, 4, border, border_width))
	card.add_theme_stylebox_override("disabled", UIKit.box(bg, 22, 3, UIKit.LINE, 1))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not affordable:
		card.modulate = Color(1, 1, 1, 0.52)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var art := DishArt.new()
	art.recipe_id = str(recipe.id)
	art.custom_minimum_size = Vector2(64, 64)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)

	var name_label := UIKit.label(str(recipe.name), 21, UIKit.INK, true)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 6)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meta)

	var method_id := MealData.method_of(recipe)
	var method_info := MealData.method_info(method_id)
	var method_label := UIKit.label(str(method_info.name), 12, Color(method_info.color), true)
	method_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta.add_child(method_label)

	var crown_badge := CrownBadge.new()
	crown_badge.level = FoodBook.crown_level_for_recipe(str(recipe.id))
	crown_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_child(crown_badge)
	meta.add_child(UIKit.spacer_h())

	var price_color := UIKit.INK
	if not affordable:
		price_color = UIKit.MUTED
	elif price == 0 or on_sale:
		price_color = Color("#3F7D5F")
	var price_label := UIKit.label("$%d" % price, 20, price_color, true)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(price_label)

	var ingredients := UIKit.label(MealData.item_names(recipe), 13, UIKit.MUTED, false)
	ingredients.clip_text = true
	ingredients.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(ingredients)

	var nutrients := HBoxContainer.new()
	nutrients.add_theme_constant_override("separation", 8)
	nutrients.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(nutrients)
	for key in MealData.STAT_KEYS:
		nutrients.add_child(_nutrient_chip(key, int(recipe[_stat_field(key)])))

	box.add_child(UIKit.spacer_h())

	var notes: Array[String] = []
	if not affordable:
		if price > state.remaining():
			notes.append("唔夠錢")
		else:
			notes.append("要留 $%d 畀下一餐" % reserve)
	else:
		if required > 0 and covered >= required:
			notes.append("雪櫃齊料")
		elif covered > 0:
			notes.append("雪櫃有 %d/%d 樣" % [covered, required])
		notes.append(str(recipe.tag))
		notes.append("%d kcal" % int(recipe.kcal))
		if on_sale:
			notes.append("今日特價 -30%")
		if repeat > 0:
			notes.append("本週食過 %d 次" % repeat)
	var note_color := UIKit.CORAL if not affordable else (Color("#3F7D5F") if on_sale else UIKit.MUTED)
	var note_label := UIKit.label(" · ".join(notes), 11, note_color, not affordable or on_sale)
	note_label.clip_text = true
	note_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(note_label)

	if affordable:
		card.pressed.connect(func() -> void:
			Sfx.play("click")
			dish_chosen.emit(str(recipe.id))
		)
	else:
		card.tooltip_text = "預算唔夠，試下平啲嘅菜式"
	return card


func _nutrient_chip(key: String, value: int) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 2)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := StatIcon.new()
	icon.key = key
	icon.custom_minimum_size = Vector2(17, 17)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)
	var label := UIKit.label(str(value), 13, MealData.stat_color(key), true)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip


func _stat_field(key: String) -> String:
	match key:
		"body":
			return "protein"
		"vitc":
			return "vitc"
		"vitd":
			return "vitd"
		"fiber":
			return "fiber"
		_:
			return "mood"


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _close() -> void:
	Sfx.play("click")
	closed.emit()
