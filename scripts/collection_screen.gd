class_name CollectionScreen
extends Control

## 食物圖鑑、成就、稱號。資料由 FoodBook autoload 提供。

signal back_pressed

var _mode := "food"
var _filter := "all"
var _content: VBoxContainer
var _tabs: Dictionary = {}
var _filter_row: HBoxContainer
var _filter_buttons: Dictionary = {}
var _summary: HBoxContainer


func _ready() -> void:
	modulate.a = 0.0
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(UIKit.pill("食物圖鑑", UIKit.SUN_SOFT, Color("#8A6216"), 12))
	header.add_child(UIKit.spacer_h())
	header.add_child(UIKit.label("王冠 · 成就 · 稱號", 11, UIKit.MUTED, false))

	box.add_child(UIKit.label("你嘅飲食紀錄", 30, UIKit.INK, true))
	var subtitle := UIKit.label("同一款菜食得越多，王冠越高；王冠總數會解鎖新稱號。", 12, UIKit.MUTED, false)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(subtitle)

	_summary = HBoxContainer.new()
	_summary.add_theme_constant_override("separation", 8)
	box.add_child(_summary)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	_tabs["food"] = _tab_button("圖鑑", "food")
	_tabs["achievement"] = _tab_button("成就", "achievement")
	_tabs["title"] = _tab_button("稱號", "title")
	for tab in _tabs.values():
		tabs.add_child(tab)
	tabs.add_child(UIKit.spacer_h())

	_filter_row = HBoxContainer.new()
	_filter_row.add_theme_constant_override("separation", 6)
	box.add_child(_filter_row)
	_filter_buttons["all"] = _filter_button("全部", "all")
	_filter_buttons["cooked"] = _filter_button("已煮", "cooked")
	_filter_buttons["crown"] = _filter_button("有王冠", "crown")
	for button in _filter_buttons.values():
		_filter_row.add_child(button)
	_filter_row.add_child(UIKit.spacer_h())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scroll_theme := Theme.new()
	scroll_theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	scroll_theme.set_stylebox("grabber", "VScrollBar", UIKit.box(UIKit.LINE, 3))
	scroll.theme = scroll_theme
	box.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 7)
	scroll.add_child(_content)

	var back := UIKit.button("返回", UIKit.PAPER, UIKit.INK, 22, 17, true, Vector2(0, 48))
	back.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 22, 0, UIKit.LINE, 1, 12))
	back.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 22, 0, UIKit.LINE, 1, 12))
	back.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 22, 0, UIKit.LINE, 1, 12))
	back.pressed.connect(func() -> void:
		Sfx.play("click")
		back_pressed.emit()
	)
	box.add_child(back)

	_switch("food")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)


func _tab_button(text: String, mode: String) -> Button:
	var button := UIKit.button(text, UIKit.PAPER, UIKit.MUTED, 17, 15, true, Vector2(96, 38))
	button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 17, 0, UIKit.LINE, 1, 9))
	button.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 17, 0, UIKit.LINE, 1, 9))
	button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 17, 0, UIKit.LINE, 1, 9))
	button.pressed.connect(func() -> void:
		Sfx.play("click")
		_switch(mode)
	)
	return button


func _filter_button(text: String, filter: String) -> Button:
	var button := UIKit.button(text, UIKit.PAPER, UIKit.MUTED, 13, 12, true, Vector2(72, 30))
	button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 15, 0, UIKit.LINE, 1, 5))
	button.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 15, 0, UIKit.LINE, 1, 5))
	button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 15, 0, UIKit.LINE, 1, 5))
	button.pressed.connect(func() -> void:
		Sfx.play("click")
		_filter = filter
		_refresh()
	)
	return button


func _switch(mode: String) -> void:
	_mode = mode
	_style_tabs()
	_filter_row.visible = mode == "food"
	_refresh()


