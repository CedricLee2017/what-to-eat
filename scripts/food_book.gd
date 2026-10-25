extends Node

## 食物圖鑑 / 成就 / 稱號。資料跨局保留，存在 user://food_book.json。
## 每款菜累積食過嘅次數會升級王冠；王冠總數會解鎖新稱號。

const PATH := "user://food_book.json"
const VERSION := 1

const CROWN_THRESHOLDS := [3, 10, 25, 50]
const CROWN_NAMES := ["", "銅冠", "銀冠", "金冠", "彩虹冠"]
const CROWN_COLORS := [
	Color.TRANSPARENT,
	Color("#B56F3F"),
	Color("#8F9AA6"),
	Color("#D9A21B"),
	Color("#8B6BB8"),
]

const TITLES := [
	{"id": "unemployed", "name": "無職新手", "crowns": 0, "line": "由一碗白飯開始。"},
	{"id": "street_eater", "name": "街坊食客", "crowns": 3, "line": "附近邊間好食，你都知道。"},
	{"id": "kitchen_regular", "name": "廚房常客", "crowns": 8, "line": "雪櫃一開，你就知煮咩。"},
	{"id": "home_cook", "name": "家常料理人", "crowns": 15, "line": "三餸一湯，難你唔到。"},
	{"id": "fridge_manager", "name": "雪櫃管理員", "crowns": 25, "line": "雪櫃入面永遠有存貨。"},
	{"id": "food_god", "name": "無職食神", "crowns": 40, "line": "無工一身輕，但食得好。"},
	{"id": "legend", "name": "傳奇飯桶", "crowns": 60, "line": "你已經係傳說。"},
]

const ACHIEVEMENTS := [
	{"id": "first_cook", "name": "初次下廚", "desc": "累計煮 1 餐", "metric": "cooks", "target": 1},
	{"id": "cook_10", "name": "廚房開工", "desc": "累計煮 10 餐", "metric": "cooks", "target": 10},
	{"id": "cook_50", "name": "煮食習慣", "desc": "累計煮 50 餐", "metric": "cooks", "target": 50},
	{"id": "cook_100", "name": "百食不厭", "desc": "累計煮 100 餐", "metric": "cooks", "target": 100},
	{"id": "perfect_1", "name": "火候掌握", "desc": "煮出 1 次完美", "metric": "perfect", "target": 1},
	{"id": "perfect_10", "name": "完美主義", "desc": "煮出 10 次完美", "metric": "perfect", "target": 10},
	{"id": "burnt_1", "name": "焦香風味", "desc": "煮燶 1 次", "metric": "burnt", "target": 1},
	{"id": "distinct_10", "name": "飲食多元", "desc": "食過 10 款不同菜式", "metric": "distinct", "target": 10},
	{"id": "distinct_all", "name": "全餐牌制霸", "desc": "食過全部 32 款內建菜式", "metric": "builtin_distinct", "target": 32},
	{"id": "first_crown", "name": "第一個王冠", "desc": "任何菜式達到銅冠", "metric": "crowned", "target": 1},
	{"id": "crown_5", "name": "王冠收藏家", "desc": "5 款菜式有王冠", "metric": "crowned", "target": 5},
	{"id": "crown_15", "name": "滿桌皇冠", "desc": "15 款菜式有王冠", "metric": "crowned", "target": 15},
	{"id": "custom_1", "name": "自家製", "desc": "煮 1 次自由創作或自創食譜", "metric": "custom", "target": 1},
	{"id": "run_1", "name": "七日完成", "desc": "完成 1 局七日挑戰", "metric": "runs", "target": 1},
]

var counts: Dictionary = {}
var perfect_counts: Dictionary = {}
var burnt_counts: Dictionary = {}
var custom_entries: Dictionary = {}
var unlocked_achievements: Dictionary = {}
var last_days: Dictionary = {}
var selected_title := "unemployed"
var runs_finished := 0
var custom_cooks := 0
var recording_enabled := true


func _ready() -> void:
	_load()


func set_recording_enabled(value: bool) -> void:
	recording_enabled = value


func record_cook(recipe_id: String, quality: String, day: int = -1) -> Array:
	if not recording_enabled:
		return []
	var recipe := MealData.recipe(recipe_id)
	if recipe.is_empty():
		return []
	var key := collection_key(recipe_id, recipe)
	var old_total := total_crowns()
	var old_level := crown_level(int(counts.get(key, 0)))
	counts[key] = int(counts.get(key, 0)) + 1
	if quality == "perfect":
		perfect_counts[key] = int(perfect_counts.get(key, 0)) + 1
	elif quality == "burnt":
		burnt_counts[key] = int(burnt_counts.get(key, 0)) + 1
	if day > 0:
		last_days[key] = day
	if bool(recipe.get("ephemeral", false)) or recipe_id.begins_with("free_"):
		custom_cooks += 1
		custom_entries[key] = _snapshot(recipe, key)
	elif bool(recipe.get("custom", false)):
		custom_cooks += 1
		custom_entries[key] = _snapshot(recipe, key)

	var events: Array = []
	var new_level := crown_level(int(counts[key]))
	if new_level > old_level:
		events.append({
			"type": "crown",
			"title": "新王冠",
			"text": "%s · %s" % [str(recipe.get("name", "菜式")), crown_name(new_level)],
		})
	events.append_array(_unlock_achievements())
	events.append_array(_unlock_titles(old_total, total_crowns()))
	_save()
	return events


