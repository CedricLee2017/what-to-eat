class_name FreeCookSheet
extends Control

## 揀菜時嘅「自由創作」：即場揀 1–3 樣材料 + 六種煮法，
## 完成後直接煮，唔一定要加入食譜簿。

signal confirmed(recipe_data: Dictionary)
signal closed

var state: MealGameState
var slot := 0

var _selected: Array[String] = []
var _method := "pan_fry"
var _method_touched := false
var _name_edit: LineEdit
var _preview: DishArt
var _preview_name: Label
var _cost_label: Label
var _method_line: Label
var _status: Label
var _confirm: Button
var _item_buttons: Dictionary = {}
var _method_buttons: Dictionary = {}


func _ready() -> void:
	modulate.a = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.13, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close()
	)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var sheet := PanelContainer.new()
	sheet.custom_minimum_size.x = 692.0
	sheet.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, 32, 22, Color.TRANSPARENT, 0, 22))
	center.add_child(sheet)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	sheet.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(UIKit.pill("自由創作 · %s" % MealData.MEAL_NAMES[slot], UIKit.CORAL_SOFT, UIKit.CORAL, 11))
	title_box.add_child(UIKit.label("自己揀材料同煮法", 27, UIKit.INK, true))
	var close := UIKit.ghost_button("×", UIKit.MUTED, 26, Vector2(44, 44))
	close.pressed.connect(_close)
	header.add_child(close)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "菜式名（可留空，自動命名）"
	_name_edit.max_length = 12
	_name_edit.custom_minimum_size.y = 44
	_name_edit.add_theme_font_override("font", UIKit.font(false))
	_name_edit.add_theme_font_size_override("font_size", 17)
	_name_edit.add_theme_color_override("font_color", UIKit.INK)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(0.6, 0.56, 0.5, 0.6))
	_name_edit.add_theme_stylebox_override("normal", UIKit.box(UIKit.CREAM, 16, 0, UIKit.LINE, 1, 11))
	_name_edit.add_theme_stylebox_override("focus", UIKit.box(UIKit.SUN_SOFT, 16, 0, UIKit.SUN, 2, 11))
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	box.add_child(_name_edit)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 12)
	box.add_child(preview_row)
	var art_panel := UIKit.panel(UIKit.SUN_SOFT, 22, 0, Color.TRANSPARENT, 0, 6)
	art_panel.custom_minimum_size = Vector2(148, 148)
	preview_row.add_child(art_panel)
	_preview = DishArt.new()
	_preview.custom_minimum_size = Vector2(136, 136)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art_panel.add_child(_preview)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_row.add_child(info)
	_preview_name = UIKit.label("未命名", 22, UIKit.INK, true)
	preview_row.add_theme_constant_override("separation", 12)
	info.add_child(_preview_name)
	_cost_label = UIKit.label("揀材料開始", 12, UIKit.MUTED, false)
	info.add_child(_cost_label)
	_method_line = UIKit.label("煮法：%s" % MealData.method_name(_method), 12, Color("#3F7D5F"), true)
	info.add_child(_method_line)
	info.add_child(UIKit.label("雪櫃有嘅材料會自動扣減；唔夠會問你補購。", 10, UIKit.MUTED, false))

	var ingredients_title := HBoxContainer.new()
	box.add_child(ingredients_title)
	ingredients_title.add_child(UIKit.label("材料（最多 3 樣）", 14, UIKit.INK, true))
	ingredients_title.add_child(UIKit.spacer_h())
	var fridge_total := UIKit.label("雪櫃 %d 件" % state.fridge_total(), 11, UIKit.MUTED, false)
	ingredients_title.add_child(fridge_total)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 214
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scroll_theme := Theme.new()
	scroll_theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	scroll_theme.set_stylebox("grabber", "VScrollBar", UIKit.box(UIKit.LINE, 3))
	scroll.theme = scroll_theme
	box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(grid)
	for item_id in MealData.INGREDIENTS:
		var button := _make_item_button(str(item_id))
		grid.add_child(button)
		_item_buttons[str(item_id)] = button

	var method_row := HBoxContainer.new()
	method_row.add_theme_constant_override("separation", 5)
	box.add_child(method_row)
	method_row.add_child(UIKit.label("煮法", 13, UIKit.MUTED, false))
	for method_id in MealData.COOK_METHOD_ORDER:
		var method_info := MealData.method_info(str(method_id))
		var method_button := UIKit.button(str(method_info.name), UIKit.PAPER, UIKit.MUTED, 15, 13, true, Vector2(75, 34))
		method_button.pressed.connect(_select_method.bind(str(method_id)))
		method_row.add_child(method_button)
		_method_buttons[str(method_id)] = method_button
	method_row.add_child(UIKit.spacer_h())

	_status = UIKit.label("", 11, UIKit.CORAL, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	_confirm = UIKit.button("開始煮", UIKit.CORAL, Color.WHITE, 23, 18, true, Vector2(0, 52))
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.pressed.connect(_confirm_cook)
	box.add_child(_confirm)

	_select_method("pan_fry")
	_refresh()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _make_item_button(item_id: String) -> Button:
	var count := state.fridge_count(item_id)
	var label_text := str(MealData.INGREDIENTS[item_id].name)
	if count > 0:
		label_text += " ·%d" % count
	var button := UIKit.button(label_text, UIKit.PAPER, UIKit.INK, 14, 11, true, Vector2(0, 38))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 13, 0, UIKit.LINE, 1, 4))
	button.add_theme_stylebox_override("hover", UIKit.box(MealData.ingredient_soft_color(item_id), 13, 0, UIKit.LINE, 1, 4))
	button.add_theme_stylebox_override("pressed", UIKit.box(MealData.ingredient_soft_color(item_id), 13, 0, UIKit.LINE, 1, 4))
	button.pressed.connect(_toggle_item.bind(item_id))
	return button


