class_name LeaderboardScreen
extends Control

signal back_pressed

var _runs: Array = []
var _content: VBoxContainer
var _tab_local: Button
var _tab_online: Button
var _refresh: Button
var _mode := "local"
var _online_entries: Array = []
var _online_note := ""
var _online_date := ""
var _date_row: HBoxContainer
var _date_label: Label
var _prev_date: Button
var _next_date: Button


func _ready() -> void:
	modulate.a = 0.0
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(UIKit.pill("排行榜", UIKit.SUN_SOFT, Color("#9A6C12"), 13))
	header.add_child(UIKit.spacer_h())
	var note := UIKit.label("匿名 · 每日挑戰" if Online.enabled else "只存喺呢部機", 12, UIKit.MUTED, false)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(note)

	box.add_child(UIKit.label("無職飲食榜", 34, UIKit.INK, true))
	box.add_child(UIKit.label("最高平均健康分 · 同分再比儲蓄 · 線上只計每日挑戰", 12, UIKit.MUTED, false))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	_tab_local = _tab_button("本機", "local")
	tabs.add_child(_tab_local)
	if Online.enabled:
		_tab_online = _tab_button("線上挑戰", "online")
		tabs.add_child(_tab_online)
	tabs.add_child(UIKit.spacer_h())
	_refresh = UIKit.ghost_button("刷新", UIKit.MUTED, 12)
	_refresh.pressed.connect(func() -> void:
		if _mode == "online":
			_load_online()
	)
	tabs.add_child(_refresh)

	_online_date = MealGameState.today_key()
	_date_row = HBoxContainer.new()
	_date_row.add_theme_constant_override("separation", 6)
	_date_row.visible = false
	box.add_child(_date_row)
	_date_row.add_child(UIKit.label("挑戰日期", 11, UIKit.MUTED, false))
	_prev_date = UIKit.ghost_button("←", UIKit.MUTED, 16, Vector2(34, 28))
	_prev_date.pressed.connect(func() -> void:
		_shift_date(-1)
	)
	_date_row.add_child(_prev_date)
	_date_label = UIKit.label("", 12, UIKit.INK, true)
	_date_label.custom_minimum_size.x = 132
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_date_row.add_child(_date_label)
	_next_date = UIKit.ghost_button("→", UIKit.MUTED, 16, Vector2(34, 28))
	_next_date.pressed.connect(func() -> void:
		_shift_date(1)
	)
	_date_row.add_child(_next_date)
	_date_row.add_child(UIKit.spacer_h())
	_date_row.add_child(UIKit.label("UTC · 最近 14 日", 10, UIKit.MUTED, false))

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

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	_runs = SaveData.load_bests().get("runs", [])
	var today := MealGameState.today_key()
	var min_key := _shift_key(today, -13)
	var latest_daily := ""
	for run in _runs:
		if str(run.get("mode", "")) != "daily":
			continue
		var key := str(run.get("date_key", ""))
		if key >= min_key and key <= today and key > latest_daily:
			latest_daily = key
	if not latest_daily.is_empty():
		_online_date = latest_daily
	_switch("local")

	var back := UIKit.button("返回標題", UIKit.PAPER, UIKit.INK, 22, 18, true, Vector2(0, 52))
	back.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 22, 0, UIKit.LINE, 1, 14))
	back.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 22, 0, UIKit.LINE, 1, 14))
	back.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 22, 0, UIKit.LINE, 1, 14))
	back.pressed.connect(func() -> void:
		Sfx.play("click")
		back_pressed.emit()
	)
	box.add_child(back)

	if not Online.top_finished.is_connected(_on_top):
		Online.top_finished.connect(_on_top)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)


func _tab_button(text: String, mode: String) -> Button:
	var button := UIKit.button(text, UIKit.PAPER, UIKit.INK, 18, 13, true, Vector2(96, 36))
	button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 18, 0, UIKit.LINE, 1, 9))
	button.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 18, 0, UIKit.LINE, 1, 9))
	button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 18, 0, UIKit.LINE, 1, 9))
	button.pressed.connect(func() -> void:
		Sfx.play("click")
		_switch(mode)
	)
	return button


