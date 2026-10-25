extends Node

var failures := 0
var checks := 0


func _ready() -> void:
	_test_initial_state()
	_test_prices_and_sales()
	_test_cooking_rules()
	_test_settlement()
	_test_week_and_report()
	_test_determinism()
	_test_repeat_penalty()
	_test_fridge()
	_test_serialization()
	_test_daily_challenge()
	_test_content_data()
	_test_cooking_methods()
	_test_method_games()
	_test_dish_art()
	_test_custom_recipes()
	_test_ephemeral_recipes()
	_test_budget_bonus()
	if failures == 0:
		print("ALL TESTS PASSED (%d checks)" % checks)
		get_tree().quit(0)
	else:
		printerr("%d/%d CHECKS FAILED" % [failures, checks])
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _cook_cheap_day(state: MealGameState) -> void:
	var cheap := ["egg_toast", "tofu_soup", "milk_oats"]
	for slot in range(3):
		check(state.can_cook(slot, cheap[slot]), "cheap dish should be affordable: " + cheap[slot])
		var record := state.cook(slot, cheap[slot], "good")
		check(not record.is_empty(), "cook should record dish")


func _test_initial_state() -> void:
	var state := MealGameState.new(12345)
	check(state.day == 1, "day starts at 1")
	check(state.remaining() == 60, "budget starts at 60")
	check(state.meals.size() == 3, "three meal slots")
	check(state.sale_ids.size() == 2, "two sale ingredients")
	check(state.weather in ["sunny", "cloudy", "rainy"], "weather is valid")
	check(state.fridge_total() == 0, "fridge starts empty")
	for key in MealData.STAT_KEYS:
		check(is_equal_approx(state.stats[key], 60.0), "stat starts at 60: " + key)
	check(state.savings == 0, "savings start at 0")


func _test_prices_and_sales() -> void:
	var state := MealGameState.new(99)
	var recipe := MealData.recipe("tomato_egg")
	var base := 0
	for item in recipe.items:
		base += int(MealData.INGREDIENTS[item].price)
	check(base == 9, "tomato egg base price is 9")
	var price := state.price_of("tomato_egg")
	var has_sale_item := state.on_sale("tomato_egg")
	check(price > 0, "dish has a positive price")
	check(has_sale_item == ("tomato" in state.sale_ids or "egg" in state.sale_ids), "sale flag matches ingredients")


func _test_cooking_rules() -> void:
	var state := MealGameState.new(7)
	var record := state.cook(0, "egg_toast", "good")
	check(not record.is_empty(), "can cook breakfast")
	check(state.meals[0] != null, "meal slot filled")
	check(state.spent == record.cost, "spent equals dish price")
	check(not state.slot_free(0), "slot no longer free")
	check(not state.can_cook(0, "egg_toast"), "cannot cook same slot twice")
	state.spent = 57
	check(not state.can_cook(1, "salmon_rice"), "cannot afford expensive dish with 3 left")
	check(not state.can_cook(1, "egg_toast"), "cannot afford 8 dollar dish with 3 left")
	var rice_price := state.price_of("plain_rice")
	state.spent = state.budget() - 2 * rice_price
	check(state.can_cook(1, "plain_rice"), "can reserve enough for the last meal")
	check(not state.can_cook(1, "egg_toast"), "reserve blocks an expensive meal")
	state.spent = 0
	check(not state.cook(1, "salmon_rice", "good").is_empty(), "expensive dish affordable on full budget")


func _test_settlement() -> void:
	var state := MealGameState.new(2024)
	state.weather = "sunny"
	_cook_cheap_day(state)
	var preview := state.totals_preview()
	var spent_before := state.spent
	var summary := state.settle_day()
	check(summary.spent == spent_before, "summary records spent")
	check(summary.saved == 60 - spent_before, "summary records saved money")
	check(state.savings == summary.saved, "savings increases by leftover")
	check(summary.kcal == int(preview.kcal), "kcal matches preview")
	check(int(summary.fridge_left) == state.fridge_total(), "summary records fridge")
	for key in MealData.STAT_KEYS:
		var delta: float = summary.deltas[key]
		check(delta >= -10.0 and delta <= 6.0, "delta within limits: " + key)
		check(state.stats[key] >= 0.0 and state.stats[key] <= 100.0, "stat clamped: " + key)
	check(state.settle_day() == summary, "settling twice returns same summary")
	check(state.settled, "day is settled")


