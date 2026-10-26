class_name HomeScreen
extends Control

signal meal_pressed(slot: int)
signal finish_day_pressed
signal sound_toggled
signal fridge_pressed
signal menu_pressed

var state: MealGameState

var _day_label: Label
var _weather_art: WeatherArt
var _weather_label: Label
var _remaining_label: Label
var _budget_label: Label
var _spent_label: Label
var _bonus_label: Label
var _budget_bar: ProgressBar
var _sale_label: Label
var _character: CharacterArt
var _speech_label: Label
var _meal_progress: Label
var _stat_rows: Array = []
var _cards: Array = []
var _hint_label: Label
var _finish_button: Button
var _sound_button: Button
var _fridge_button: Button


func _ready() -> void:
	modulate.a = 0.0
	_build()
	refresh()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)


func _build() -> void:
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
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	# ── 頂欄 ─────────────────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var day_chip := _make_chip(UIKit.SUN_SOFT, Color("#9A6C12"))
	_day_label = day_chip.label
	header.add_child(day_chip.panel)

	var weather_chip := UIKit.panel(UIKit.SKY_SOFT, 999, 0, Color.TRANSPARENT, 0, 0)
	var weather_margin := MarginContainer.new()
	weather_margin.add_theme_constant_override("margin_left", 12)
	weather_margin.add_theme_constant_override("margin_right", 12)
	weather_margin.add_theme_constant_override("margin_top", 5)
	weather_margin.add_theme_constant_override("margin_bottom", 5)
	weather_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var weather_row := HBoxContainer.new()
	weather_row.add_theme_constant_override("separation", 6)
	weather_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_art = WeatherArt.new()
	_weather_art.custom_minimum_size = Vector2(26, 26)
	_weather_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_weather_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather_row.add_child(_weather_art)
	_weather_label = UIKit.label("晴天", 13, Color("#3F6E92"), true)
	_weather_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weather_row.add_child(_weather_label)
	weather_margin.add_child(weather_row)
	weather_chip.add_child(weather_margin)
	header.add_child(weather_chip)

	# 手機闊度優先：模式已經喺標題／語音提示，不再佔頂欄位置。
	header.add_child(UIKit.spacer_h())

	var menu_button := UIKit.button("目錄", UIKit.PAPER, UIKit.INK, 14, 13, true, Vector2(58, 36))
	menu_button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 14, 0, UIKit.LINE, 1, 6))
	menu_button.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 14, 0, UIKit.LINE, 1, 6))
	menu_button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 14, 0, UIKit.LINE, 1, 6))
	menu_button.pressed.connect(func() -> void:
		Sfx.play("click")
		menu_pressed.emit()
	)
	header.add_child(menu_button)

	_sound_button = UIKit.button("音", UIKit.PAPER, UIKit.INK, 22, 15, true, Vector2(44, 44))
	_sound_button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 22, 0, UIKit.LINE, 1, 4))
	_sound_button.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 22, 0, UIKit.LINE, 1, 4))
	_sound_button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 22, 0, UIKit.LINE, 1, 4))
	_sound_button.pressed.connect(func() -> void:
		Sfx.toggle_mute()
		Sfx.play("click")
		update_sound_icon()
		sound_toggled.emit()
	)
	header.add_child(_sound_button)

	# ── 預算 ─────────────────────────────────────────
	var budget_panel := UIKit.panel(UIKit.PAPER, 26, 8, Color.TRANSPARENT, 0, 16)
	box.add_child(budget_panel)
	var budget_box := VBoxContainer.new()
	budget_box.add_theme_constant_override("separation", 6)
	budget_panel.add_child(budget_box)

	var budget_row := HBoxContainer.new()
	budget_row.add_theme_constant_override("separation", 10)
	budget_box.add_child(budget_row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", -2)
	budget_row.add_child(left)
	left.add_child(UIKit.label("今日仲有", 12, UIKit.MUTED, false))
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 4)
	left.add_child(amount_row)
	_remaining_label = UIKit.label("$60", 36, UIKit.INK, true)
	_remaining_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	amount_row.add_child(_remaining_label)
	var unit := UIKit.label("蚊", 14, UIKit.MUTED, false)
	unit.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	amount_row.add_child(unit)

	budget_row.add_child(UIKit.spacer_h())

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	budget_row.add_child(right)
	_budget_label = UIKit.label("預算 $60", 14, UIKit.MUTED, false)
	_budget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_budget_label)
	_spent_label = UIKit.label("已用 $0", 13, UIKit.MUTED, false)
	_spent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_spent_label)
	_bonus_label = UIKit.label("", 10, Color("#9A6C12"), true)
	_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bonus_label.visible = false
	right.add_child(_bonus_label)

	_budget_bar = ProgressBar.new()
	_budget_bar.max_value = MealGameState.BUDGET
	_budget_bar.value = MealGameState.BUDGET
	_budget_bar.show_percentage = false
	_budget_bar.custom_minimum_size.y = 10
	_budget_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_budget_bar.add_theme_stylebox_override("background", UIKit.box(UIKit.SAND, 5))
	_budget_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.MINT, 5))
	budget_box.add_child(_budget_bar)

	var sale_row := HBoxContainer.new()
	sale_row.add_theme_constant_override("separation", 8)
	budget_box.add_child(sale_row)
	sale_row.add_child(UIKit.pill("是日特價", UIKit.MINT_SOFT, Color("#3F7D5F"), 11))
	_sale_label = UIKit.wrapped("", 12, UIKit.MUTED, false)
	_sale_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sale_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	sale_row.add_child(_sale_label)

	_fridge_button = UIKit.button("雪櫃 0", UIKit.MINT_SOFT, Color("#3F7D5F"), 14, 13, true, Vector2(98, 32))
	_fridge_button.add_theme_stylebox_override("normal", UIKit.box(UIKit.MINT_SOFT, 14, 0, Color.TRANSPARENT, 0, 7))
	_fridge_button.add_theme_stylebox_override("hover", UIKit.box(UIKit.MINT_SOFT.darkened(0.04), 14, 0, Color.TRANSPARENT, 0, 7))
	_fridge_button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.MINT_SOFT.darkened(0.08), 14, 0, Color.TRANSPARENT, 0, 7))
	_fridge_button.pressed.connect(func() -> void:
		Sfx.play("click")
		fridge_pressed.emit()
	)
	sale_row.add_child(_fridge_button)

	# ── 角色 + 對白 ───────────────────────────────────
	var character_panel := UIKit.panel(UIKit.SUN_SOFT, 30, 0, Color.TRANSPARENT, 0, 12)
	character_panel.custom_minimum_size.y = 250
	character_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(character_panel)

	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", 4)
	character_panel.add_child(character_row)

	_character = CharacterArt.new()
	_character.custom_minimum_size = Vector2(200, 250)
	_character.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character.size_flags_horizontal = Control.SIZE_FILL
	character_row.add_child(_character)

	var talk := VBoxContainer.new()
	talk.add_theme_constant_override("separation", 8)
	talk.alignment = BoxContainer.ALIGNMENT_CENTER
	talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_row.add_child(talk)

	var talk_header := HBoxContainer.new()
	talk_header.add_theme_constant_override("separation", 8)
	talk.add_child(talk_header)
	talk_header.add_child(UIKit.label("無職日記", 12, Color("#8A6216"), true))
	talk_header.add_child(UIKit.spacer_h())
	_meal_progress = UIKit.label("0 / 3 餐", 12, Color("#A97716"), true)
	talk_header.add_child(_meal_progress)

	var bubble := UIKit.panel(UIKit.PAPER, 22, 4, Color.TRANSPARENT, 0, 16)
	bubble.custom_minimum_size.y = 90
	talk.add_child(bubble)
	_speech_label = UIKit.wrapped("無工一身輕。今日，食咩好？", 19, UIKit.INK, false)
	_speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.add_child(_speech_label)

	var goal_panel := UIKit.panel(Color(1, 1, 1, 0.42), 16, 0, Color.TRANSPARENT, 0, 10)
	talk.add_child(goal_panel)
	var goal := UIKit.wrapped("每日目標：蛋白質 40 · 維C 40 · 維D 20 · 纖維 16 · 心情 20", 11, Color("#8A6216"), true)
	goal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_panel.add_child(goal)

	# ── 身體狀況 ──────────────────────────────────────
	var health_panel := UIKit.panel(UIKit.PAPER, 26, 8, Color.TRANSPARENT, 0, 16)
	box.add_child(health_panel)
	var health_box := VBoxContainer.new()
	health_box.add_theme_constant_override("separation", 2)
	health_panel.add_child(health_box)

	var health_header := HBoxContainer.new()
	health_box.add_child(health_header)
	health_header.add_child(UIKit.label("身體狀況", 19, UIKit.INK, true))
	health_header.add_child(UIKit.spacer_h())
	var health_note := UIKit.label("均衡三餐，慢慢變好", 12, UIKit.MUTED, false)
	health_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_header.add_child(health_note)

	for key in MealData.STAT_KEYS:
		var row := StatRow.new(key)
		health_box.add_child(row)
		_stat_rows.append(row)

	# ── 三餐 ─────────────────────────────────────────
	var meals := HBoxContainer.new()
	meals.add_theme_constant_override("separation", 10)
	meals.custom_minimum_size.y = 246
	box.add_child(meals)
	for i in range(3):
		var card := MealCard.new()
		card.slot = i
		card.pressed.connect(_on_card_pressed.bind(i))
		meals.add_child(card)
		_cards.append(card)

	# ── 底部 ─────────────────────────────────────────
	var footer := CenterContainer.new()
	footer.custom_minimum_size.y = 42
	box.add_child(footer)
	_hint_label = UIKit.label("撳餐牌，開始煮飯 · 一日三餐要食齊", 13, UIKit.MUTED, false)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(_hint_label)
	_finish_button = UIKit.button("今日完結 →", UIKit.CORAL, Color.WHITE, 22, 17, true, Vector2(230, 42))
	_finish_button.visible = false
	_finish_button.pressed.connect(func() -> void:
		Sfx.play("click")
		finish_day_pressed.emit()
	)
	footer.add_child(_finish_button)

	update_sound_icon()


