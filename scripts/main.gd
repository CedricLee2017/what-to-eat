extends Control

## 遊戲流程：標題 → 主畫面 → 雪櫃／揀菜 → 煮飯 → 日結算 → 七日報告。

var state: MealGameState
var _screen: Control
var _overlay: Control
var _dialog: Control
var _stage: Control
var _save_enabled := true
var _is_tour := false
var _pending_ephemeral := ""
var _toast: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.setup()
	theme = UIKit.make_theme()

	_is_tour = false
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--tour"):
			_is_tour = true
	_save_enabled = not _is_tour or "--save" in OS.get_cmdline_user_args()
	FoodBook.set_recording_enabled(_save_enabled)

	var backdrop := Backdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# 720 闊嘅置中舞台：桌面左右留奶油色背景，手機剛好填滿。
	_stage = Control.new()
	_stage.anchor_left = 0.5
	_stage.anchor_right = 0.5
	_stage.anchor_top = 0.0
	_stage.anchor_bottom = 1.0
	_stage.offset_left = -260.0
	_stage.offset_right = 260.0
	_stage.offset_top = 0.0
	_stage.offset_bottom = 0.0
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_stage)

	_show_login()

	if "--tour-continue" in OS.get_cmdline_user_args():
		_run_continue_tour()
	elif "--tour-board" in OS.get_cmdline_user_args():
		_run_board_tour()
	elif "--tour-recipes" in OS.get_cmdline_user_args():
		_run_recipe_tour()
	elif "--tour-rewards" in OS.get_cmdline_user_args():
		_run_rewards_tour()
	elif "--tour-methods" in OS.get_cmdline_user_args():
		_run_method_tour()
	elif "--tour-collection" in OS.get_cmdline_user_args():
		_run_collection_tour()
	elif "--tour-unlock" in OS.get_cmdline_user_args():
		_run_unlock_tour()
	elif "--tour-free" in OS.get_cmdline_user_args():
		_run_free_tour()
	elif _is_tour:
		_run_tour()


func _show_login() -> void:
	_clear_overlay()
	ProfileData.logout()
	var login := LoginScreen.new()
	login.login_pressed.connect(_on_login)
	login.guest_pressed.connect(_on_guest)
	_set_screen(login)


func _on_login(_nickname: String) -> void:
	_show_title()


func _on_guest() -> void:
	_show_title()


func _on_switch_player() -> void:
	_show_login()


func _show_title() -> void:
	_clear_overlay()
	if not ProfileData.session_active:
		ProfileData.set_guest()
	RecipeBook.sync_rewards()
	var title := TitleScreen.new()
	title.start_pressed.connect(_start_game)
	title.continue_pressed.connect(_continue_game)
	title.leaderboard_pressed.connect(_show_leaderboard)
	title.book_pressed.connect(_show_recipe_book)
	title.collection_pressed.connect(_show_collection)
	title.switch_player_pressed.connect(_on_switch_player)
	_set_screen(title)


func _start_game(mode: String) -> void:
	_clear_overlay()
	MealData.purge_ephemeral()
	_pending_ephemeral = ""
	var date_key := MealGameState.today_key() if mode == "daily" else ""
	var seed := MealGameState.daily_seed(date_key) if mode == "daily" else MealGameState.random_seed()
	state = MealGameState.new(seed, mode, date_key)
	state.extra_budget = RecipeBook.bonus_amount()
	if _save_enabled:
		SaveData.save_run(state)
	_show_home()


func _continue_game() -> void:
	var loaded := SaveData.load_run()
	if loaded == null:
		_show_title()
		return
	state = loaded
	state.extra_budget = RecipeBook.bonus_amount()
	_show_home()


func _show_home() -> void:
	_clear_overlay()
	var home := HomeScreen.new()
	home.state = state
	home.meal_pressed.connect(_on_meal_pressed)
	home.finish_day_pressed.connect(_show_summary)
	home.fridge_pressed.connect(_show_fridge)
	home.menu_pressed.connect(_on_menu_pressed)
	_set_screen(home)


func _set_screen(screen: Control) -> void:
	_clear_dialog()
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(screen)


func _add_overlay(overlay: Control) -> void:
	_clear_overlay()
	_overlay = overlay
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(overlay)


func _clear_overlay() -> void:
	_clear_dialog()
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _clear_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