func _test_week_and_report() -> void:
	var state := MealGameState.new(555)
	for day_index in range(7):
		check(state.day == day_index + 1, "day increments correctly")
		_cook_cheap_day(state)
		state.settle_day()
		if day_index < 6:
			check(state.next_day(), "next day available")
			check(state.remaining() == 60, "budget resets each day")
			check(state.spent == 0, "spending resets each day")
			check(state.meals[0] == null, "meals reset each day")
	check(not state.next_day(), "no day 8")
	var report := state.report()
	check(report.grade in ["S", "A", "B", "C", "D"], "grade is valid")
	check(report.savings > 0, "week ends with savings")
	check(report.favourite != "", "favourite dish recorded")
	check(report.distinct >= 3, "distinct dishes counted")
	check(state.history.size() == 7, "history has seven days")


func _test_determinism() -> void:
	var a := MealGameState.new(4242)
	var b := MealGameState.new(4242)
	check(a.weather == b.weather, "same seed same weather")
	check(a.sale_ids == b.sale_ids, "same seed same sale ingredients")
	check(a.price_of("tomato_egg") == b.price_of("tomato_egg"), "same seed same prices")


func _test_repeat_penalty() -> void:
	var state := MealGameState.new(31)
	check(is_equal_approx(state.repeat_penalty("tomato_egg"), 1.0), "first time no penalty")
	state.cook(0, "tomato_egg", "good")
	check(is_equal_approx(state.repeat_penalty("tomato_egg"), 0.82), "second time 18% mood penalty")
	state.cook(1, "tomato_egg", "good")
	state.cook(2, "tomato_egg", "good")
	check(is_equal_approx(state.repeat_penalty("tomato_egg"), 0.46), "fourth use is heavily penalised")
	state.week_counts["tomato_egg"] = 10
	check(is_equal_approx(state.repeat_penalty("tomato_egg"), 0.4), "penalty floors at 40%")


func _test_fridge() -> void:
	var state := MealGameState.new(777)
	var tomato_price := state.ingredient_price("tomato")
	var egg_price := state.ingredient_price("egg")
	check(state.buy_ingredient("tomato"), "can buy tomato")
	check(state.fridge_count("tomato") == 1, "fridge holds tomato")
	check(state.spent == tomato_price, "fridge purchase costs money")
	check(state.fridge_covered("tomato_egg") == 1, "fridge covers one ingredient")
	check(state.price_of("tomato_egg") == egg_price, "dish price only charges missing ingredient")

	check(state.buy_ingredient("egg"), "can buy egg")
	check(state.price_of("tomato_egg") == 0, "dish with full fridge is free")
	check(not state.on_sale("tomato_egg"), "fully stocked dish is not marked on sale")
	var spent_before := state.spent
	var record := state.cook(0, "tomato_egg", "good")
	check(int(record.cost) == 0, "cooking from fridge costs zero")
	check(state.spent == spent_before, "fridge cooking does not add spending")
	check(state.fridge_total() == 0, "fridge ingredients consumed")
	check(record.has("fridge_used"), "record tracks fridge usage")

	var full := MealGameState.new(778)
	var guard := 0
	while full.buy_ingredient("rice") and guard < 30:
		guard += 1
	check(full.fridge_total() == MealGameState.FRIDGE_CAPACITY, "fridge fills to capacity")
	check(full.fridge_total() <= MealGameState.FRIDGE_CAPACITY, "fridge never exceeds capacity")
	check(not full.can_buy_ingredient("rice"), "cannot buy when fridge full")

	var carry := MealGameState.new(779)
	carry.buy_ingredient("egg")
	carry.buy_ingredient("milk")
	carry.next_day()
	check(carry.fridge_count("egg") == 1, "fridge carries to next day")
	check(carry.fridge_count("milk") == 1, "fridge keeps multiple items")


