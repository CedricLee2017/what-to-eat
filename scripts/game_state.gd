class_name MealGameState
extends RefCounted

## 一局遊戲嘅完整狀態：每日預算、雪櫃、三餐、營養結算、七日報告。
## 唔依賴任何 UI，方便 headless 測試與存檔。

const BUDGET := 60
const DAYS := 7
const FRIDGE_CAPACITY := 12
const SAVE_VERSION := 2

var day := 1
var stats: Dictionary = {}
var savings := 0
var meals: Array = []
var spent := 0
var price_mods: Dictionary = {}
var sale_ids: Array[String] = []
var weather := "sunny"
var settled := false
var history: Array = []
var week_counts: Dictionary = {}
var fridge: Dictionary = {}
var perfect_count := 0
var burnt_count := 0
var last_quality := ""
var last_cooked_slot := -1
var last_day_comment := ""

## 模式與種子：每日挑戰用同一個日期種子，所有人同一市場。
var run_seed := 1
var mode := "free"
var challenge_date := ""
var extra_budget := 0

## 自由創作嘅即時菜式：跟住一局存檔，但唔會加入食譜簿。
var ephemeral_recipes: Dictionary = {}

var _last_summary: Dictionary = {}
var _day_start_stats: Dictionary = {}


func _init(seed_value: int = 0, run_mode: String = "free", date_key: String = "") -> void:
	run_seed = seed_value if seed_value != 0 else random_seed()
	mode = run_mode
	challenge_date = date_key
	for key in MealData.STAT_KEYS:
		stats[key] = 60.0
	_start_day()


func _start_day() -> void:
	spent = 0
	meals = [null, null, null]
	settled = false
	last_quality = ""
	last_cooked_slot = -1
	_last_summary = {}
	_day_start_stats = stats.duplicate()

	# 每日市場由 run_seed + day 決定，唔靠序列 RNG。
	# 好處：存檔／讀檔、每日挑戰重玩，都會得到完全一樣嘅天氣同特價。
	var day_rng := RandomNumberGenerator.new()
	day_rng.seed = int(run_seed) + day * 104729

	var roll := day_rng.randf()
	if roll < 0.45:
		weather = "sunny"
	elif roll < 0.78:
		weather = "cloudy"
	else:
		weather = "rainy"

	sale_ids.clear()
	var pool: Array = MealData.INGREDIENTS.keys()
	while sale_ids.size() < 2:
		var candidate: String = pool[day_rng.randi_range(0, pool.size() - 1)]
		if not sale_ids.has(candidate):
			sale_ids.append(candidate)

	price_mods.clear()
	for item_id in MealData.INGREDIENTS:
		var category := str(MealData.INGREDIENTS[item_id].get("cat", "veg"))
		var swing := day_rng.randf_range(0.92, 1.08)
		var weather_mod := 1.0
		if weather == "sunny" and (category == "veg" or category == "fruit"):
			weather_mod = 0.92
		elif weather == "rainy" and (category == "veg" or category == "fruit"):
			weather_mod = 1.12
		elif weather == "cloudy":
			weather_mod = 1.0
		var sale_mod := 0.7 if sale_ids.has(item_id) else 1.0
		price_mods[item_id] = clampf(swing * weather_mod * sale_mod, 0.5, 1.3)


func budget() -> int:
	return BUDGET + extra_budget


func market_note() -> String:
	match weather:
		"sunny":
			return "晴天 · 蔬果平 8%"
		"rainy":
			return "落雨 · 蔬果貴 12%"
		_:
			return "多雲 · 菜價平穩"


static func random_seed() -> int:
	var value := int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	return abs(value) + 1


static func today_key() -> String:
	# 每日挑戰用 UTC，確保全球玩家同一日同一個 seed／市場。
	var d := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()))
	return "%04d%02d%02d" % [int(d.year), int(d.month), int(d.day)]


static func daily_seed(date_key: String) -> int:
	return abs(date_key.hash()) + 1