func _on_meal_pressed(slot: int) -> void:
	if not state.slot_free(slot):
		return
	var picker := DishPicker.new()
	picker.state = state
	picker.slot = slot
	picker.dish_chosen.connect(_on_dish_chosen)
	picker.free_cook_pressed.connect(_show_free_cook.bind(slot))
	picker.closed.connect(_clear_overlay)
	_add_overlay(picker)


func _show_free_cook(slot: int) -> void:
	if state == null or not state.slot_free(slot):
		return
	_clear_dialog()
	var sheet := FreeCookSheet.new()
	sheet.state = state
	sheet.slot = slot
	sheet.confirmed.connect(_on_free_cook_confirmed.bind(slot))
	sheet.closed.connect(_clear_dialog)
	_dialog = sheet
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(sheet)


func _on_free_cook_confirmed(recipe_data: Dictionary, slot: int) -> void:
	if state == null or not state.slot_free(slot):
		return
	_clear_dialog()
	var ephemeral_id := "free_%d_%d" % [int(Time.get_ticks_usec()), randi() % 100000]
	var stored := recipe_data.duplicate(true)
	stored["id"] = ephemeral_id
	stored["ephemeral"] = true
	state.register_ephemeral(stored)
	_pending_ephemeral = ephemeral_id
	if not state.can_cook(slot, ephemeral_id):
		state.remove_ephemeral(ephemeral_id)
		_pending_ephemeral = ""
		return
	_on_dish_chosen(ephemeral_id)


func _on_menu_pressed() -> void:
	if state != null and _save_enabled:
		SaveData.save_run(state)
	Sfx.play("click")
	_show_title()


func _on_dish_chosen(recipe_id: String) -> void:
	if state == null:
		return
	if _overlay is DishPicker:
		var picker := _overlay as DishPicker
		var slot := picker.slot
		if not state.can_cook(slot, recipe_id):
			if recipe_id == _pending_ephemeral:
				state.remove_ephemeral(recipe_id)
				_pending_ephemeral = ""
			return
		if state.missing_items(recipe_id).is_empty():
			if recipe_id == _pending_ephemeral:
				_pending_ephemeral = ""
			_clear_overlay()
			_open_cook_screen(slot, recipe_id)
		else:
			_show_buy_confirm(slot, recipe_id)


func _show_buy_confirm(slot: int, recipe_id: String) -> void:
	_clear_dialog()
	var dialog := BuyConfirm.new()
	dialog.state = state
	dialog.slot = slot
	dialog.recipe_id = recipe_id
	dialog.confirmed.connect(func() -> void:
		_clear_dialog()
		_clear_overlay()
		_pending_ephemeral = ""
		_open_cook_screen(slot, recipe_id)
	)
	dialog.cancelled.connect(func() -> void:
		_clear_dialog()
		if not _pending_ephemeral.is_empty() and _pending_ephemeral == recipe_id:
			state.remove_ephemeral(_pending_ephemeral)
			_pending_ephemeral = ""
	)
	_dialog = dialog
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(dialog)


func _open_cook_screen(slot: int, recipe_id: String) -> void:
	var cook := CookScreen.new()
	cook.state = state
	cook.slot = slot
	cook.recipe_id = recipe_id
	cook.finished.connect(_on_cooked.bind(slot, recipe_id))
	_add_overlay(cook)
	Sfx.play("open")


func _on_cooked(quality: String, slot: int, recipe_id: String) -> void:
	if state == null:
		return
	var record := state.cook(slot, recipe_id, quality)
	var unlock_events: Array = []
	if not record.is_empty() and _save_enabled:
		unlock_events = FoodBook.record_cook(recipe_id, quality, state.day)
	_clear_overlay()

	var home := _screen as HomeScreen
	if home != null:
		home.refresh()
		if quality == "perfect":
			home.cheer_character()
	if _save_enabled:
		SaveData.save_run(state)
	_show_toast(unlock_events)


func _show_fridge() -> void:
	if _screen is not HomeScreen:
		return
	if _overlay is FridgeSheet:
		return
	var sheet := FridgeSheet.new()
	sheet.state = state
	sheet.changed.connect(_on_fridge_changed)
	sheet.closed.connect(_on_fridge_closed)
	_add_overlay(sheet)


func _on_fridge_changed() -> void:
	if _screen is HomeScreen:
		_screen.refresh()
	if _save_enabled:
		SaveData.save_run(state)


func _on_fridge_closed() -> void:
	_clear_overlay()
	if _screen is HomeScreen:
		_screen.refresh()
	if _save_enabled:
		SaveData.save_run(state)