func _toggle_item(item_id: String) -> void:
	Sfx.play("click")
	if _selected.has(item_id):
		_selected.erase(item_id)
	elif _selected.size() >= 3:
		_status.text = "最多 3 樣材料"
		return
	else:
		_selected.append(item_id)
		if not _method_touched and not _selected.is_empty():
			_method = MealData.suggest_method(_selected)
	_status.text = ""
	_refresh_item_buttons()
	_style_methods()
	_refresh()


func _refresh_item_buttons() -> void:
	for item_id in _item_buttons:
		var button: Button = _item_buttons[item_id]
		var selected := _selected.has(item_id)
		var bg := UIKit.CORAL_SOFT if selected else UIKit.PAPER
		var border := UIKit.CORAL if selected else UIKit.LINE
		var width := 2 if selected else 1
		button.add_theme_color_override("font_color", UIKit.CORAL if selected else UIKit.INK)
		button.add_theme_color_override("font_hover_color", UIKit.CORAL if selected else UIKit.INK)
		button.add_theme_color_override("font_pressed_color", UIKit.CORAL if selected else UIKit.INK)
		button.add_theme_stylebox_override("normal", UIKit.box(bg, 13, 0, border, width, 4))
		button.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.03), 13, 0, border, width, 4))


func _select_method(method_id: String) -> void:
	_method = method_id
	_method_touched = true
	Sfx.play("click")
	_style_methods()
	_refresh()


func _style_methods() -> void:
	for id in _method_buttons:
		var button: Button = _method_buttons[id]
		var selected: bool = str(id) == _method
		var bg := UIKit.MINT_SOFT if selected else UIKit.PAPER
		var fg := Color("#3F7D5F") if selected else UIKit.MUTED
		button.add_theme_color_override("font_color", fg)
		button.add_theme_color_override("font_hover_color", fg)
		button.add_theme_color_override("font_pressed_color", fg)
		button.add_theme_stylebox_override("normal", UIKit.box(bg, 15, 0, UIKit.LINE, 1, 5))
		button.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.03), 15, 0, UIKit.LINE, 1, 5))


func _auto_name() -> String:
	if _selected.is_empty():
		return "未命名"
	var text := "%s%s" % [MealData.method_info(_method).verb, MealData.ingredient_names(_selected).replace("・", "")]
	if text.length() > 12:
		text = text.substr(0, 12)
	return text


func _display_name() -> String:
	var typed := _name_edit.text.strip_edges() if _name_edit != null else ""
	return typed if not typed.is_empty() else _auto_name()


func _missing_cost() -> int:
	var needed := {}
	for item_id in _selected:
		needed[item_id] = int(needed.get(item_id, 0)) + 1
	var cost := 0
	for item_id in needed:
		var lack := int(needed[item_id]) - state.fridge_count(item_id)
		if lack > 0:
			cost += state.ingredient_price(item_id) * lack
	return cost


func _refresh() -> void:
	if _preview == null:
		return
	var display_name := _display_name()
	_preview_name.text = display_name
	_method_line.text = "煮法：%s · %s" % [MealData.method_name(_method), MealData.method_info(_method).line]
	if _selected.is_empty():
		_preview.recipe_id = ""
		_preview.recipe_data = {}
		_cost_label.text = "揀材料開始 · 1–3 樣"
		_confirm.text = "開始煮"
		_confirm.disabled = true
		return
	var recipe := _build_recipe(display_name)
	_preview.recipe_id = ""
	_preview.recipe_data = recipe
	var cost := _missing_cost()
	var reserve := state.reserve_for_slot(slot)
	var affordable := cost + reserve <= state.remaining()
	_cost_label.text = "材料費 $%d · 補購後剩 $%d · %d kcal" % [cost, maxi(0, state.remaining() - cost), int(recipe.kcal)]
	if not affordable:
		if cost <= state.remaining():
			_confirm.text = "唔夠錢（要留 $%d）" % reserve
		else:
			_confirm.text = "唔夠錢"
		_confirm.disabled = true
		_status.text = "呢個組合會令你冇錢食下一餐。"
	else:
		_confirm.text = "開始煮 · $%d" % cost
		_confirm.disabled = false
		_status.text = ""


func _build_recipe(display_name: String) -> Dictionary:
	return MealData.build_custom_recipe("preview", display_name, _selected, MealData.method_form(_method), [], _method)


func _confirm_cook() -> void:
	if _selected.is_empty():
		return
	var recipe := _build_recipe(_display_name())
	if recipe.is_empty():
		_status.text = "再揀一次材料。"
		return
	Sfx.play("start")
	confirmed.emit(recipe)


func _close() -> void:
	Sfx.play("click")
	closed.emit()