func _switch(mode: String) -> void:
	if mode == "online" and not Online.enabled:
		mode = "local"
	_mode = mode
	_style_tab(_tab_local, mode == "local")
	if _tab_online != null:
		_style_tab(_tab_online, mode == "online")
	_refresh.visible = mode == "online" and Online.enabled
	_date_row.visible = mode == "online" and Online.enabled
	if mode == "online":
		_update_date_row()
		_load_online()
	else:
		_clear_content()
		_render_local()


func _style_tab(button: Button, selected: bool) -> void:
	var bg := UIKit.CORAL_SOFT if selected else UIKit.PAPER
	var fg := UIKit.CORAL if selected else UIKit.MUTED
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg)
	button.add_theme_color_override("font_pressed_color", fg)
	button.add_theme_stylebox_override("normal", UIKit.box(bg, 18, 0, UIKit.LINE, 1, 9))
	button.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.03), 18, 0, UIKit.LINE, 1, 9))


func _clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _render_local() -> void:
	if _runs.is_empty():
		_content.add_child(_empty_panel("仲未有本機紀錄。去煮返一星期啦。"))
		return
	for i in range(_runs.size()):
		_content.add_child(_make_local_row(i + 1, _runs[i]))
	_content.add_child(UIKit.gap(0, 10))


func _load_online() -> void:
	_clear_content()
	_content.add_child(_empty_panel("連線到線上排行榜…"))
	if not Online.top_finished.is_connected(_on_top):
		Online.top_finished.connect(_on_top)
	if not Online.fetch_board(_online_date):
		_clear_content()
		_content.add_child(_error_panel("線上排行榜暫時連唔到，本機紀錄仍然保留。"))


func _shift_date(days: int) -> void:
	var today := MealGameState.today_key()
	var next_key := _shift_key(_online_date, days)
	var min_key := _shift_key(today, -13)
	if next_key > today or next_key < min_key:
		return
	_online_date = next_key
	_update_date_row()
	_load_online()


func _update_date_row() -> void:
	_date_label.text = "%s UTC" % MealGameState.pretty_date(_online_date)
	_prev_date.disabled = _online_date <= _shift_key(MealGameState.today_key(), -13)
	_next_date.disabled = _online_date >= MealGameState.today_key()


func _shift_key(date_key: String, days: int) -> String:
	var year := int(date_key.substr(0, 4))
	var month := int(date_key.substr(4, 2))
	var day := int(date_key.substr(6, 2))
	var stamp := Time.get_unix_time_from_datetime_dict({
		"year": year, "month": month, "day": day,
		"hour": 0, "minute": 0, "second": 0,
	})
	var shifted := Time.get_datetime_dict_from_unix_time(int(stamp) + days * 86400)
	return "%04d%02d%02d" % [int(shifted.year), int(shifted.month), int(shifted.day)]


func _on_top(ok: bool, message: String, entries: Array) -> void:
	if _mode != "online" or not is_inside_tree():
		return
	_clear_content()
	if not ok:
		_content.add_child(_error_panel("線上排行榜暫時連唔到。\n" + message))
		return
	_online_entries = entries
	_online_note = "挑戰日期 %s UTC · %s" % [MealGameState.pretty_date(_online_date), message]
	var note := UIKit.label(_online_note, 12, UIKit.MUTED, false)
	note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_content.add_child(note)
	if entries.is_empty():
		_content.add_child(_empty_panel("呢個日期暫時未有人提交。你可以做第一個。"))
		return
	for entry in entries:
		_content.add_child(_make_online_row(int(entry.get("rank", 1)), entry))
	_content.add_child(UIKit.gap(0, 10))