static func pretty_date(date_key: String) -> String:
	if date_key.length() == 8:
		return "%s.%s.%s" % [date_key.substr(0, 4), date_key.substr(4, 2), date_key.substr(6, 2)]
	return date_key


func remaining() -> int:
	return maxi(0, budget() - spent)


func ingredient_price(item_id: String) -> int:
	return MealData.ingredient_price(item_id, price_mods)


func fridge_total() -> int:
	var total := 0
	for count in fridge.values():
		total += int(count)
	return total


func fridge_count(item_id: String) -> int:
	return int(fridge.get(item_id, 0))


func required_count(recipe_id: String) -> int:
	return MealData.recipe(recipe_id).get("items", []).size()


func missing_items(recipe_id: String) -> Dictionary:
	var needed := {}
	for item_id in MealData.recipe(recipe_id).get("items", []):
		needed[item_id] = int(needed.get(item_id, 0)) + 1
	var missing := {}
	for item_id in needed:
		var lack := int(needed[item_id]) - fridge_count(item_id)
		if lack > 0:
			missing[item_id] = lack
	return missing


func fridge_covered(recipe_id: String) -> int:
	return required_count(recipe_id) - _missing_count(recipe_id)


func _missing_count(recipe_id: String) -> int:
	var count := 0
	for amount in missing_items(recipe_id).values():
		count += int(amount)
	return count


func price_of(recipe_id: String) -> int:
	var recipe_data := MealData.recipe(recipe_id)
	if recipe_data.is_empty():
		return 999
	var missing := missing_items(recipe_id)
	var total := 0
	for item_id in missing:
		total += ingredient_price(item_id) * int(missing[item_id])
	return total


func full_price_of(recipe_id: String) -> int:
	return MealData.recipe_price(MealData.recipe(recipe_id), price_mods)


func on_sale(recipe_id: String) -> bool:
	for item_id in missing_items(recipe_id):
		if sale_ids.has(item_id):
			return true
	return false


func sale_names() -> Array[String]:
	var names: Array[String] = []
	for item_id in sale_ids:
		names.append(MealData.INGREDIENTS[item_id].name)
	return names


func slot_free(slot: int) -> bool:
	return slot >= 0 and slot < meals.size() and meals[slot] == null


func can_cook(slot: int, recipe_id: String) -> bool:
	if not slot_free(slot):
		return false
	return price_of(recipe_id) + reserve_for_slot(slot) <= remaining()


func reserve_for_slot(slot: int) -> int:
	var unfilled_after := 0
	for i in range(meals.size()):
		if i != slot and meals[i] == null:
			unfilled_after += 1
	return price_of("plain_rice") * unfilled_after


func can_buy_ingredient(item_id: String) -> bool:
	if not MealData.INGREDIENTS.has(item_id):
		return false
	if fridge_total() >= FRIDGE_CAPACITY:
		return false
	return ingredient_price(item_id) <= remaining()