func _test_serialization() -> void:
	var state := MealGameState.new(9090, "daily", "20261025")
	state.buy_ingredient("egg")
	state.buy_ingredient("tomato")
	state.cook(0, "tomato_egg", "perfect")
	state.settle_day()
	var data := state.to_dict()
	var restored := MealGameState.from_dict(data)
	check(restored.day == state.day, "restore keeps day")
	check(restored.run_seed == state.run_seed, "restore keeps seed")
	check(restored.mode == state.mode, "restore keeps mode")
	check(restored.challenge_date == state.challenge_date, "restore keeps challenge date")
	check(restored.spent == state.spent, "restore keeps spending")
	check(restored.fridge_total() == state.fridge_total(), "restore keeps fridge")
	check(restored.history.size() == state.history.size(), "restore keeps history")
	check(restored.week_count("tomato_egg") == 1, "restore keeps repeat counts")
	check(is_equal_approx(float(restored.stats.body), float(state.stats.body)), "restore keeps stats")
	check(restored.meals[0].recipe_id == "tomato_egg", "restore keeps meals")
	check(restored.next_day(), "restored state can continue")
	check(state.next_day(), "original can continue")
	check(restored.weather == state.weather, "next day weather deterministic after restore")
	check(restored.sale_ids == state.sale_ids, "next day sales deterministic after restore")


func _test_daily_challenge() -> void:
	var date_key := "20261025"
	var seed := MealGameState.daily_seed(date_key)
	check(seed != 0, "daily seed is non-zero")
	check(seed == MealGameState.daily_seed(date_key), "daily seed is stable")
	check(MealGameState.pretty_date(date_key) == "2026.10.25", "date is pretty printed")
	var a := MealGameState.new(seed, "daily", date_key)
	var b := MealGameState.new(seed, "daily", date_key)
	check(a.mode == "daily" and b.mode == "daily", "daily mode recorded")
	check(a.challenge_date == date_key, "daily date recorded")
	check(a.weather == b.weather, "daily weather is shared")
	check(a.sale_ids == b.sale_ids, "daily sales are shared")


func _test_content_data() -> void:
	check(MealData.RECIPES.size() >= 26, "at least 26 recipes")
	check(MealData.INGREDIENTS.size() >= 30, "at least 30 ingredients")
	var ids := {}
	for recipe in MealData.RECIPES:
		check(not ids.has(recipe.id), "recipe id unique: " + str(recipe.id))
		ids[recipe.id] = true
		check(not recipe.items.is_empty(), "recipe has ingredients: " + str(recipe.id))
		var total := 0
		for item_id in recipe.items:
			check(MealData.INGREDIENTS.has(item_id), "ingredient exists: " + str(item_id))
			total += int(MealData.INGREDIENTS[item_id].price)
		check(total <= MealGameState.BUDGET, "recipe is affordable within a day: " + str(recipe.id))
		check(int(recipe.kcal) > 0, "recipe has calories: " + str(recipe.id))


func _test_custom_recipes() -> void:
	var custom := MealData.build_custom_recipe("test_custom", "番茄蛋", ["tomato", "egg"], "plate", [])
	check(custom.protein == 7, "custom recipe sums protein")
	check(custom.vitc == 14, "custom recipe sums vitamin C")
	check(custom.mood == 5, "custom recipe adds cooking joy")
	check(custom.colors.size() == 3, "custom recipe has three colours")
	check(MealData.COOK_METHODS.has(str(custom.method)), "custom recipe gets a valid method")
	MealData.register_custom(custom)
	check(not MealData.recipe("test_custom").is_empty(), "custom recipe is registered")
	check(MealData.all_recipes().size() > MealData.RECIPES.size(), "custom recipe appears in picker list")
	var state := MealGameState.new(888)
	check(state.price_of("test_custom") > 0, "custom recipe can be priced")
	check(state.required_count("test_custom") == 2, "custom recipe needs two ingredients")
	MealData.custom_recipes.clear()
	check(MealData.recipe("test_custom").is_empty(), "custom recipe can be removed")