func _show_summary() -> void:
	if state == null or _overlay is DaySummary:
		return
	var summary := state.settle_day()
	var screen := DaySummary.new()
	screen.state = state
	screen.summary = summary
	screen.next_pressed.connect(_on_summary_next)
	_add_overlay(screen)


func _on_summary_next() -> void:
	_clear_overlay()
	if state.day < MealGameState.DAYS:
		RecipeBook.tick_bonus_day()
		state.extra_budget = RecipeBook.bonus_amount()
		state.next_day()
		if _save_enabled:
			SaveData.save_run(state)
		_show_home()
	else:
		_finish_run()


func _finish_run() -> void:
	RecipeBook.tick_bonus_day()
	var report := state.report()
	var result := {"rank": 0, "best_today": {}}
	if _save_enabled:
		SaveData.clear_run()
		result = SaveData.add_result(state, report)
	var run_events: Array = FoodBook.record_run_finished(report) if _save_enabled else []
	var screen := EndScreen.new()
	screen.state = state
	screen.report = report
	screen.rank = int(result.get("rank", 0))
	screen.best_today = result.get("best_today", {})
	screen.replay_pressed.connect(_replay)
	screen.title_pressed.connect(_show_title)
	_set_screen(screen)
	_show_toast(run_events)


func _replay() -> void:
	_start_game(state.mode)


func _show_leaderboard() -> void:
	var screen := LeaderboardScreen.new()
	screen.back_pressed.connect(_show_title)
	_set_screen(screen)


func _show_recipe_book() -> void:
	var screen := RecipeBookScreen.new()
	screen.back_pressed.connect(_show_title)
	screen.create_pressed.connect(_open_recipe_studio)
	_set_screen(screen)


func _show_collection() -> void:
	var screen := CollectionScreen.new()
	screen.back_pressed.connect(_show_title)
	_set_screen(screen)


func _show_toast(events: Array) -> void:
	if events.is_empty():
		return
	if _toast != null:
		_toast.queue_free()
		_toast = null
	var toast := UnlockToast.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(toast)
	toast.setup(events)
	_toast = toast


func _open_recipe_studio() -> void:
	var studio := RecipeStudio.new()
	studio.saved.connect(func(_id: String) -> void:
		if _screen is RecipeBookScreen:
			_screen.refresh_mine()
	)
	studio.closed.connect(func() -> void:
		_clear_overlay()
		if _screen is RecipeBookScreen:
			_screen.refresh_mine()
	)
	_add_overlay(studio)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _dialog is BuyConfirm:
			_dialog.cancelled.emit()
			get_viewport().set_input_as_handled()
		elif _dialog is FreeCookSheet:
			_clear_dialog()
			get_viewport().set_input_as_handled()
		elif _overlay is DishPicker or _overlay is FridgeSheet:
			_clear_overlay()
			if _screen is HomeScreen:
				_screen.refresh()
			get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────────────────
# 開發用：自動行一次流程並截圖（Godot -- --tour --out=...）
# ─────────────────────────────────────────────────────────

func _run_continue_tour() -> void:
	await get_tree().create_timer(1.0).timeout
	ProfileData.set_guest()
	_show_title()
	await get_tree().create_timer(0.4).timeout
	var out_dir := "user://tour"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _shot(out_dir, "continue_title")
	_continue_game()
	await get_tree().create_timer(0.8).timeout
	await _shot(out_dir, "continue_home")
	print("CONTINUE TOUR DONE")
	get_tree().quit(0)


func _run_board_tour() -> void:
	await get_tree().create_timer(0.8).timeout
	ProfileData.set_guest()
	var out_dir := "user://tour"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_show_leaderboard()
	await get_tree().create_timer(0.5).timeout
	await _shot(out_dir, "leaderboard_local")
	if _screen is LeaderboardScreen:
		_screen._switch("online")
		await get_tree().create_timer(1.5).timeout
		await _shot(out_dir, "leaderboard_online")
	print("BOARD TOUR DONE")
	get_tree().quit(0)


func _run_rewards_tour() -> void:
	await get_tree().create_timer(2.0).timeout
	ProfileData.set_guest()
	_show_title()
	await get_tree().create_timer(0.4).timeout
	var out_dir := "user://tour"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _shot(out_dir, "rewards_title")
	_start_game("free")
	await get_tree().create_timer(0.7).timeout
	await _shot(out_dir, "rewards_home")
	print("REWARDS TOUR DONE bonus=", RecipeBook.bonus_days)
	get_tree().quit(0)