func _make_chip(bg: Color, fg: Color) -> Dictionary:
	var panel := UIKit.panel(bg, 999, 0, Color.TRANSPARENT, 0, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UIKit.label("DAY 1 · 星期一", 13, fg, true)
	margin.add_child(label)
	panel.add_child(margin)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return {"panel": panel, "label": label}


func refresh() -> void:
	if state == null:
		return
	_day_label.text = "DAY %d · %s" % [state.day, MealData.weekday(state.day)]
	_weather_art.kind = state.weather
	_weather_label.text = MealData.WEATHERS[state.weather].name
	_remaining_label.text = "$%d" % state.remaining()
	_remaining_label.add_theme_color_override("font_color", UIKit.CORAL if state.remaining() <= 14 else UIKit.INK)
	_budget_label.text = "預算 $%d" % state.budget()
	_spent_label.text = "已用 $%d" % state.spent
	_budget_bar.max_value = state.budget()
	_budget_bar.value = state.remaining()
	_budget_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.CORAL if state.remaining() <= 14 else UIKit.MINT, 5))
	_sale_label.text = state.market_note() + " · 特價 " + "・".join(state.sale_names()) + " -30%"
	_fridge_button.text = "雪櫃 %d" % state.fridge_total()
	var bonus := state.budget() - MealGameState.BUDGET
	if bonus > 0:
		_bonus_label.text = "人氣 +$%d · 剩 %d 日" % [bonus, RecipeBook.bonus_days]
		_bonus_label.visible = true
	elif RecipeBook.bonus_days > 0:
		_bonus_label.text = "人氣 +$5 · 下日生效"
		_bonus_label.visible = true
	else:
		_bonus_label.visible = false

	var eaten := 0
	for meal in state.meals:
		if meal != null:
			eaten += 1
	_meal_progress.text = "%d / 3 餐" % eaten
	_speech_label.text = state.home_speech()

	var average := 0.0
	for key in MealData.STAT_KEYS:
		average += float(state.stats[key])
	average /= float(MealData.STAT_KEYS.size())
	_character.mood = clampf(average / 100.0, 0.05, 1.0)

	for i in range(_stat_rows.size()):
		var key: String = MealData.STAT_KEYS[i]
		_stat_rows[i].set_values(float(state.stats[key]))

	for i in range(3):
		_cards[i].refresh(state.meals[i])

	var all_done := true
	for meal in state.meals:
		if meal == null:
			all_done = false
	_finish_button.visible = all_done
	_hint_label.visible = not all_done


func update_sound_icon() -> void:
	if _sound_button == null:
		return
	_sound_button.text = "靜" if Sfx.muted else "音"


func cheer_character() -> void:
	_character.cheer()


func _on_card_pressed(slot: int) -> void:
	Sfx.play("click")
	meal_pressed.emit(slot)
