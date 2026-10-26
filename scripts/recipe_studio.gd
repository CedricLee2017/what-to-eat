class_name RecipeStudio
extends Control

signal saved(recipe_id: String)
signal closed

var _name_edit: LineEdit
var _preview: DishArt
var _preview_name: Label
var _cost_label: Label
var _nutrient_row: HBoxContainer
var _selected: Array[String] = []
var _form := "plate"
var _method := "pan_fry"
var _item_buttons: Dictionary = {}
var _form_buttons: Dictionary = {}
var _method_buttons: Dictionary = {}
var _save_button: Button
var _status: Label


func _ready() -> void:
	modulate.a = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.13, 0.1, 0.5)
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
	sheet.custom_minimum_size.x = 456.0
	sheet.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, 32, 20, Color.TRANSPARENT, 0, 24))
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
	title_box.add_child(UIKit.label("創作新食譜", 28, UIKit.INK, true))
	title_box.add_child(UIKit.label("揀 1–3 樣材料，幫佢改個名。", 12, UIKit.MUTED, false))
	var close := UIKit.ghost_button("×", UIKit.MUTED, 26, Vector2(44, 44))
	close.pressed.connect(_close)
	header.add_child(close)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "食物名稱（最多 12 字）"
	_name_edit.max_length = 12
	_name_edit.custom_minimum_size.y = 56
	_name_edit.add_theme_font_override("font", UIKit.font(false))
	_name_edit.add_theme_font_size_override("font_size", UIKit.scaled_font(18))
	_name_edit.add_theme_color_override("font_color", UIKit.INK)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(0.6, 0.56, 0.5, 0.6))
	_name_edit.add_theme_stylebox_override("normal", UIKit.box(UIKit.CREAM, 16, 0, UIKit.LINE, 1, 12))
	_name_edit.add_theme_stylebox_override("focus", UIKit.box(UIKit.SUN_SOFT, 16, 0, UIKit.SUN, 2, 12))
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh_preview())
	box.add_child(_name_edit)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 12)
	box.add_child(preview_row)
	var art_panel := UIKit.panel(UIKit.SUN_SOFT, 22, 0, Color.TRANSPARENT, 0, 8)
	art_panel.custom_minimum_size = Vector2(170, 170)
	preview_row.add_child(art_panel)
	_preview = DishArt.new()
	_preview.custom_minimum_size = Vector2(150, 150)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art_panel.add_child(_preview)

	var preview_info := VBoxContainer.new()
	preview_info.add_theme_constant_override("separation", 4)
	preview_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_row.add_child(preview_info)
	_preview_name = UIKit.label("未命名", 21, UIKit.INK, true)
	preview_info.add_child(_preview_name)
	_cost_label = UIKit.label("成本 $0 · 0 kcal", 12, UIKit.MUTED, false)
	preview_info.add_child(_cost_label)
	_nutrient_row = HBoxContainer.new()
	_nutrient_row.add_theme_constant_override("separation", 8)
	preview_info.add_child(_nutrient_row)
	preview_info.add_child(UIKit.label("材料會按雪櫃數量扣減；唔夠會問你補購。", 10, UIKit.MUTED, false))

	var ingredients_title := HBoxContainer.new()
	box.add_child(ingredients_title)
	ingredients_title.add_child(UIKit.label("材料", 15, UIKit.INK, true))
	ingredients_title.add_child(UIKit.spacer_h())
	ingredients_title.add_child(UIKit.label("最多 3 樣", 11, UIKit.MUTED, false))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 250
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for item_id in MealData.INGREDIENTS:
		var button := _make_item_button(str(item_id))
		grid.add_child(button)
		_item_buttons[str(item_id)] = button

	box.add_child(UIKit.label("煮法", 13, UIKit.MUTED, false))
	var method_grid := GridContainer.new()
	method_grid.columns = 3
	method_grid.add_theme_constant_override("h_separation", 6)
	method_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(method_grid)
	for method_id in MealData.COOK_METHOD_ORDER:
		var method_info := MealData.method_info(str(method_id))
		var method_button := UIKit.button(str(method_info.name), UIKit.PAPER, UIKit.MUTED, 15, 13, true, Vector2(0, 40))
		method_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		method_button.pressed.connect(_set_method.bind(str(method_id)))
		method_grid.add_child(method_button)
		_method_buttons[str(method_id)] = method_button

	box.add_child(UIKit.label("上碟裝飾", 13, UIKit.MUTED, false))
	var form_grid := GridContainer.new()
	form_grid.columns = 5
	form_grid.add_theme_constant_override("h_separation", 6)
	form_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(form_grid)
	for form_id in MealData.CUSTOM_FORMS:
		var form_button := UIKit.button(str(MealData.CUSTOM_FORM_NAMES[form_id]), UIKit.PAPER, UIKit.MUTED, 15, 12, true, Vector2(0, 40))
		form_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		form_button.pressed.connect(_set_form.bind(str(form_id)))
		form_grid.add_child(form_button)
		_form_buttons[str(form_id)] = form_button

	_status = UIKit.label("", 11, UIKit.CORAL, true)
	box.add_child(_status)

	_save_button = UIKit.button("加入食譜簿", UIKit.CORAL, Color.WHITE, 24, 19, true, Vector2(0, 52))
	_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_button.pressed.connect(_save)
	box.add_child(_save_button)

	_set_method("pan_fry")
	_set_form("plate")
	_refresh_preview()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _make_item_button(item_id: String) -> Button:
	var button := UIKit.button(str(MealData.INGREDIENTS[item_id].name), UIKit.PAPER, UIKit.INK, 14, 12, true, Vector2(0, 42))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 14, 0, UIKit.LINE, 1, 5))
	button.add_theme_stylebox_override("hover", UIKit.box(MealData.ingredient_soft_color(item_id), 14, 0, UIKit.LINE, 1, 5))
	button.add_theme_stylebox_override("pressed", UIKit.box(MealData.ingredient_soft_color(item_id), 14, 0, UIKit.LINE, 1, 5))
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
	_status.text = ""
	_refresh_item_buttons()
	_refresh_preview()


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
		button.add_theme_stylebox_override("normal", UIKit.box(bg, 14, 0, border, width, 5))
		button.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.03), 14, 0, border, width, 5))