func _run_recipe_tour() -> void:
	await get_tree().create_timer(0.8).timeout
	ProfileData.set_guest()
	_show_title()
	await get_tree().create_timer(0.4).timeout
	var out_dir := "user://tour"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)

	_show_recipe_book()
	await get_tree().create_timer(0.5).timeout
	await _shot(out_dir, "book_empty")

	_open_recipe_studio()
	await get_tree().create_timer(0.5).timeout
	if _overlay is RecipeStudio:
		var studio := _overlay as RecipeStudio
		studio._name_edit.text = "番茄蛋多士"
		studio._selected = ["tomato", "egg"]
		studio._set_method("bake")
		studio._refresh_item_buttons()
		studio._refresh_preview()
		await get_tree().create_timer(0.3).timeout
		await _shot(out_dir, "studio")
		studio._save()
	await get_tree().create_timer(0.7).timeout
	await _shot(out_dir, "book_created")

	if not RecipeBook.recipes.is_empty():
		var dialog := ShareDialog.new()
		dialog.recipe_id = str(RecipeBook.recipes[0].id)
		dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_screen.add_child(dialog)
		await get_tree().create_timer(0.5).timeout
		await _shot(out_dir, "share")
		dialog.queue_free()

	if Online.enabled and not RecipeBook.recipes.is_empty():
		RecipeBook.publish(str(RecipeBook.recipes[0].id))
		await get_tree().create_timer(1.4).timeout
		if _screen is RecipeBookScreen:
			_screen._switch("friends")
			await get_tree().create_timer(1.5).timeout
			await _shot(out_dir, "friends")

	# 模擬收到讚好，睇預算獎勵
	RecipeBook.bonus_days = 10
	_start_game("free")
	state.extra_budget = 5
	if _screen is HomeScreen:
		_screen.refresh()
	await get_tree().create_timer(0.7).timeout
	await _shot(out_dir, "bonus_home")
	print("RECIPE TOUR DONE")
	get_tree().quit(0)


func _run_method_tour() -> void:
	await get_tree().create_timer(0.8).timeout
	ProfileData.set_guest()
	var out_dir := "user://tour"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)

	_start_game("free")
	await get_tree().create_timer(0.5).timeout
	_on_meal_pressed(0)
	await get_tree().create_timer(0.4).timeout
	_show_free_cook(0)
	await get_tree().create_timer(0.4).timeout
	if _dialog is FreeCookSheet:
		var sheet := _dialog as FreeCookSheet
		sheet._selected = ["tomato", "egg"]
		sheet._method = "pan_fry"
		sheet._refresh_item_buttons()
		sheet._style_methods()
		sheet._refresh()
		await get_tree().create_timer(0.35).timeout
		await _shot(out_dir, "free_create")
		_clear_dialog()
	_clear_overlay()

	var demos := [
		{"method": "pan_fry", "recipe": "egg_toast", "name": "method_pan_fry"},
		{"method": "deep_fry", "recipe": "fried_chicken_leg", "name": "method_deep_fry"},
		{"method": "braise", "recipe": "curry_chicken", "name": "method_braise"},
		{"method": "stew", "recipe": "pumpkin_soup", "name": "method_stew"},
		{"method": "bake", "recipe": "cheese_potato", "name": "method_bake"},
		{"method": "steam", "recipe": "steamed_salmon", "name": "method_steam"},
	]
	for demo in demos:
		_start_game("free")
		await get_tree().create_timer(0.35).timeout
		_open_cook_screen(0, str(demo.recipe))
		await get_tree().create_timer(0.55).timeout
		await _shot(out_dir, str(demo.name))
		if _overlay is CookScreen:
			_overlay.force_result_at(0.5)
		await get_tree().create_timer(0.45).timeout
		await _shot(out_dir, str(demo.name) + "_result")
		if _overlay is CookScreen:
			_overlay._finish()
		await get_tree().create_timer(0.4).timeout
	print("METHOD TOUR DONE")
	get_tree().quit(0)


