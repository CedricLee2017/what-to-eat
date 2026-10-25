class_name CookScreen
extends Control

signal finished(quality: String)

var state: MealGameState
var slot := 0
var recipe_id := ""

var _action: Button
var _status_panel: PanelContainer
var _status_label: Label
var _art: DishArt
var _game: CookMethodGame
var _instruction_panel: PanelContainer
var _result_box: VBoxContainer
var _stamp: Label
var _kcal_label: Label
var _gain_labels: Dictionary = {}
var _sheet: PanelContainer
var _method_id := "pan_fry"
var _quality := ""
var _stopped := false
var _done := false


func _ready() -> void:
	modulate.a = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.13, 0.1, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_sheet = PanelContainer.new()
	_sheet.anchor_left = 0.5
	_sheet.anchor_right = 0.5
	_sheet.anchor_top = 0.5
	_sheet.anchor_bottom = 0.5
	_sheet.offset_left = -320.0
	_sheet.offset_right = 320.0
	_sheet.offset_top = -440.0
	_sheet.offset_bottom = 440.0
	_sheet.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, 34, 22, Color.TRANSPARENT, 0, 24))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_sheet.add_child(box)

	var recipe := MealData.recipe(recipe_id)
	_method_id = MealData.method_of(recipe)
	var method := MealData.method_info(_method_id)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	var kicker := UIKit.label("%s · 第 %d 日" % [MealData.MEAL_NAMES[slot], state.day], 13, UIKit.CORAL, true)
	title_box.add_child(kicker)
	title_box.add_child(UIKit.label(str(recipe.name), 30, UIKit.INK, true))
	var ingredient_line := MealData.item_names(recipe)
	if state.week_count(recipe_id) > 0:
		ingredient_line += " · 本週食過 %d 次" % state.week_count(recipe_id)
	title_box.add_child(UIKit.label(ingredient_line, 12, UIKit.MUTED, false))

	_status_panel = UIKit.panel(UIKit.SUN_SOFT, 999, 0, Color.TRANSPARENT, 0, 0)
	_status_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 12)
	status_margin.add_theme_constant_override("margin_right", 12)
	status_margin.add_theme_constant_override("margin_top", 6)
	status_margin.add_theme_constant_override("margin_bottom", 6)
	_status_label = UIKit.label("煮緊", 13, Color("#9A6C12"), true)
	status_margin.add_child(_status_label)
	_status_panel.add_child(status_margin)
	header.add_child(_status_panel)

	var method_row := HBoxContainer.new()
	method_row.add_theme_constant_override("separation", 8)
	box.add_child(method_row)
	method_row.add_child(UIKit.pill("%s · %s" % [method.name, method.verb], Color(method.soft), Color(method.color), 13))
	var method_line := UIKit.label(str(method.line), 12, UIKit.MUTED, false)
	method_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	method_row.add_child(method_line)

	var art_panel := UIKit.panel(Color(method.soft), 28, 0, Color.TRANSPARENT, 0, 8)
	art_panel.custom_minimum_size.y = 140
	box.add_child(art_panel)
	_art = DishArt.new()
	_art.recipe_id = recipe_id
	_art.custom_minimum_size = Vector2(112, 112)
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art_panel.add_child(_art)

	_instruction_panel = UIKit.panel(UIKit.SUN_SOFT, 18, 0, Color.TRANSPARENT, 0, 10)
	box.add_child(_instruction_panel)
	var instruction_box := VBoxContainer.new()
	instruction_box.add_theme_constant_override("separation", 1)
	_instruction_panel.add_child(instruction_box)
	var instruction := UIKit.wrapped(str(method.action) + "。", 17, Color("#7A5716"), true)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_box.add_child(instruction)
	var goal := UIKit.label("目標：%s" % str(method.goal), 12, Color("#8A6216"), false)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_box.add_child(goal)

	_game = CookMethodGame.new()
	_game.method_id = _method_id
	_game.colors = recipe.get("colors", [])
	_game.items = recipe.get("items", [])
	_game.custom_minimum_size = Vector2(0, 300)
	_game.judged.connect(_on_judged)
	box.add_child(_game)

	var action_note := UIKit.label("%s · 完美 ×1.15 · 唔錯 ×1.0 · 燶咗 ×0.8" % method.name, 12, Color(0.55, 0.51, 0.45, 0.9), false)
	action_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(action_note)

	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 5)
	_result_box.visible = false
	box.add_child(_result_box)
	_stamp = UIKit.label("完美", 38, UIKit.MINT, true)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_box.add_child(_stamp)

	var gains := HBoxContainer.new()
	gains.alignment = BoxContainer.ALIGNMENT_CENTER
	gains.add_theme_constant_override("separation", 8)
	_result_box.add_child(gains)
	var short_names := {"body": "體質", "vitc": "維C", "vitd": "維D", "fiber": "纖維", "mood": "心情"}
	for key in MealData.STAT_KEYS:
		var gain_label := UIKit.label("%s +0" % short_names[key], 13, MealData.stat_color(key), true)
		gains.add_child(gain_label)
		_gain_labels[key] = gain_label

	_kcal_label = UIKit.label("", 12, UIKit.MUTED, false)
	_kcal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_box.add_child(_kcal_label)

	box.add_child(UIKit.spacer_v())

	_action = UIKit.button("跟住指示煮", UIKit.SAND, UIKit.MUTED, 24, 21, true, Vector2(0, 54))
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action.disabled = true
	_action.visible = false
	_action.pressed.connect(_on_action)
	box.add_child(_action)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _on_action() -> void:
	if _done or not _stopped:
		return
	_finish()


