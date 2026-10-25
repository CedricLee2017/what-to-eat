extends Node

## 存檔 / 本機排行榜測試（會短暫寫入 user://，完結前清除）。

var failures := 0
var checks := 0
var _backup: Dictionary = {}


func _ready() -> void:
	_backup_user_files()
	_cleanup()
	_test_run_roundtrip()
	_test_ranking()
	_test_profile()
	_test_food_book()
	_cleanup()
	_restore_user_files()
	if failures == 0:
		print("SAVE TESTS PASSED (%d checks)" % checks)
		get_tree().quit(0)
	else:
		printerr("%d/%d SAVE CHECKS FAILED" % [failures, checks])
		get_tree().quit(1)


func _backup_user_files() -> void:
	for file_name in ["run.json", "bests.json", "profile.json", "food_book.json"]:
		var path: String = "user://" + str(file_name)
		if FileAccess.file_exists(path):
			_backup[str(file_name)] = FileAccess.get_file_as_string(path)


func _restore_user_files() -> void:
	for file_name in _backup:
		var file := FileAccess.open("user://" + file_name, FileAccess.WRITE)
		if file != null:
			file.store_string(str(_backup[file_name]))
			file.close()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("run.json")
		dir.remove("bests.json")
		dir.remove("profile.json")
		dir.remove("food_book.json")


func _test_run_roundtrip() -> void:
	var state := MealGameState.new(123456, "daily", MealGameState.today_key())
	state.buy_ingredient("tomato")
	state.cook(0, "tomato_egg", "good")
	SaveData.save_run(state)
	var peek := SaveData.peek_run()
	check(not peek.is_empty(), "peek finds saved run")
	check(int(peek.get("day", 0)) == 1, "peek has day")
	check(str(peek.get("mode", "")) == "daily", "peek has mode")
	var loaded := SaveData.load_run()
	check(loaded != null, "load returns state")
	if loaded != null:
		check(loaded.run_seed == state.run_seed, "load keeps seed")
		check(loaded.mode == "daily", "load keeps mode")
		check(loaded.fridge_count("tomato") == 0, "used fridge item is gone")
		check(loaded.meals[0].recipe_id == "tomato_egg", "load keeps meal")
	SaveData.clear_run()
	check(SaveData.load_run() == null, "clear removes run")
	check(SaveData.peek_run().is_empty(), "peek empty after clear")


func _test_ranking() -> void:
	var today := MealGameState.today_key()
	var averages := [64.0, 79.0, 71.0]
	var ranks: Array[int] = []
	for i in range(averages.size()):
		var state := MealGameState.new(100 + i, "daily", today)
		var report := {
			"average": averages[i],
			"grade": "A" if averages[i] >= 72.0 else "B",
			"mode": "daily",
			"savings": 10 + i,
			"favourite": "番茄炒蛋",
			"distinct": 5 + i,
			"perfect": i,
			"burnt": 0,
			"fridge_left": 0,
			"seed": state.run_seed,
		}
		var result := SaveData.add_result(state, report)
		ranks.append(int(result.rank))
	var runs: Array = SaveData.load_bests().get("runs", [])
	check(runs.size() == 3, "three results stored")
	check(float(runs[0].average) == 79.0, "highest average first")
	check(float(runs[1].average) == 71.0, "second highest second")
	check(float(runs[2].average) == 64.0, "lowest average last")
	check(int(ranks[1]) == 1, "best run ranked first")
	var best := SaveData.today_best()
	check(not best.is_empty(), "today best exists")
	check(is_equal_approx(float(best.get("average", 0.0)), 79.0), "today best is highest")
	var overall := SaveData.overall_best()
	check(is_equal_approx(float(overall.get("average", 0.0)), 79.0), "overall best is highest")


func _test_profile() -> void:
	check(not ProfileData.has_profile(), "profile starts empty")
	ProfileData.set_guest()
	check(ProfileData.is_guest(), "guest session works")
	check(ProfileData.current_name() == "訪客", "guest has a display name")
	var profile := ProfileData.save_profile("小明", "1234")
	check(not profile.is_empty(), "profile can be created")
	check(ProfileData.has_profile(), "profile is stored locally")
	check(ProfileData.profile_has_pin(), "profile stores a pin")
	check(ProfileData.verify_pin("1234"), "correct pin is accepted")
	check(not ProfileData.verify_pin("9999"), "wrong pin is rejected")
	check(ProfileData.current_name() == "小明", "profile session uses nickname")
	ProfileData.logout()
	check(ProfileData.is_guest(), "logout falls back to guest")
	var loaded := ProfileData.load_profile()
	check(str(loaded.get("nickname", "")) == "小明", "profile survives logout")
	ProfileData.clear_profile()
	check(not ProfileData.has_profile(), "profile can be cleared")


func _test_food_book() -> void:
	FoodBook.reset_all()
	check(FoodBook.total_crowns() == 0, "food book starts with no crowns")
	check(FoodBook.crown_level(2) == 0, "two meals is not a crown")
	check(FoodBook.crown_level(3) == 1, "three meals is a bronze crown")
	check(FoodBook.crown_level(10) == 2, "ten meals is a silver crown")
	check(FoodBook.crown_level(25) == 3, "twenty-five meals is a gold crown")
	check(FoodBook.crown_level(50) == 4, "fifty meals is a rainbow crown")
	check(FoodBook.next_crown_threshold(3) == 10, "next crown threshold after bronze is silver")

	var events := FoodBook.record_cook("tomato_egg", "good", 1)
	check(not events.is_empty(), "first cook unlocks an achievement")
	check(FoodBook.count_for_recipe("tomato_egg") == 1, "food book counts first cook")
	check(FoodBook.crown_level_for_recipe("tomato_egg") == 0, "one cook has no crown")
	FoodBook.record_cook("tomato_egg", "perfect", 1)
	FoodBook.record_cook("tomato_egg", "perfect", 1)
	check(FoodBook.crown_level_for_recipe("tomato_egg") == 1, "three cooks unlocks bronze crown")
	check(FoodBook.stats().perfect == 2, "food book counts perfect meals")

	for recipe_id in ["curry_chicken", "egg_toast"]:
		for i in range(3):
			FoodBook.record_cook(str(recipe_id), "good", 1)
	check(FoodBook.total_crowns() == 3, "three crowned dishes gives three crown points")
	var street_title := {}
	for title in FoodBook.titles():
		if str(title.id) == "street_eater":
			street_title = title
	check(not street_title.is_empty() and bool(street_title.unlocked), "three crowns unlocks street eater")
	check(FoodBook.select_title("street_eater"), "unlocked title can be selected")
	check(FoodBook.selected_title_name() == "街坊食客", "selected title is stored")
	FoodBook.reload()
	check(FoodBook.count_for_recipe("tomato_egg") == 3, "food book count survives reload")
	check(FoodBook.selected_title_name() == "街坊食客", "selected title survives reload")

	var free_recipe := MealData.build_custom_recipe("free_book_test", "自由蒸蛋", ["egg", "tomato"], "bowl", [], "steam")
	free_recipe["ephemeral"] = true
	MealData.register_custom(free_recipe)
	var before_entries := FoodBook.entries().size()
	FoodBook.record_cook("free_book_test", "good", 1)
	check(FoodBook.stats().custom >= 1, "free creation counts as custom cook")
	check(FoodBook.entries().size() >= before_entries, "food book keeps free creation snapshot")
	MealData.custom_recipes.clear()
	FoodBook.reset_all()
	check(FoodBook.total_crowns() == 0, "food book can be reset for tests")