func _run_unlock_tour() -> void:
	await get_tree().create_timer(0.8).timeout
	ProfileData.set_guest()
	var out_dir := "user://tour"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)

	FoodBook.reset_all()
	FoodBook.set_recording_enabled(true)
	FoodBook.record_cook("tomato_egg", "good", 1)
	FoodBook.record_cook("tomato_egg", "good", 1)
	_start_game("free")
	await get_tree().create_timer(0.5).timeout
	_on_meal_pressed(0)
	await get_tree().create_timer(0.3).timeout
	_on_dish_chosen("tomato_egg")
	await get_tree().create_timer(0.35).timeout
	if _dialog is BuyConfirm:
		_dialog.confirmed.emit()
	await get_tree().create_timer(0.4).timeout
	if _overlay is CookScreen:
		_overlay.force_result_at(0.5)
		await get_tree().create_timer(0.45).timeout
		_overlay._finish()
	await get_tree().create_timer(0.9).timeout
	await _shot(out_dir, "unlock_home")
	print("UNLOCK TOUR count=", FoodBook.count_for_recipe("tomato_egg"), " crowns=", FoodBook.crown_level_for_recipe("tomato_egg"))
	await get_tree().create_timer(3.2).timeout
	_show_collection()
	await get_tree().create_timer(0.5).timeout
	await _shot(out_dir, "unlock_collection")
	get_tree().quit(0)


func _run_collection_tour() -> void:
	await get_tree().create_timer(0.8).timeout
	ProfileData.set_guest()
	var out_dir := "user://tour"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)

	FoodBook.reset_all()
	FoodBook.set_recording_enabled(true)
	var seeded := ["tomato_egg", "curry_chicken", "salmon_rice", "chicken_salad", "egg_toast", "noodle_egg", "cheese_potato", "beef_greens"]
	for recipe_id in seeded:
		for i in range(10):
			FoodBook.record_cook(str(recipe_id), "perfect" if i % 3 == 0 else "good", 1)
	FoodBook.record_cook("fried_chicken_leg", "burnt", 2)
	FoodBook.select_title("home_cook")
	FoodBook.set_recording_enabled(false)

	_show_title()
	await get_tree().create_timer(0.6).timeout
	await _shot(out_dir, "collection_title")

	_show_collection()
	await get_tree().create_timer(0.6).timeout
	await _shot(out_dir, "collection_food")
	if _screen is CollectionScreen:
		_screen._switch("achievement")
		await get_tree().create_timer(0.4).timeout
		await _shot(out_dir, "collection_achievements")
		_screen._switch("title")
		await get_tree().create_timer(0.4).timeout
		await _shot(out_dir, "collection_titles")

	_show_toast([
		{"type": "crown", "title": "新王冠", "text": "番茄炒蛋 · 銀冠"},
		{"type": "achievement", "title": "成就解鎖", "text": "王冠收藏家"},
		{"type": "title", "title": "新稱號", "text": "家常料理人"},
	])
	await get_tree().create_timer(0.5).timeout
	await _shot(out_dir, "collection_toast")
	print("COLLECTION TOUR DONE crowns=", FoodBook.total_crowns(), " title=", FoodBook.selected_title_name())
	get_tree().quit(0)


func _run_free_tour() -> void:
	await get_tree().create_timer(0.8).timeout
	var out_dir := "user://tour"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)

	if not ProfileData.has_profile():
		ProfileData.save_profile("阿明", "1234")
		_show_login()
	await get_tree().create_timer(0.5).timeout
	await _shot(out_dir, "free_login_existing")
	if _screen is LoginScreen:
		var login := _screen as LoginScreen
		login._pin_edit.text = "9999"
		login._submit_existing()
		await get_tree().create_timer(0.2).timeout
		await _shot(out_dir, "free_login_wrong_pin")
		login._pin_edit.text = "1234"
		login._submit_existing()
	await get_tree().create_timer(0.5).timeout
	await _shot(out_dir, "free_login_title")

	_start_game("free")
	await get_tree().create_timer(0.5).timeout
	_on_meal_pressed(0)
	await get_tree().create_timer(0.4).timeout
	_show_free_cook(0)
	await get_tree().create_timer(0.35).timeout
	if _dialog is FreeCookSheet:
		var sheet := _dialog as FreeCookSheet
		sheet._selected = ["egg", "tomato"]
		sheet._select_method("steam")
		sheet._refresh_item_buttons()
		sheet._refresh()
		await get_tree().create_timer(0.3).timeout
		await _shot(out_dir, "free_sheet_steam")
		sheet._confirm_cook()
	await get_tree().create_timer(0.4).timeout
	if _dialog is BuyConfirm:
		await _shot(out_dir, "free_buy_confirm")
		_dialog.confirmed.emit()
	await get_tree().create_timer(0.45).timeout
	await _shot(out_dir, "free_cook")
	if _overlay is CookScreen:
		_overlay.force_result_at(0.5)
		await get_tree().create_timer(0.45).timeout
		await _shot(out_dir, "free_cook_result")
		_overlay._finish()
	await get_tree().create_timer(0.55).timeout
	await _shot(out_dir, "free_home")
	print("FREE TOUR DONE ephemeral=", state.ephemeral_recipes.size())
	_on_menu_pressed()
	await get_tree().create_timer(0.5).timeout
	await _shot(out_dir, "free_back_to_title")
	print("FREE TOUR BACK TO TITLE=", _screen is TitleScreen)
	get_tree().quit(0)