func _empty_panel(text: String) -> PanelContainer:
	var panel := UIKit.panel(UIKit.CREAM, 22, 0, Color.TRANSPARENT, 0, 20)
	var label := UIKit.label(text, 15, UIKit.MUTED, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel.add_child(label)
	return panel


func _error_panel(text: String) -> PanelContainer:
	var panel := UIKit.panel(UIKit.CORAL_SOFT, 22, 0, Color.TRANSPARENT, 0, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var label := UIKit.label(text, 13, UIKit.CORAL, false)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(label)
	var retry := UIKit.button("重試", UIKit.CORAL, Color.WHITE, 18, 12, true, Vector2(100, 34))
	retry.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	retry.pressed.connect(_load_online)
	box.add_child(retry)
	return panel


func _make_local_row(rank: int, run: Dictionary) -> Control:
	var panel := UIKit.panel(UIKit.PAPER, 22, 5, Color.TRANSPARENT, 0, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_rank_label(rank))

	var grade := str(run.get("grade", "D"))
	var style := _grade_style(grade)
	row.add_child(_grade_badge(grade, style))

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	var mode_text := "每日挑戰 · " + MealGameState.pretty_date(str(run.get("date_key", ""))) + " UTC" if str(run.get("mode", "")) == "daily" else "自由煮飯"
	var title := UIKit.label(mode_text, 14, UIKit.INK, true)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	var detail := "儲 $%d · 最愛 %s · %d 種" % [
		int(run.get("savings", 0)),
		str(run.get("favourite", "—")),
		int(run.get("distinct", 0)),
	]
	var detail_label := UIKit.label(detail, 11, UIKit.MUTED, false)
	detail_label.clip_text = true
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(detail_label)

	row.add_child(_average_block(str(run.get("average", 0.0)), style.fg))
	return panel


func _make_online_row(rank: int, entry: Dictionary) -> Control:
	var panel := UIKit.panel(UIKit.PAPER, 22, 5, Color.TRANSPARENT, 0, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_rank_label(rank))

	var grade := str(entry.get("grade", "D"))
	var style := _grade_style(grade)
	row.add_child(_grade_badge(grade, style))

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	var title := UIKit.label("匿名玩家 · 每日挑戰", 14, UIKit.INK, true)
	text.add_child(title)
	var detail := "儲 $%d · 最愛 %s · %d 種" % [
		int(entry.get("savings", 0)),
		str(entry.get("favourite", "—")),
		int(entry.get("distinct", 0)),
	]
	var detail_label := UIKit.label(detail, 11, UIKit.MUTED, false)
	detail_label.clip_text = true
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(detail_label)

	row.add_child(_average_block(str(entry.get("average", 0.0)), style.fg))
	return panel


func _rank_label(rank: int) -> Label:
	var rank_color := UIKit.MUTED
	if rank == 1:
		rank_color = Color("#B5821B")
	elif rank == 2:
		rank_color = Color("#7C8A92")
	elif rank == 3:
		rank_color = Color("#A46B45")
	var label := UIKit.label(str(rank), 26, rank_color, true)
	label.custom_minimum_size.x = 40
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _grade_style(grade: String) -> Dictionary:
	match grade:
		"S":
			return {"bg": UIKit.SUN_SOFT, "fg": Color("#B5821B")}
		"A":
			return {"bg": UIKit.MINT_SOFT, "fg": Color("#3F7D5F")}
		"B":
			return {"bg": UIKit.SKY_SOFT, "fg": Color("#3F6E92")}
		"C":
			return {"bg": UIKit.CORAL_SOFT, "fg": UIKit.CORAL}
		_:
			return {"bg": Color("#F0E0D2"), "fg": UIKit.BROWN}


func _grade_badge(grade: String, style: Dictionary) -> PanelContainer:
	var badge := UIKit.panel(style.bg, 16, 0, Color.TRANSPARENT, 0, 8)
	badge.custom_minimum_size = Vector2(48, 48)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := UIKit.label(grade, 24, style.fg, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(label)
	return badge


func _average_block(average_text: String, color: Color) -> VBoxContainer:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var avg := UIKit.label("%d" % int(round(float(average_text))), 22, color, true)
	avg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(avg)
	var avg_note := UIKit.label("平均", 10, UIKit.MUTED, false)
	avg_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(avg_note)
	return right


func _exit_tree() -> void:
	if Online.top_finished.is_connected(_on_top):
		Online.top_finished.disconnect(_on_top)