func _set_method(method_id: String) -> void:
	_method = method_id
	for id in _method_buttons:
		var button: Button = _method_buttons[id]
		var selected: bool = str(id) == method_id
		var bg := UIKit.MINT_SOFT if selected else UIKit.PAPER
		var fg := Color("#3F7D5F") if selected else UIKit.MUTED
		button.add_theme_color_override("font_color", fg)
		button.add_theme_color_override("font_hover_color", fg)
		button.add_theme_color_override("font_pressed_color", fg)
		button.add_theme_stylebox_override("normal", UIKit.box(bg, 15, 0, UIKit.LINE, 1, 5))
		button.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.03), 15, 0, UIKit.LINE, 1, 5))
	_refresh_preview()


func _set_form(form_id: String) -> void:
	_form = form_id
	for id in _form_buttons:
		var button: Button = _form_buttons[id]
		var selected: bool = str(id) == form_id
		var bg := UIKit.SUN_SOFT if selected else UIKit.PAPER
		var fg := Color("#9A6C12") if selected else UIKit.MUTED
		button.add_theme_color_override("font_color", fg)
		button.add_theme_color_override("font_hover_color", fg)
		button.add_theme_color_override("font_pressed_color", fg)
		button.add_theme_stylebox_override("normal", UIKit.box(bg, 15, 0, UIKit.LINE, 1, 5))
		button.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.03), 15, 0, UIKit.LINE, 1, 5))
	_refresh_preview()


func _refresh_preview() -> void:
	var recipe_name := _name_edit.text.strip_edges()
	if recipe_name.is_empty():
		recipe_name = "未命名"
	_preview_name.text = recipe_name
	if _selected.is_empty():
		_preview.recipe_id = ""
		_preview.recipe_data = {}
		_cost_label.text = "揀材料開始"
		_clear_nutrients()
		_save_button.disabled = true
		return
	var recipe := MealData.build_custom_recipe("preview", recipe_name, _selected, _form, [], _method)
	_preview.recipe_id = ""
	_preview.recipe_data = recipe
	var base_cost := 0
	for item_id in _selected:
		base_cost += int(MealData.INGREDIENTS[item_id].price)
	_cost_label.text = "成本 $%d · %d kcal · %s" % [base_cost, int(recipe.kcal), MealData.method_name(_method)]
	_refresh_nutrients(recipe)
	_save_button.disabled = _name_edit.text.strip_edges().is_empty()


func _clear_nutrients() -> void:
	for child in _nutrient_row.get_children():
		_nutrient_row.remove_child(child)
		child.queue_free()


func _refresh_nutrients(recipe: Dictionary) -> void:
	_clear_nutrients()
	var labels := {"body": "體質", "vitc": "維C", "vitd": "維D", "fiber": "纖維", "mood": "心情"}
	var values := {
		"body": int(recipe.protein), "vitc": int(recipe.vitc), "vitd": int(recipe.vitd),
		"fiber": int(recipe.fiber), "mood": int(recipe.mood),
	}
	for key in MealData.STAT_KEYS:
		var label := UIKit.label("%s +%d" % [labels[key], values[key]], 10, MealData.stat_color(key), true)
		_nutrient_row.add_child(label)


func _save() -> void:
	var recipe_name := _name_edit.text.strip_edges()
	if recipe_name.is_empty() or _selected.is_empty():
		_status.text = "要先改名同揀材料"
		return
	var recipe := RecipeBook.create_recipe(recipe_name, _selected, _form, _method)
	if recipe.is_empty():
		_status.text = "儲存失敗，再試一次"
		return
	Sfx.play("perfect")
	saved.emit(str(recipe.id))
	_close()


func _close() -> void:
	Sfx.play("click")
	closed.emit()
