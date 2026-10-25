class_name DaySummary
extends Control

signal next_pressed

var state: MealGameState
var summary: Dictionary

var _rows: Array = []


func _ready() -> void:
	modulate.a = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.13, 0.1, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var sheet := PanelContainer.new()
	sheet.anchor_left = 0.5
	sheet.anchor_right = 0.5
	sheet.anchor_top = 0.5
	sheet.anchor_bottom = 0.5
	sheet.offset_left = -320.0
	sheet.offset_right = 320.0
	sheet.offset_top = -425.0
	sheet.offset_bottom = 425.0
	sheet.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, 34, 22, Color.TRANSPARENT, 0, 24))
	add_child(sheet)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	sheet.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(UIKit.pill("DAY %d 完結" % int(summary.day), UIKit.CORAL_SOFT, UIKit.CORAL, 13))
	header.add_child(UIKit.spacer_h())
	var weekday := UIKit.label(MealData.weekday(int(summary.day)), 13, UIKit.MUTED, false)
	weekday.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(weekday)

	var comment := UIKit.wrapped(str(summary.comment), 20, UIKit.INK, true)
	comment.custom_minimum_size.y = 52
	box.add_child(comment)

	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 8)
	box.add_child(money)
	money.add_child(_mini_panel("今日支出", "$%d" % int(summary.spent), UIKit.CORAL_SOFT, UIKit.CORAL))
	money.add_child(_mini_panel("預算", "$%d" % int(summary.get("budget", MealGameState.BUDGET)), UIKit.SAND, UIKit.INK))
	money.add_child(_mini_panel("儲起", "$%d" % int(summary.saved), UIKit.MINT_SOFT, Color("#3F7D5F")))

	var kcal_row := HBoxContainer.new()
	box.add_child(kcal_row)
	var kcal := int(summary.kcal)
	var kcal_note := "啱啱好"
	var kcal_color := UIKit.MINT
	if kcal < 1150:
		kcal_note = "偏少"
		kcal_color = UIKit.CORAL
	elif kcal > 2800:
		kcal_note = "偏多"
		kcal_color = UIKit.CORAL
	var kcal_label := UIKit.label("熱量 %d kcal · %s" % [kcal, kcal_note], 13, kcal_color, true)
	kcal_row.add_child(kcal_label)
	kcal_row.add_child(UIKit.spacer_h())
	var weather_note: String = str(MealData.WEATHERS[str(summary.weather)].name)
	if str(summary.weather) == "sunny":
		weather_note += " · 維D +2"
	elif str(summary.weather) == "rainy":
		weather_note += " · 心情 -3"
	weather_note += " · 雪櫃 %d 件" % int(summary.get("fridge_left", 0))
	var weather_label := UIKit.label(weather_note, 12, UIKit.MUTED, false)
	kcal_row.add_child(weather_label)

	var meals_title := HBoxContainer.new()
	box.add_child(meals_title)
	meals_title.add_child(UIKit.label("今日食單", 14, UIKit.MUTED, true))
	meals_title.add_child(UIKit.spacer_h())

	var meals := HBoxContainer.new()
	meals.add_theme_constant_override("separation", 8)
	box.add_child(meals)
	for i in range(3):
		meals.add_child(_meal_item(i))

	var divider := ColorRect.new()
	divider.color = UIKit.LINE
	divider.custom_minimum_size.y = 1
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	var health_header := HBoxContainer.new()
	box.add_child(health_header)
	health_header.add_child(UIKit.label("身體變化", 17, UIKit.INK, true))
	health_header.add_child(UIKit.spacer_h())
	health_header.add_child(UIKit.label("0 – 100", 11, UIKit.MUTED, false))

	for key in MealData.STAT_KEYS:
		var row := StatRow.new(key, true)
		row.set_values(float(summary.after[key]), float(summary.deltas[key]))
		box.add_child(row)
		_rows.append(row)

	var tip_panel := UIKit.panel(UIKit.MINT_SOFT, 20, 0, Color.TRANSPARENT, 0, 12)
	box.add_child(tip_panel)
	var tip := UIKit.wrapped(_tip_text(), 13, Color("#3F7D5F"), true)
	tip_panel.add_child(tip)

	var button_text := "聽日再算 →" if int(summary.day) < MealGameState.DAYS else "睇成個星期報告 →"
	var next_button := UIKit.button(button_text, UIKit.CORAL, Color.WHITE, 24, 20, true, Vector2(0, 56))
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(func() -> void:
		Sfx.play("click")
		next_pressed.emit()
	)
	box.add_child(next_button)

	Sfx.play("day")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)


func _mini_panel(label_text: String, value: String, bg: Color, fg: Color) -> PanelContainer:
	var panel := UIKit.panel(bg, 18, 0, Color.TRANSPARENT, 0, 10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var label := UIKit.label(label_text, 11, fg.darkened(0.05), false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var value_label := UIKit.label(value, 22, fg, true)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value_label)
	return panel


func _meal_item(index: int) -> Control:
	var record = summary.meals[index]
	var panel := UIKit.panel(UIKit.CREAM, 18, 0, Color.TRANSPARENT, 0, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	if record == null:
		var empty := UIKit.label("冇食", 13, UIKit.MUTED, false)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(empty)
		return panel
	var art := DishArt.new()
	art.recipe_id = str(record.recipe_id)
	art.custom_minimum_size = Vector2(56, 56)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var recipe := MealData.recipe(str(record.recipe_id))
	var name := UIKit.label(str(recipe.name), 13, UIKit.INK, true)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(name)
	var quality := MealData.quality(str(record.quality))
	var q_color := UIKit.MUTED
	if record.quality == "perfect":
		q_color = UIKit.MINT
	elif record.quality == "burnt":
		q_color = UIKit.BROWN
	text_box.add_child(UIKit.label("%s · %s" % [MealData.method_name(MealData.method_of(recipe)), quality.name], 11, q_color, false))
	return panel


func _tip_text() -> String:
	var ratios: Dictionary = summary.ratios
	var worst := "body"
	var worst_ratio := 9.0
	for key in MealData.STAT_KEYS:
		if float(ratios[key]) < worst_ratio:
			worst_ratio = float(ratios[key])
			worst = key
	if int(summary.kcal) < 1150:
		return "聽日貼士：食得太少，加多碗飯或者多士，先夠力。"
	if worst_ratio >= 0.92:
		return "聽日貼士：飲食幾均衡，保持落去就啱。"
	match worst:
		"body":
			return "聽日貼士：加隻蛋、豆腐或者雞胸，補返蛋白質。"
		"vitc":
			return "聽日貼士：番茄、菜心、香蕉都幫到手，加多份蔬果。"
		"vitd":
			return "聽日貼士：三文魚、牛奶、芝士，或者出去曬下太陽。"
		"fiber":
			return "聽日貼士：燕麥、雜豆、南瓜，腸胃會多謝你。"
		_:
			return "聽日貼士：煮得完美，或者食一餐自己最鍾意嘅。"