func _style_tabs() -> void:
	for id in _tabs:
		var button: Button = _tabs[id]
		var selected := str(id) == _mode
		var bg := UIKit.CORAL_SOFT if selected else UIKit.PAPER
		var fg := UIKit.CORAL if selected else UIKit.MUTED
		button.add_theme_color_override("font_color", fg)
		button.add_theme_color_override("font_hover_color", fg)
		button.add_theme_color_override("font_pressed_color", fg)
		button.add_theme_stylebox_override("normal", UIKit.box(bg, 17, 0, UIKit.LINE, 1, 9))
		button.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.03), 17, 0, UIKit.LINE, 1, 9))
	for id in _filter_buttons:
		var button: Button = _filter_buttons[id]
		var selected := str(id) == _filter
		var bg := UIKit.MINT_SOFT if selected else UIKit.PAPER
		var fg := Color("#3F7D5F") if selected else UIKit.MUTED
		button.add_theme_color_override("font_color", fg)
		button.add_theme_color_override("font_hover_color", fg)
		button.add_theme_color_override("font_pressed_color", fg)
		button.add_theme_stylebox_override("normal", UIKit.box(bg, 15, 0, UIKit.LINE, 1, 5))
		button.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.03), 15, 0, UIKit.LINE, 1, 5))


func _refresh() -> void:
	for child in _summary.get_children():
		_summary.remove_child(child)
		child.queue_free()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_style_tabs()
	var metrics := FoodBook.stats()
	_summary.add_child(_mini_panel("內建已發現", "%d / %d" % [int(metrics.builtin_distinct), MealData.RECIPES.size()], UIKit.MINT_SOFT, Color("#3F7D5F")))
	_summary.add_child(_mini_panel("王冠總數", str(int(metrics.crowns)), UIKit.SUN_SOFT, Color("#8A6216")))
	_summary.add_child(_mini_panel("目前稱號", FoodBook.selected_title_name(), UIKit.GRAPE_SOFT, Color("#6B5B95")))
	match _mode:
		"achievement":
			_render_achievements()
		"title":
			_render_titles()
		_:
			_render_food()


func _mini_panel(label_text: String, value: String, bg: Color, fg: Color) -> PanelContainer:
	var panel := UIKit.panel(bg, 18, 0, Color.TRANSPARENT, 0, 9)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var label := UIKit.label(label_text, 10, fg.darkened(0.05), false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var value_label := UIKit.label(value, 20, fg, true)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(value_label)
	return panel


func _render_food() -> void:
	var entries := FoodBook.entries()
	var shown := 0
	for entry in entries:
		var count := int(entry.count)
		if _filter == "cooked" and count <= 0:
			continue
		if _filter == "crown" and int(entry.crowns) <= 0:
			continue
		_content.add_child(_food_row(entry))
		shown += 1
	if shown == 0:
		_content.add_child(_empty_panel("呢個分類暫時未有菜式。煮多幾餐再嚟睇。" if _filter != "all" else "圖鑑空空如也，去煮第一餐啦。"))
	_content.add_child(UIKit.gap(0, 6))


func _food_row(entry: Dictionary) -> Control:
	var recipe: Dictionary = entry.recipe
	var count := int(entry.count)
	var level := int(entry.crowns)
	var key := str(entry.key)
	var panel := UIKit.panel(UIKit.PAPER, 20, 4, Color.TRANSPARENT, 0, 8)
	if count <= 0:
		panel.modulate = Color(1, 1, 1, 0.72)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var art := DishArt.new()
	art.recipe_data = recipe
	art.custom_minimum_size = Vector2(64, 64)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	text.add_child(top)
	var name_label := UIKit.label(str(recipe.get("name", "菜式")), 17, UIKit.INK, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	var method := MealData.method_info(MealData.method_of(recipe))
	top.add_child(UIKit.label(str(method.name), 11, Color(method.color), true))
	var crowns := CrownBadge.new()
	crowns.level = level
	crowns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(crowns)

	var detail := "未煮過 · 煮一次解鎖紀錄"
	if count > 0:
		detail = "食過 %d 次 · %s · 完美 %d · 燶咗 %d" % [count, FoodBook.crown_name(level), int(entry.perfect), int(entry.burnt)]
	text.add_child(UIKit.label(detail, 11, UIKit.MUTED, false))

	var progress_text := "已達最高 %s" % FoodBook.crown_name(level) if level >= 4 else "下一個：%s · 仲差 %d 次" % [FoodBook.crown_name(level + 1), FoodBook.next_crown_threshold(count) - count]
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 6)
	text.add_child(progress)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = FoodBook.crown_progress(count) * 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UIKit.box(UIKit.SAND, 4))
	bar.add_theme_stylebox_override("fill", UIKit.box(FoodBook.crown_color(maxi(1, level + 1)), 4))
	progress.add_child(bar)

	var small := UIKit.label(progress_text, 10, UIKit.MUTED, false)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	small.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_child(small)
	if key.begins_with("free:"):
		var free_pill := UIKit.pill("自由創作", UIKit.CORAL_SOFT, UIKit.CORAL, 9)
		free_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(free_pill)
	return panel