func _on_judged(quality: String) -> void:
	if _stopped:
		return
	_stopped = true
	_quality = quality
	var quality_info := MealData.quality(_quality)

	_status_label.text = quality_info.name
	var status_bg := UIKit.MINT_SOFT
	var status_fg := Color("#3F7D5F")
	if _quality == "good":
		status_bg = UIKit.SUN_SOFT
		status_fg = Color("#9A6C12")
	elif _quality == "burnt":
		status_bg = Color("#F0E0D2")
		status_fg = UIKit.BROWN
	_status_panel.add_theme_stylebox_override("panel", UIKit.box(status_bg, 999, 0, Color.TRANSPARENT, 0, 0))
	_status_label.add_theme_color_override("font_color", status_fg)

	_instruction_panel.visible = false
	_result_box.visible = true
	_stamp.text = "%s · %s" % [MealData.method_name(_method_id), quality_info.name]
	_stamp.add_theme_color_override("font_color", status_fg)
	_art.burnt = _quality == "burnt"
	_fill_gains(quality_info)
	_action.text = "食完！"
	_action.disabled = false
	_action.visible = true
	_paint_action(UIKit.MINT)

	if _quality == "perfect":
		Sfx.play("perfect")
	elif _quality == "burnt":
		Sfx.play("burnt")
	else:
		Sfx.play("good")

	_result_box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_result_box, "modulate:a", 1.0, 0.25)


func _fill_gains(quality: Dictionary) -> void:
	var recipe := MealData.recipe(recipe_id)
	var multiplier: float = quality.nutrition
	var mood_mult: float = quality.mood * state.repeat_penalty(recipe_id)
	var values := {
		"body": round(float(recipe.protein) * multiplier),
		"vitc": round(float(recipe.vitc) * multiplier),
		"vitd": round(float(recipe.vitd) * multiplier),
		"fiber": round(float(recipe.fiber) * multiplier),
		"mood": round(float(recipe.mood) * mood_mult),
	}
	for key in MealData.STAT_KEYS:
		_gain_labels[key].text = "%s +%d" % [_gain_labels[key].text.split(" ")[0], int(values[key])]
	_kcal_label.text = "熱量 %d kcal" % int(recipe.kcal)


func _paint_action(bg: Color) -> void:
	_action.add_theme_stylebox_override("normal", UIKit.box(bg, 24, 0, Color.TRANSPARENT, 0, 18))
	_action.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.05), 24, 0, Color.TRANSPARENT, 0, 18))
	_action.add_theme_stylebox_override("pressed", UIKit.box(bg.darkened(0.06), 24, 0, Color.TRANSPARENT, 0, 18))


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit(_quality)


func _unhandled_input(event: InputEvent) -> void:
	if not _stopped or _done:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_on_action()


func force_result_at(value: float) -> void:
	if _game != null and not _stopped:
		_game.force_result_at(value)
