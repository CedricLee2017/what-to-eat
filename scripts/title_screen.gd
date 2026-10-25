class_name TitleScreen
extends Control

signal start_pressed(mode: String)
signal continue_pressed
signal leaderboard_pressed
signal book_pressed
signal collection_pressed
signal switch_player_pressed


var _has_save := false
var _reward_label: Label


func _ready() -> void:
	modulate.a = 0.0
	var saved := SaveData.peek_run()
	_has_save = not saved.is_empty()
	var today_best := SaveData.today_best()
	var overall := SaveData.overall_best()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var badge_center := CenterContainer.new()
	var badge := UIKit.pill("無職日記 · 七日篇", UIKit.MINT_SOFT, Color("#3F7D5F"), 14)
	badge_center.add_child(badge)
	box.add_child(badge_center)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	title_row.add_child(UIKit.label("今日", 64, UIKit.INK, true))
	title_row.add_child(UIKit.label("食咩好？", 64, UIKit.CORAL, true))
	box.add_child(title_row)

	var subtitle := UIKit.label("無職，但食得好。", 22, UIKit.MUTED, false)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var player_center := CenterContainer.new()
	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 6)
	player_center.add_child(player_row)
	var guest := ProfileData.is_guest()
	var player_pill := UIKit.pill("訪客 · 休閒玩" if guest else "玩家 · %s" % ProfileData.current_name(), UIKit.SKY_SOFT if guest else UIKit.MINT_SOFT, Color("#3F6E92") if guest else Color("#3F7D5F"), 12)
	player_row.add_child(player_pill)
	var title_pill := UIKit.pill(FoodBook.selected_title_name(), UIKit.SUN_SOFT, Color("#8A6216"), 11)
	player_row.add_child(title_pill)
	var switch_button := UIKit.ghost_button("登入" if guest else "切換", UIKit.MUTED, 12, Vector2(52, 30))
	switch_button.pressed.connect(func() -> void:
		Sfx.play("click")
		switch_player_pressed.emit()
	)
	player_row.add_child(switch_button)
	box.add_child(player_center)

	var character := CharacterArt.new()
	character.mood = 0.82
	character.custom_minimum_size = Vector2(290, 330)
	character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(character)

	var quote_center := CenterContainer.new()
	var quote := UIKit.pill("唔使返工，但一日三餐總要諗。", UIKit.SUN_SOFT, Color("#8A6216"), 14)
	quote_center.add_child(quote)
	box.add_child(quote_center)

	box.add_child(UIKit.gap(0, 6))

	if not saved.is_empty():
		var continue_center := CenterContainer.new()
		var mode_text := "每日挑戰" if str(saved.get("mode", "free")) == "daily" else "自由煮飯"
		var continue_button := UIKit.button("繼續上次 · 第 %d 日 · %s" % [int(saved.get("day", 1)), mode_text], UIKit.SUN, UIKit.INK, 22, 18, true, Vector2(360, 48))
		continue_button.pressed.connect(func() -> void:
			Sfx.play("click")
			continue_pressed.emit()
		)
		continue_center.add_child(continue_button)
		box.add_child(continue_center)

	var daily_center := CenterContainer.new()
	var daily_button := UIKit.button("每日挑戰", UIKit.CORAL, Color.WHITE, 26, 24, true, Vector2(300, 58))
	daily_button.pressed.connect(func() -> void:
		Sfx.play("start")
		start_pressed.emit("daily")
	)
	daily_center.add_child(daily_button)
	box.add_child(daily_center)

	var daily_info := "今日 %s UTC" % MealGameState.pretty_date(MealGameState.today_key())
	if not today_best.is_empty():
		daily_info += " · 今日最佳 %s %d" % [str(today_best.get("grade", "")), int(round(float(today_best.get("average", 0.0))))]
	else:
		daily_info += " · 同一個市場，同一個開始"
	var daily_label := UIKit.label(daily_info, 12, UIKit.MUTED, false)
	daily_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(daily_label)

	var free_center := CenterContainer.new()
	var free_button := UIKit.button("自由煮飯", UIKit.MINT_SOFT, Color("#3F7D5F"), 22, 18, true, Vector2(240, 46))
	free_button.pressed.connect(func() -> void:
		Sfx.play("click")
		start_pressed.emit("free")
	)
	free_center.add_child(free_button)
	box.add_child(free_center)

	var rank_center := CenterContainer.new()
	var rank_text := "排行榜"
	if not overall.is_empty():
		rank_text += " · 最高 %s" % str(overall.get("grade", ""))
	var rank_button := UIKit.button(rank_text + " →", UIKit.PAPER, UIKit.INK, 16, 13, true, Vector2(220, 36))
	rank_button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 16, 0, UIKit.LINE, 1, 9))
	rank_button.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 16, 0, UIKit.LINE, 1, 9))
	rank_button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 16, 0, UIKit.LINE, 1, 9))
	rank_button.pressed.connect(func() -> void:
		Sfx.play("click")
		leaderboard_pressed.emit()
	)
	rank_center.add_child(rank_button)
	box.add_child(rank_center)

	var book_center := CenterContainer.new()
	var book_button := UIKit.button("食譜簿 · 創作／朋友", UIKit.MINT_SOFT, Color("#3F7D5F"), 15, 13, true, Vector2(220, 36))
	book_button.add_theme_stylebox_override("normal", UIKit.box(UIKit.MINT_SOFT, 15, 0, Color.TRANSPARENT, 0, 9))
	book_button.add_theme_stylebox_override("hover", UIKit.box(UIKit.MINT_SOFT.darkened(0.04), 15, 0, Color.TRANSPARENT, 0, 9))
	book_button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.MINT_SOFT.darkened(0.08), 15, 0, Color.TRANSPARENT, 0, 9))
	book_button.pressed.connect(func() -> void:
		Sfx.play("click")
		book_pressed.emit()
	)
	book_center.add_child(book_button)
	box.add_child(book_center)

	var collection_center := CenterContainer.new()
	var collection_button := UIKit.button("食物圖鑑 · 成就 · 稱號", UIKit.GRAPE_SOFT, Color("#6B5B95"), 14, 13, true, Vector2(220, 36))
	collection_button.add_theme_stylebox_override("normal", UIKit.box(UIKit.GRAPE_SOFT, 14, 0, Color.TRANSPARENT, 0, 9))
	collection_button.add_theme_stylebox_override("hover", UIKit.box(UIKit.GRAPE_SOFT.darkened(0.04), 14, 0, Color.TRANSPARENT, 0, 9))
	collection_button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.GRAPE_SOFT.darkened(0.08), 14, 0, Color.TRANSPARENT, 0, 9))
	collection_button.pressed.connect(func() -> void:
		Sfx.play("click")
		collection_pressed.emit()
	)
	collection_center.add_child(collection_button)
	box.add_child(collection_center)

	_reward_label = UIKit.label("", 11, Color("#9A6C12"), true)
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.visible = false
	box.add_child(_reward_label)
	_update_reward_label()
	if not RecipeBook.rewards_changed.is_connected(_on_rewards_changed):
		RecipeBook.rewards_changed.connect(_on_rewards_changed)

	var rules := UIKit.label("7 日 · 每日基本 $60 · 一日三餐 · 雪櫃可以跨日補貨", 12, UIKit.MUTED, false)
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rules)

	var footer := UIKit.label("由一個唔使返工嘅人主演", 11, Color(0.55, 0.51, 0.45, 0.75), false)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(footer)

	var sound_button := UIKit.button("音" if not Sfx.muted else "靜", UIKit.PAPER, UIKit.INK, 22, 14, true, Vector2(40, 40))
	sound_button.anchor_left = 1.0
	sound_button.anchor_right = 1.0
	sound_button.anchor_top = 0.0
	sound_button.anchor_bottom = 0.0
	sound_button.offset_left = -68.0
	sound_button.offset_right = -28.0
	sound_button.offset_top = 28.0
	sound_button.offset_bottom = 68.0
	sound_button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 20, 0, UIKit.LINE, 1, 4))
	sound_button.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 20, 0, UIKit.LINE, 1, 4))
	sound_button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 20, 0, UIKit.LINE, 1, 4))
	sound_button.pressed.connect(func() -> void:
		Sfx.toggle_mute()
		sound_button.text = "靜" if Sfx.muted else "音"
		Sfx.play("click")
	)
	add_child(sound_button)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.45)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			Sfx.play("start")
			if _has_save:
				continue_pressed.emit()
			else:
				start_pressed.emit("daily")


func _update_reward_label() -> void:
	if _reward_label == null:
		return
	if RecipeBook.bonus_days > 0:
		_reward_label.text = "人氣預算 +$5 · 剩 %d 日" % RecipeBook.bonus_days
		_reward_label.visible = true
	else:
		_reward_label.visible = false


func _on_rewards_changed(new_likes: int, days: int) -> void:
	if _reward_label == null:
		return
	_reward_label.text = "收到 %d 個新讚好！人氣 +$5 · 剩 %d 日" % [new_likes, days]
	_reward_label.visible = true


func _exit_tree() -> void:
	if RecipeBook.rewards_changed.is_connected(_on_rewards_changed):
		RecipeBook.rewards_changed.disconnect(_on_rewards_changed)