func record_run_finished(_report: Dictionary = {}) -> Array:
	if not recording_enabled:
		return []
	runs_finished += 1
	var events := _unlock_achievements()
	_save()
	return events


func collection_key(recipe_id: String, recipe: Dictionary = {}) -> String:
	var data := recipe if not recipe.is_empty() else MealData.recipe(recipe_id)
	if bool(data.get("ephemeral", false)) or recipe_id.begins_with("free_"):
		var items: Array = data.get("items", []).duplicate()
		items.sort()
		var item_text := ""
		for item_id in items:
			if not item_text.is_empty():
				item_text += "+"
			item_text += str(item_id)
		return "free:%s:%s" % [str(data.get("method", "pan_fry")), item_text]
	return recipe_id


func crown_level(count: int) -> int:
	var level := 0
	for i in range(CROWN_THRESHOLDS.size()):
		if count >= int(CROWN_THRESHOLDS[i]):
			level = i + 1
	return level


func crown_name(level: int) -> String:
	return CROWN_NAMES[clampi(level, 0, CROWN_NAMES.size() - 1)]


func crown_color(level: int) -> Color:
	return CROWN_COLORS[clampi(level, 0, CROWN_COLORS.size() - 1)]


func next_crown_threshold(count: int) -> int:
	for threshold in CROWN_THRESHOLDS:
		if count < int(threshold):
			return int(threshold)
	return 0


func crown_progress(count: int) -> float:
	var next := next_crown_threshold(count)
	if next == 0:
		return 1.0
	var previous := 0
	for threshold in CROWN_THRESHOLDS:
		if int(threshold) <= count:
			previous = int(threshold)
		else:
			break
	return clampf(float(count - previous) / float(maxi(1, next - previous)), 0.0, 1.0)


func count_for_recipe(recipe_id: String) -> int:
	var recipe := MealData.recipe(recipe_id)
	if recipe.is_empty():
		return 0
	return int(counts.get(collection_key(recipe_id, recipe), 0))


func crown_level_for_recipe(recipe_id: String) -> int:
	return crown_level(count_for_recipe(recipe_id))


func crown_level_for_key(key: String) -> int:
	return crown_level(int(counts.get(key, 0)))


func total_crowns() -> int:
	return int(stats().get("crowns", 0))


func stats() -> Dictionary:
	var builtin_ids := {}
	for recipe in MealData.RECIPES:
		builtin_ids[str(recipe.id)] = true
	var total_cooks := 0
	var perfect := 0
	var burnt := 0
	var distinct := 0
	var builtin_distinct := 0
	var crowned := 0
	var crowns := 0
	for key in counts:
		var count := int(counts[key])
		if count <= 0:
			continue
		total_cooks += count
		distinct += 1
		if builtin_ids.has(str(key)):
			builtin_distinct += 1
		var level := crown_level(count)
		crowns += level
		if level > 0:
			crowned += 1
	for value in perfect_counts.values():
		perfect += int(value)
	for value in burnt_counts.values():
		burnt += int(value)
	return {
		"cooks": total_cooks,
		"perfect": perfect,
		"burnt": burnt,
		"distinct": distinct,
		"builtin_distinct": builtin_distinct,
		"crowned": crowned,
		"crowns": crowns,
		"custom": custom_cooks,
		"runs": runs_finished,
	}


func entries() -> Array:
	var result: Array = []
	var seen := {}
	for recipe in MealData.RECIPES:
		var key := str(recipe.id)
		result.append(_entry(key, recipe))
		seen[key] = true
	for recipe in RecipeBook.recipes:
		var key := str(recipe.get("id", ""))
		if key.is_empty() or seen.has(key):
			continue
		result.append(_entry(key, recipe))
		seen[key] = true
	for key in custom_entries:
		if seen.has(str(key)):
			continue
		var snapshot = custom_entries[key]
		if typeof(snapshot) == TYPE_DICTIONARY:
			result.append(_entry(str(key), snapshot))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.count) != int(b.count):
			return int(a.count) > int(b.count)
		return str(a.recipe.get("name", "")) < str(b.recipe.get("name", ""))
	)
	return result


func achievements() -> Array:
	var metrics := stats()
	var result: Array = []
	for definition in ACHIEVEMENTS:
		var metric := str(definition.metric)
		var target := int(definition.target)
		var progress := clampi(int(metrics.get(metric, 0)), 0, target)
		result.append({
			"id": str(definition.id),
			"name": str(definition.name),
			"desc": str(definition.desc),
			"progress": progress,
			"target": target,
			"unlocked": unlocked_achievements.has(str(definition.id)),
		})
	return result