func buy_ingredient(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if fridge_total() + amount > FRIDGE_CAPACITY:
		return false
	var cost := ingredient_price(item_id) * amount
	if cost > remaining():
		return false
	spent += cost
	fridge[item_id] = fridge_count(item_id) + amount
	return true


func week_count(recipe_id: String) -> int:
	return int(week_counts.get(recipe_id, 0))


func register_ephemeral(recipe_data: Dictionary) -> void:
	var recipe_key := str(recipe_data.get("id", ""))
	if recipe_key.is_empty():
		return
	var stored := recipe_data.duplicate(true)
	stored["ephemeral"] = true
	ephemeral_recipes[recipe_key] = stored
	MealData.register_custom(stored)


func remove_ephemeral(recipe_id: String) -> void:
	if not ephemeral_recipes.has(recipe_id):
		return
	ephemeral_recipes.erase(recipe_id)
	for i in range(MealData.custom_recipes.size() - 1, -1, -1):
		if str(MealData.custom_recipes[i].get("id", "")) == recipe_id:
			MealData.custom_recipes.remove_at(i)
			break


func repeat_penalty(recipe_id: String) -> float:
	return maxf(0.4, 1.0 - 0.18 * float(week_count(recipe_id)))


func cook(slot: int, recipe_id: String, quality_id: String) -> Dictionary:
	if not can_cook(slot, recipe_id):
		push_warning("Cannot cook %s in slot %d" % [recipe_id, slot])
		return {}

	var used_from_fridge := {}
	var bought_items := {}
	for item_id in MealData.recipe(recipe_id).get("items", []):
		if fridge_count(item_id) > 0:
			fridge[item_id] = fridge_count(item_id) - 1
			used_from_fridge[item_id] = int(used_from_fridge.get(item_id, 0)) + 1
			if fridge_count(item_id) <= 0:
				fridge.erase(item_id)
		else:
			bought_items[item_id] = int(bought_items.get(item_id, 0)) + 1

	var cost := 0
	for item_id in bought_items:
		cost += ingredient_price(item_id) * int(bought_items[item_id])
	var repeat_index := week_count(recipe_id)
	var record := {
		"recipe_id": recipe_id,
		"quality": quality_id,
		"cost": cost,
		"repeat_index": repeat_index,
		"fridge_used": used_from_fridge,
		"bought": bought_items,
	}
	meals[slot] = record
	spent += cost
	week_counts[recipe_id] = repeat_index + 1
	last_quality = quality_id
	last_cooked_slot = slot
	if quality_id == "perfect":
		perfect_count += 1
	elif quality_id == "burnt":
		burnt_count += 1
	return record


func totals_preview() -> Dictionary:
	var totals := {"body": 0.0, "vitc": 0.0, "vitd": 0.0, "fiber": 0.0, "mood": 0.0}
	var kcal := 0
	var unique := {}
	for meal in meals:
		if meal == null:
			continue
		var recipe_data := MealData.recipe(meal.recipe_id)
		var quality := MealData.quality(meal.quality)
		var multiplier: float = quality.nutrition
		var mood_mult: float = quality.mood * maxf(0.4, 1.0 - 0.18 * float(meal.repeat_index))
		totals.body += float(recipe_data.protein) * multiplier
		totals.vitc += float(recipe_data.vitc) * multiplier
		totals.vitd += float(recipe_data.vitd) * multiplier
		totals.fiber += float(recipe_data.fiber) * multiplier
		totals.mood += float(recipe_data.mood) * mood_mult
		kcal += int(recipe_data.kcal)
		unique[meal.recipe_id] = true
	totals.mood += float(unique.size()) * 2.0
	if weather == "sunny":
		totals.vitd += 2.0
		totals.mood += 2.0
	elif weather == "rainy":
		totals.mood -= 3.0
	if kcal < 1150:
		totals.body *= 0.8
	elif kcal > 2700:
		totals.body *= 0.92
	return {"totals": totals, "kcal": kcal, "unique": unique.size()}


func settle_day() -> Dictionary:
	if settled:
		return _last_summary
	var preview := totals_preview()
	var totals: Dictionary = preview.totals
	var deltas := {}
	var ratios := {}
	var before := stats.duplicate()
	for key in MealData.STAT_KEYS:
		var target: float = MealData.STATS[key].target
		var ratio: float = totals[key] / target
		ratios[key] = ratio
		var delta := clampf(round((ratio - 1.0) * 18.0), -10.0, 6.0)
		deltas[key] = delta
		stats[key] = clampf(stats[key] + delta, 0.0, 100.0)

	var saved := budget() - spent
	savings += saved
	settled = true
	var comment := _day_comment(ratios, int(preview.kcal), deltas)
	last_day_comment = comment

	var summary := {
		"day": day,
		"before": before,
		"after": stats.duplicate(),
		"deltas": deltas,
		"ratios": ratios,
		"totals": totals,
		"kcal": int(preview.kcal),
		"spent": spent,
		"saved": saved,
		"budget": budget(),
		"weather": weather,
		"meals": meals.duplicate(true),
		"comment": comment,
		"fridge_left": fridge_total(),
	}
	_last_summary = summary
	history.append(summary)
	return summary


func next_day() -> bool:
	if day >= DAYS:
		return false
	day += 1
	_start_day()
	return true


func _day_comment(ratios: Dictionary, kcal: int, deltas: Dictionary) -> String:
	var worst_key := "body"
	var worst_ratio := 99.0
	for key in MealData.STAT_KEYS:
		if float(ratios[key]) < worst_ratio:
			worst_ratio = float(ratios[key])
			worst_key = key
	if kcal < 1150:
		return "食得太少，個人輕飄飄。聽日加多碗飯。"
	if kcal > 2800:
		return "食到好飽，坐低都覺得攰。"
	if worst_ratio >= 0.92 and float(deltas.get("mood", 0.0)) >= 0.0:
		return "營養幾平均，身體多謝你。"
	match worst_key:
		"body":
			return "蛋白質唔夠，好似冇乜力。聽日食隻蛋或者雞肉。"
		"vitc":
			return "好耐冇食生果，皮膚都乾乾地。"
		"vitd":
			return "成日留喺屋企，要食魚同曬下太陽。"
		"fiber":
			return "腸胃有啲唔舒服，要多啲菜同雜糧。"
		"mood":
			return "食嘢，最緊要開心。聽日煮返餐好嘅。"
	return "今日過得去，聽日再諗。"


func home_speech() -> String:
	if not meals.has(null):
		return "今日三餐搞掂。補完貨，就撳「今日完結」。"
	if last_cooked_slot >= 0 and meals[last_cooked_slot] != null and not last_quality.is_empty():
		var recipe_data := MealData.recipe(meals[last_cooked_slot].recipe_id)
		if last_quality == "perfect":
			return "%s，煮得啱啱好。正！" % recipe_data.name
		elif last_quality == "burnt":
			return "%s有少少燶，下次早啲停手。" % recipe_data.name
		else:
			return "%s食飽，滿足。" % recipe_data.name
	if remaining() <= 14:
		return "預算剩返 $%d，夜晚食得簡單啲。" % remaining()
	if day == 1 and meals[0] == null and mode == "daily":
		return "每日挑戰開始。今日，食咩好？"
	if day == 1 and meals[0] == null:
		return "無工一身輕。今日，食咩好？"
	return str(MealData.WEATHERS[weather].line)


func report() -> Dictionary:
	var total := 0.0
	var best_key := "body"
	var worst_key := "body"
	var best_value := -1.0
	var worst_value := 101.0
	for key in MealData.STAT_KEYS:
		var value: float = stats[key]
		total += value
		if value > best_value:
			best_value = value
			best_key = key
		if value < worst_value:
			worst_value = value
			worst_key = key
	var average := total / float(MealData.STAT_KEYS.size())
	var grade := "D"
	if average >= 82.0:
		grade = "S"
	elif average >= 72.0:
		grade = "A"
	elif average >= 62.0:
		grade = "B"
	elif average >= 52.0:
		grade = "C"

	var favourite := ""
	var favourite_count := 0
	for recipe_id in week_counts:
		if int(week_counts[recipe_id]) > favourite_count:
			favourite_count = int(week_counts[recipe_id])
			favourite = MealData.recipe(recipe_id).name

	var grade_line := ""
	match grade:
		"S":
			grade_line = "你根本係無職飲食大師。"
		"A":
			grade_line = "身體好，荷包仲有錢。"
		"B":
			grade_line = "正正常常，繼續保持。"
		"C":
			grade_line = "有啲偏食，下個星期改善下。"
		_:
			grade_line = "身體投訴緊，要認真煮飯喇。"

	return {
		"average": average,
		"grade": grade,
		"grade_line": grade_line,
		"best_key": best_key,
		"best": best_value,
		"worst_key": worst_key,
		"worst": worst_value,
		"favourite": favourite,
		"favourite_count": favourite_count,
		"savings": savings,
		"perfect": perfect_count,
		"burnt": burnt_count,
		"distinct": week_counts.size(),
		"fridge_left": fridge_total(),
		"mode": mode,
		"challenge_date": challenge_date,
		"seed": run_seed,
	}


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"run_seed": run_seed,
		"mode": mode,
		"challenge_date": challenge_date,
		"extra_budget": extra_budget,
		"ephemeral_recipes": ephemeral_recipes.duplicate(true),
		"day": day,
		"stats": stats.duplicate(),
		"savings": savings,
		"meals": meals.duplicate(true),
		"spent": spent,
		"price_mods": price_mods.duplicate(),
		"sale_ids": sale_ids.duplicate(),
		"weather": weather,
		"settled": settled,
		"history": history.duplicate(true),
		"week_counts": week_counts.duplicate(),
		"fridge": fridge.duplicate(),
		"perfect_count": perfect_count,
		"burnt_count": burnt_count,
		"last_quality": last_quality,
		"last_cooked_slot": last_cooked_slot,
		"last_day_comment": last_day_comment,
	}