func _test_cooking_methods() -> void:
	check(MealData.COOK_METHOD_ORDER.size() == 6, "six cooking methods")
	var seen := {}
	for method_id in MealData.COOK_METHOD_ORDER:
		var info := MealData.method_info(str(method_id))
		check(not str(info.get("name", "")).is_empty(), "method has a name: " + str(method_id))
		check(not str(info.get("action", "")).is_empty(), "method has a mini-game hint: " + str(method_id))
		check(not str(info.get("vessel", "")).is_empty(), "method has generated art vessel: " + str(method_id))
	for recipe in MealData.RECIPES:
		var method := MealData.method_of(recipe)
		check(MealData.COOK_METHODS.has(method), "recipe has a valid method: " + str(recipe.id))
		seen[method] = true
	check(seen.size() == 6, "built-in recipes cover all six methods")
	var custom := MealData.build_custom_recipe("method_test", "蒸蛋", ["egg"], "bowl", [], "steam")
	check(str(custom.method) == "steam", "custom recipe keeps chosen method")
	check(str(custom.form) == "bowl", "custom recipe keeps chosen form")
	var auto := MealData.build_custom_recipe("auto_method", "雜錦", ["bread", "cheese"], "plate", [])
	check(str(auto.method) == "bake", "method is suggested from ingredients")
	check(CookMethodGame.quality_for_score(0.9) == "perfect", "method score maps to perfect")
	check(CookMethodGame.quality_for_score(0.5) == "good", "method score maps to good")
	check(CookMethodGame.quality_for_score(0.1) == "burnt", "method score maps to burnt")
	MealData.custom_recipes.clear()


func _test_method_games() -> void:
	for method_id in MealData.COOK_METHOD_ORDER:
		var game := CookMethodGame.new()
		game.method_id = str(method_id)
		add_child(game)
		var result := {"quality": ""}
		game.judged.connect(func(quality: String) -> void:
			result.quality = quality
		)
		game.force_result_at(0.5)
		check(str(result.quality) == "perfect", "method mini-game can be completed: " + str(method_id))
		check(not game.running, "method mini-game stops after judging: " + str(method_id))
		game.queue_free()
	var bad := CookMethodGame.new()
	bad.method_id = "pan_fry"
	add_child(bad)
	var bad_result := {"quality": ""}
	bad.judged.connect(func(quality: String) -> void:
		bad_result.quality = quality
	)
	bad.force_result_at(0.0)
	check(str(bad_result.quality) == "burnt", "method mini-game can fail")
	bad.queue_free()


func _test_dish_art() -> void:
	check(DishArt.mapped_recipe_count() >= 19, "pixel-food manifest has mapped recipes")
	var curry := MealData.recipe("curry_chicken")
	var curry_path := DishArt.art_path_for(curry)
	check(curry_path.ends_with("33_curry_dish.png"), "curry maps to curry pixel art")
	check(DishArt.texture_for(curry) != null, "mapped recipe texture loads")
	var rice := MealData.recipe("plain_rice")
	check(DishArt.art_path_for(rice).is_empty(), "unmapped recipe uses procedural fallback")
	var art := DishArt.new()
	art.recipe_id = "curry_chicken"
	add_child(art)
	check(art.uses_pixel_art(), "DishArt shows pixel art when mapped")
	art.recipe_id = "plain_rice"
	check(not art.uses_pixel_art(), "DishArt falls back for unmapped recipe")
	art.queue_free()


func _test_ephemeral_recipes() -> void:
	var state := MealGameState.new(991)
	var recipe := MealData.build_custom_recipe("free_test", "自由蒸蛋", ["egg", "tomato"], "plate", [], "steam")
	state.register_ephemeral(recipe)
	check(not MealData.recipe("free_test").is_empty(), "ephemeral recipe is usable in this run")
	var visible := false
	for item in MealData.visible_recipes():
		if str(item.id) == "free_test":
			visible = true
	check(not visible, "ephemeral recipe is hidden from the normal picker")
	check(state.price_of("free_test") > 0, "ephemeral recipe can be priced")
	check(state.cook(0, "free_test", "perfect").recipe_id == "free_test", "ephemeral recipe can be cooked")
	var restored := MealGameState.from_dict(state.to_dict())
	check(restored.ephemeral_recipes.has("free_test"), "ephemeral recipe is saved with the run")
	check(not MealData.recipe("free_test").is_empty(), "ephemeral recipe is restored for art")
	restored.remove_ephemeral("free_test")
	check(MealData.recipe("free_test").is_empty(), "ephemeral recipe can be discarded")
	MealData.custom_recipes.clear()


func _test_budget_bonus() -> void:
	var state := MealGameState.new(889)
	state.extra_budget = 5
	check(state.budget() == 65, "budget bonus adds five dollars")
	check(state.remaining() == 65, "remaining uses boosted budget")
	state.cook(0, "plain_rice", "good")
	var summary := state.settle_day()
	check(int(summary.budget) == 65, "summary records boosted budget")
	check(int(summary.saved) == 65 - state.spent, "leftover uses boosted budget")