func titles() -> Array:
	var crowns := total_crowns()
	var result: Array = []
	for definition in TITLES:
		result.append({
			"id": str(definition.id),
			"name": str(definition.name),
			"line": str(definition.line),
			"crowns": int(definition.crowns),
			"unlocked": crowns >= int(definition.crowns),
			"selected": selected_title == str(definition.id),
		})
	return result


func selected_title_name() -> String:
	for definition in TITLES:
		if str(definition.id) == selected_title:
			return str(definition.name)
	return "無職新手"


func selected_title_line() -> String:
	for definition in TITLES:
		if str(definition.id) == selected_title:
			return str(definition.line)
	return "由一碗白飯開始。"


func select_title(title_id: String) -> bool:
	for definition in TITLES:
		if str(definition.id) != title_id:
			continue
		if total_crowns() < int(definition.crowns):
			return false
		selected_title = title_id
		_save()
		return true
	return false


func reset_all() -> void:
	counts.clear()
	perfect_counts.clear()
	burnt_counts.clear()
	custom_entries.clear()
	unlocked_achievements.clear()
	last_days.clear()
	selected_title = "unemployed"
	runs_finished = 0
	custom_cooks = 0
	_save()


func reload() -> void:
	_load()


func _entry(key: String, recipe: Dictionary) -> Dictionary:
	return {
		"key": key,
		"recipe": recipe,
		"count": int(counts.get(key, 0)),
		"crowns": crown_level(int(counts.get(key, 0))),
		"perfect": int(perfect_counts.get(key, 0)),
		"burnt": int(burnt_counts.get(key, 0)),
		"last_day": int(last_days.get(key, 0)),
	}


func _snapshot(recipe: Dictionary, key: String) -> Dictionary:
	var snapshot := recipe.duplicate(true)
	snapshot["id"] = key
	snapshot["ephemeral"] = false
	snapshot["collection"] = true
	return snapshot


func _unlock_achievements() -> Array:
	var metrics := stats()
	var events: Array = []
	for definition in ACHIEVEMENTS:
		var achievement_id := str(definition.id)
		if unlocked_achievements.has(achievement_id):
			continue
		var value := int(metrics.get(str(definition.metric), 0))
		if value >= int(definition.target):
			unlocked_achievements[achievement_id] = true
			events.append({
				"type": "achievement",
				"title": "成就解鎖",
				"text": str(definition.name),
			})
	return events


func _unlock_titles(old_total: int, new_total: int) -> Array:
	var events: Array = []
	for definition in TITLES:
		var required := int(definition.crowns)
		if required > old_total and required <= new_total:
			events.append({
				"type": "title",
				"title": "新稱號",
				"text": str(definition.name),
			})
	return events


func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"version": VERSION,
		"counts": counts,
		"perfect_counts": perfect_counts,
		"burnt_counts": burnt_counts,
		"custom_entries": custom_entries,
		"unlocked_achievements": unlocked_achievements.keys(),
		"last_days": last_days,
		"selected_title": selected_title,
		"runs_finished": runs_finished,
		"custom_cooks": custom_cooks,
	}))
	file.close()


func _load() -> void:
	counts.clear()
	perfect_counts.clear()
	burnt_counts.clear()
	custom_entries.clear()
	unlocked_achievements.clear()
	last_days.clear()
	selected_title = "unemployed"
	runs_finished = 0
	custom_cooks = 0
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_read_int_dict(parsed.get("counts", {}), counts)
	_read_int_dict(parsed.get("perfect_counts", {}), perfect_counts)
	_read_int_dict(parsed.get("burnt_counts", {}), burnt_counts)
	_read_int_dict(parsed.get("last_days", {}), last_days)
	var saved_custom = parsed.get("custom_entries", {})
	if typeof(saved_custom) == TYPE_DICTIONARY:
		for key in saved_custom:
			if typeof(saved_custom[key]) == TYPE_DICTIONARY:
				custom_entries[str(key)] = saved_custom[key]
	var saved_achievements = parsed.get("unlocked_achievements", [])
	if typeof(saved_achievements) == TYPE_ARRAY:
		for achievement_id in saved_achievements:
			unlocked_achievements[str(achievement_id)] = true
	elif typeof(saved_achievements) == TYPE_DICTIONARY:
		for achievement_id in saved_achievements:
			unlocked_achievements[str(achievement_id)] = true
	selected_title = str(parsed.get("selected_title", "unemployed"))
	if not _title_is_unlocked(selected_title):
		selected_title = "unemployed"
	runs_finished = maxi(0, int(parsed.get("runs_finished", 0)))
	custom_cooks = maxi(0, int(parsed.get("custom_cooks", 0)))


func _title_is_unlocked(title_id: String) -> bool:
	var crowns := total_crowns()
	for definition in TITLES:
		if str(definition.id) == title_id:
			return crowns >= int(definition.crowns)
	return false


func _read_int_dict(source, target: Dictionary) -> void:
	if typeof(source) != TYPE_DICTIONARY:
		return
	for key in source:
		var value := int(source[key])
		if value > 0:
			target[str(key)] = value