func _render_achievements() -> void:
	var achievements := FoodBook.achievements()
	var unlocked := 0
	for achievement in achievements:
		if bool(achievement.unlocked):
			unlocked += 1
	_content.add_child(_empty_panel("已解鎖 %d / %d 個成就。煮飯、完美火候、收集王冠都會有成就。" % [unlocked, achievements.size()]))
	for achievement in achievements:
		_content.add_child(_achievement_row(achievement))
	_content.add_child(UIKit.gap(0, 6))


func _achievement_row(achievement: Dictionary) -> Control:
	var is_unlocked := bool(achievement.unlocked)
	var panel := UIKit.panel(UIKit.PAPER if is_unlocked else UIKit.CREAM, 18, 0, Color.TRANSPARENT, 0, 9)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	panel.add_child(row)
	var badge := UIKit.panel(UIKit.MINT_SOFT if is_unlocked else UIKit.SAND, 999, 0, Color.TRANSPARENT, 0, 0)
	badge.custom_minimum_size = Vector2(38, 38)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var mark := UIKit.label("✓" if is_unlocked else "…", 18, Color("#3F7D5F") if is_unlocked else UIKit.MUTED, true)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(mark)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UIKit.label(str(achievement.name), 15, UIKit.INK, true))
	text.add_child(UIKit.label(str(achievement.desc), 10, UIKit.MUTED, false))
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, int(achievement.target))
	bar.value = int(achievement.progress)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)
	bar.add_theme_stylebox_override("background", UIKit.box(UIKit.SAND, 4))
	bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.MINT if is_unlocked else UIKit.SUN, 4))
	text.add_child(bar)
	var progress_label := UIKit.label("已解鎖" if is_unlocked else "%d / %d" % [int(achievement.progress), int(achievement.target)], 10, Color("#3F7D5F") if is_unlocked else UIKit.MUTED, true)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.custom_minimum_size.x = 62
	row.add_child(progress_label)
	return panel


func _render_titles() -> void:
	var total := FoodBook.total_crowns()
	var titles := FoodBook.titles()
	_content.add_child(_empty_panel("總王冠 %d 個。王冠係每款菜食到 3 / 10 / 25 / 50 次升級。" % total))
	for title in titles:
		_content.add_child(_title_row(title))
	_content.add_child(UIKit.gap(0, 6))


func _title_row(title: Dictionary) -> Control:
	var selected := bool(title.selected)
	var unlocked := bool(title.unlocked)
	var panel := UIKit.panel(UIKit.SUN_SOFT if selected else UIKit.PAPER, 18, 0, UIKit.SUN if selected else Color.TRANSPARENT, 2 if selected else 0, 9)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	panel.add_child(row)
	var icon := CrownBadge.new()
	var required_crowns := int(title.crowns)
	var icon_level := 0
	if required_crowns >= 40:
		icon_level = 4
	elif required_crowns >= 15:
		icon_level = 3
	elif required_crowns >= 8:
		icon_level = 2
	elif required_crowns > 0:
		icon_level = 1
	icon.level = icon_level
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UIKit.label(str(title.name), 17, UIKit.INK, true))
	text.add_child(UIKit.label(str(title.line), 10, UIKit.MUTED, false))
	var requirement := "起始稱號" if int(title.crowns) == 0 else "需要 %d 個王冠" % int(title.crowns)
	text.add_child(UIKit.label(requirement, 10, Color("#8A6216") if unlocked else UIKit.MUTED, true))
	var button: Button
	if selected:
		button = UIKit.button("使用中", UIKit.SUN, Color("#7A5716"), 15, 12, true, Vector2(72, 34))
		button.disabled = true
	elif unlocked:
		button = UIKit.button("使用", UIKit.MINT, Color.WHITE, 15, 12, true, Vector2(72, 34))
		button.pressed.connect(func() -> void:
			if FoodBook.select_title(str(title.id)):
				Sfx.play("coin")
				_refresh()
		)
	else:
		button = UIKit.button("未解鎖", UIKit.SAND, UIKit.MUTED, 15, 11, true, Vector2(72, 34))
		button.disabled = true
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return panel


func _empty_panel(text: String) -> PanelContainer:
	var panel := UIKit.panel(UIKit.CREAM, 20, 0, Color.TRANSPARENT, 0, 16)
	var label := UIKit.label(text, 12, UIKit.MUTED, false)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