static func from_dict(data: Dictionary) -> MealGameState:
	var state := MealGameState.new(int(data.get("run_seed", 1)), str(data.get("mode", "free")), str(data.get("challenge_date", "")))
	state._restore(data)
	return state


func _restore(data: Dictionary) -> void:
	run_seed = int(data.get("run_seed", run_seed))
	mode = str(data.get("mode", "free"))
	challenge_date = str(data.get("challenge_date", ""))
	extra_budget = int(data.get("extra_budget", 0))
	ephemeral_recipes.clear()
	var saved_ephemeral: Dictionary = data.get("ephemeral_recipes", {})
	for recipe_key in saved_ephemeral:
		if typeof(saved_ephemeral[recipe_key]) == TYPE_DICTIONARY:
			var ephemeral: Dictionary = saved_ephemeral[recipe_key].duplicate(true)
			ephemeral["ephemeral"] = true
			ephemeral_recipes[str(recipe_key)] = ephemeral
			MealData.register_custom(ephemeral)
	day = clampi(int(data.get("day", 1)), 1, DAYS)
	stats.clear()
	var saved_stats: Dictionary = data.get("stats", {})
	for key in MealData.STAT_KEYS:
		stats[key] = float(saved_stats.get(key, 60.0))
	savings = int(data.get("savings", 0))
	meals = data.get("meals", [null, null, null]).duplicate(true)
	while meals.size() < 3:
		meals.append(null)
	spent = int(data.get("spent", 0))
	price_mods.clear()
	var mods: Dictionary = data.get("price_mods", {})
	for item_id in MealData.INGREDIENTS:
		price_mods[item_id] = float(mods.get(item_id, 1.0))
	sale_ids.clear()
	for item_id in data.get("sale_ids", []):
		sale_ids.append(str(item_id))
	weather = str(data.get("weather", "sunny"))
	settled = false
	history.clear()
	for entry in data.get("history", []):
		history.append(entry)
	week_counts.clear()
	var counts: Dictionary = data.get("week_counts", {})
	for recipe_id in counts:
		week_counts[str(recipe_id)] = int(counts[recipe_id])
	fridge.clear()
	var saved_fridge: Dictionary = data.get("fridge", {})
	for item_id in saved_fridge:
		var amount := int(saved_fridge[item_id])
		if amount > 0 and MealData.INGREDIENTS.has(item_id):
			fridge[str(item_id)] = amount
	perfect_count = int(data.get("perfect_count", 0))
	burnt_count = int(data.get("burnt_count", 0))
	last_quality = str(data.get("last_quality", ""))
	last_cooked_slot = int(data.get("last_cooked_slot", -1))
	last_day_comment = str(data.get("last_day_comment", ""))
	_last_summary = {}
	_day_start_stats = stats.duplicate()
