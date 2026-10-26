class_name EndScreen
extends Control

signal replay_pressed
signal title_pressed

var state: MealGameState
var report: Dictionary
var rank := 0
var best_today: Dictionary = {}

var _online_label: Label
var _online_button: Button
var _online_panel: PanelContainer
var _online_submitting := false

var _grade_colors := {
	"S": {"bg": UIKit.SUN_SOFT, "fg": Color("#B5821B")},
	"A": {"bg": UIKit.MINT_SOFT, "fg": Color("#3F7D5F")},
	"B": {"bg": UIKit.SKY_SOFT, "fg": Color("#3F6E92")},
	"C": {"bg": UIKit.CORAL_SOFT, "fg": UIKit.CORAL},
	"D": {"bg": Color("#F0E0D2"), "fg": UIKit.BROWN},
}


func _ready() -> void:
	modulate.a = 0.0
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll_theme := Theme.new()
	scroll_theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	scroll_theme.set_stylebox("grabber", "VScrollBar", UIKit.box(UIKit.LINE, 3))
	scroll.theme = scroll_theme
	margin.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(UIKit.pill("每日挑戰完成" if state.mode == "daily" else "一個星期過去", UIKit.CORAL_SOFT, UIKit.CORAL, 13))
	header.add_child(UIKit.spacer_h())
	var weekday := UIKit.label("星期日晚上", 13, UIKit.MUTED, false)
	weekday.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(weekday)

	var mode_line := "每日挑戰 · " + MealGameState.pretty_date(state.challenge_date) + " UTC" if state.mode == "daily" else "自由煮飯"
	if rank > 0 and not best_today.is_empty() and absf(float(best_today.get("average", -1.0)) - float(report.average)) < 0.05:
		mode_line += " · 今日最佳"
	var meta_label := UIKit.label(mode_line, 12, UIKit.MUTED, false)
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(meta_label)

	var grade: String = str(report.grade)
	var colors: Dictionary = _grade_colors.get(grade, _grade_colors["D"])
	var grade_panel := UIKit.panel(colors.bg, 30, 8, Color.TRANSPARENT, 0, 18)
	box.add_child(grade_panel)
	var grade_row := HBoxContainer.new()
	grade_row.add_theme_constant_override("separation", 22)
	grade_panel.add_child(grade_row)
	var grade_label := UIKit.label(grade, 104, colors.fg, true)
	grade_label.custom_minimum_size.x = 112
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grade_row.add_child(grade_label)

	var grade_text := VBoxContainer.new()
	grade_text.add_theme_constant_override("separation", 2)
	grade_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grade_row.add_child(grade_text)
	grade_text.add_child(UIKit.label("健康評級", 13, colors.fg, true))
	grade_text.add_child(UIKit.label("平均 %d / 100" % int(round(report.average)), 26, UIKit.INK, true))
	grade_text.add_child(UIKit.wrapped(str(report.grade_line), 15, colors.fg.darkened(0.08), false))
	grade_text.add_child(UIKit.label("稱號 · %s · 王冠 %d" % [FoodBook.selected_title_name(), FoodBook.total_crowns()], 12, colors.fg.darkened(0.12), true))
	var rank_note := "本機第 %d 名 · 新紀錄！" % rank if rank == 1 else ("本機排名 #%d" % rank if rank > 1 else "")
	if not rank_note.is_empty():
		grade_text.add_child(UIKit.label(rank_note, 11, colors.fg.darkened(0.12), true))

	var week_row := HBoxContainer.new()
	week_row.alignment = BoxContainer.ALIGNMENT_CENTER
	week_row.add_theme_constant_override("separation", 6)
	box.add_child(week_row)
	for i in range(state.history.size()):
		week_row.add_child(_day_chip(i))

	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", 6)
	box.add_child(character_row)
	var character := CharacterArt.new()
	character.mood = clampf(float(report.average) / 100.0, 0.1, 1.0)
	character.custom_minimum_size = Vector2(160, 220)
	character.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	character_row.add_child(character)
	var bubble := UIKit.panel(UIKit.SUN_SOFT, 24, 0, Color.TRANSPARENT, 0, 16)
	bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_row.add_child(bubble)
	var quote := UIKit.wrapped(_closing_line(grade), 21, Color("#7A5716"), true)
	quote.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.add_child(quote)

	var stats_panel := UIKit.panel(UIKit.PAPER, 26, 8, Color.TRANSPARENT, 0, 16)
	box.add_child(stats_panel)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 2)
	stats_panel.add_child(stats_box)
	var stats_header := HBoxContainer.new()
	stats_box.add_child(stats_header)
	stats_header.add_child(UIKit.label("身體最終狀態", 17, UIKit.INK, true))
	stats_header.add_child(UIKit.spacer_h())
	var best_name: String = MealData.STATS[report.best_key].name
	var worst_name: String = MealData.STATS[report.worst_key].name
	var compare := UIKit.label("最強 %s · 最弱 %s" % [best_name, worst_name], 12, UIKit.MUTED, false)
	compare.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_header.add_child(compare)
	for key in MealData.STAT_KEYS:
		var row := StatRow.new(key)
		row.set_values(float(state.stats[key]))
		stats_box.add_child(row)

	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	box.add_child(info)
	info.add_child(_info_panel("儲起", "$%d" % int(report.savings), UIKit.MINT_SOFT, Color("#3F7D5F")))
	info.add_child(_info_panel("最愛", str(report.favourite), UIKit.SUN_SOFT, Color("#9A6C12")))
	info.add_child(_info_panel("多樣性", "%d 種" % int(report.distinct), UIKit.CORAL_SOFT, UIKit.CORAL))

	if state.mode == "daily" and Online.enabled:
		_online_panel = UIKit.panel(UIKit.CREAM, 14, 0, Color.TRANSPARENT, 0, 8)
		box.add_child(_online_panel)
		var online_row := HBoxContainer.new()
		online_row.add_theme_constant_override("separation", 8)
		_online_panel.add_child(online_row)
		_online_label = UIKit.label("線上：準備提交…", 12, UIKit.MUTED, false)
		_online_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_online_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		online_row.add_child(_online_label)
		_online_button = UIKit.ghost_button("重試提交", UIKit.CORAL, 11)
		_online_button.visible = false
		_online_button.pressed.connect(_submit_online)
		online_row.add_child(_online_button)
		call_deferred("_submit_online")

	var restart := UIKit.button("再玩一次", UIKit.CORAL, Color.WHITE, 26, 22, true, Vector2(0, 58))
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(func() -> void:
		Sfx.play("start")
		replay_pressed.emit()
	)
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	button_row.add_child(restart)
	var back := UIKit.button("返回標題", UIKit.PAPER, UIKit.INK, 24, 16, true, Vector2(130, 58))
	back.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 24, 0, UIKit.LINE, 1, 10))
	back.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 24, 0, UIKit.LINE, 1, 10))
	back.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 24, 0, UIKit.LINE, 1, 10))
	back.pressed.connect(func() -> void:
		Sfx.play("click")
		title_pressed.emit()
	)
	button_row.add_child(back)
	box.add_child(button_row)

	var footer := UIKit.label("完美 %d 餐 · 燶咗 %d 餐 · 雪櫃剩 %d 件" % [int(report.perfect), int(report.burnt), int(report.fridge_left)], 12, UIKit.MUTED, false)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(footer)

	Sfx.play("day")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _submit_online() -> void:
	if _online_label == null or _online_submitting:
		return
	_online_submitting = true
	_online_label.text = "線上：提交中…"
	_online_label.add_theme_color_override("font_color", UIKit.MUTED)
	if _online_panel != null:
		_online_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.CREAM, 14, 0, Color.TRANSPARENT, 0, 8))
	_online_button.visible = false
	if not Online.submit_finished.is_connected(_on_online_submit):
		Online.submit_finished.connect(_on_online_submit)
	if not Online.submit_daily(state, report):
		_online_submitting = false
		_online_label.text = "線上：暫時連唔到，成績已存本機"
		_online_label.add_theme_color_override("font_color", UIKit.CORAL)
		if _online_panel != null:
			_online_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.CORAL_SOFT, 14, 0, Color.TRANSPARENT, 0, 8))
		_online_button.visible = true