func _run_tour() -> void:
	await get_tree().create_timer(1.0).timeout
	ProfileData.set_guest()
	var out_dir := "user://tour"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)

	await _shot(out_dir, "00_login")
	_show_title()
	await get_tree().create_timer(0.4).timeout
	await _shot(out_dir, "01_title")
	_start_game("daily")
	await get_tree().create_timer(0.6).timeout
	await _shot(out_dir, "02_home")

	_on_meal_pressed(0)
	await get_tree().create_timer(0.45).timeout
	await _shot(out_dir, "03_picker")

	_on_dish_chosen("tomato_egg")
	await get_tree().create_timer(0.4).timeout
	await _shot(out_dir, "04_buy_confirm")
	if _dialog is BuyConfirm:
		_dialog.confirmed.emit()
	await get_tree().create_timer(0.45).timeout
	await _shot(out_dir, "05_cook")

	if _overlay is CookScreen:
		_overlay.force_result_at(0.5)
		await get_tree().create_timer(0.5).timeout
		await _shot(out_dir, "06_cook_result")
		_overlay._finish()
	await get_tree().create_timer(0.6).timeout

	await _tour_cook(1, "milk_oats", 0.2)
	await _tour_cook(2, "chicken_salad", 0.5)
	_show_summary()
	await get_tree().create_timer(0.7).timeout
	await _shot(out_dir, "07_summary")

	_on_summary_next()
	await get_tree().create_timer(0.7).timeout
	await _shot(out_dir, "08_home_day2")

	# 低預算：睇下「唔夠錢」嘅菜式狀態
	state.spent = 52
	if _screen is HomeScreen:
		_screen.refresh()
	_on_meal_pressed(0)
	await get_tree().create_timer(0.5).timeout
	await _shot(out_dir, "09_picker_low_budget")
	_clear_overlay()
	state.spent = 0
	if _screen is HomeScreen:
		_screen.refresh()

	# 雪櫃：買入幾樣特價食材
	_show_fridge()
	await get_tree().create_timer(0.4).timeout
	if _overlay is FridgeSheet:
		for item_id in state.sale_ids:
			_overlay._buy(item_id)
	await get_tree().create_timer(0.3).timeout
	await _shot(out_dir, "10_fridge")
	_on_fridge_closed()
	await get_tree().create_timer(0.4).timeout

	# 快速玩完剩餘日子，睇最終報告
	var menus := [
		["milk_oats", "chicken_salad", "pumpkin_soup"],
		["banana_yogurt", "tofu_soup", "salmon_rice"],
		["egg_toast", "chicken_salad", "cheese_potato"],
		["bean_fried_rice", "pumpkin_soup", "salmon_rice"],
		["banana_toast", "beef_greens", "cheese_potato"],
		["banana_yogurt", "orange_chicken_salad", "cheese_potato"],
	]
	var menu_index := 0
	while state.day < 7:
		for slot in range(3):
			state.cook(slot, menus[menu_index][slot], "perfect" if slot == 1 else "good")
		state.settle_day()
		state.next_day()
		menu_index += 1
	for slot in range(3):
		state.cook(slot, menus[menu_index][slot], "perfect" if slot != 1 else "good")
	state.settle_day()
	_finish_run()
	await get_tree().create_timer(0.8).timeout
	await _shot(out_dir, "11_end")

	print("TOUR DONE: " + out_dir)
	get_tree().quit(0)


func _tour_cook(slot: int, recipe_id: String, stop_value: float) -> void:
	_open_cook_screen(slot, recipe_id)
	await get_tree().create_timer(0.35).timeout
	if _overlay is CookScreen:
		_overlay.force_result_at(stop_value)
		await get_tree().create_timer(0.4).timeout
		_overlay._finish()
	await get_tree().create_timer(0.55).timeout


func _shot(dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := dir.path_join(file_name + ".png")
	image.save_png(path)
	print("SHOT " + path)