func _on_online_submit(ok: bool, message: String, _rank: int) -> void:
	_online_submitting = false
	if _online_label == null:
		return
	_online_label.text = message
	_online_label.add_theme_color_override("font_color", UIKit.MINT if ok else UIKit.CORAL)
	if _online_panel != null:
		_online_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.MINT_SOFT if ok else UIKit.CORAL_SOFT, 14, 0, Color.TRANSPARENT, 0, 8))
	_online_button.visible = not ok


func _exit_tree() -> void:
	if Online.submit_finished.is_connected(_on_online_submit):
		Online.submit_finished.disconnect(_on_online_submit)


func _day_chip(index: int) -> Control:
	var summary: Dictionary = state.history[index]
	var total := 0.0
	for key in MealData.STAT_KEYS:
		total += float(summary.deltas[key])
	var average := total / float(MealData.STAT_KEYS.size())
	var bg := UIKit.SUN_SOFT
	var fg := Color("#9A6C12")
	if average >= 1.2:
		bg = UIKit.MINT_SOFT
		fg = Color("#3F7D5F")
	elif average < -0.4:
		bg = UIKit.CORAL_SOFT
		fg = UIKit.CORAL
	var panel := UIKit.panel(bg, 14, 0, Color.TRANSPARENT, 0, 5)
	panel.custom_minimum_size = Vector2(0, 54)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var day_label := UIKit.label(MealData.WEEKDAYS[index].substr(2, 1), 10, fg, false)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(day_label)
	var delta_label := UIKit.label("%+d" % int(round(average)), 15, fg, true)
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(delta_label)
	return panel


func _info_panel(label_text: String, value: String, bg: Color, fg: Color) -> PanelContainer:
	var panel := UIKit.panel(bg, 18, 0, Color.TRANSPARENT, 0, 10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var label := UIKit.label(label_text, 11, fg, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var value_label := UIKit.label(value, 17, fg, true)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(value_label)
	return panel


func _closing_line(grade: String) -> String:
	match grade:
		"S":
			return "無職，但食得好。你已經係生活大師。"
		"A":
			return "身體唔錯，荷包仲有錢。呢個節奏幾好。"
		"B":
			return "普普通通，至少一日三餐，食得飽。"
		"C":
			return "有啲對唔住自己個身體，下星期煮好啲。"
		_:
			return "下個星期，由一碗飯開始。"
