extends Node

## 自創食譜、分享碼、網上發佈／讚好，以及人氣預算獎勵。

signal rewards_changed(new_likes: int, bonus_days: int)
signal publish_result(ok: bool, message: String, recipe_id: String, remote_id: String)
signal like_result(ok: bool, message: String, recipe_id: String, like_count: int)
signal friends_result(ok: bool, message: String, entries: Array)

const RECIPE_PATH := "user://custom_recipes.json"
const REWARD_PATH := "user://rewards.json"
const BONUS_DAYS_PER_LIKE := 10
const BONUS_AMOUNT := 5
const MAX_BONUS_DAYS := 90
const MAX_ITEMS := 3

var recipes: Array = []
var bonus_days := 0
var reward_likes_seen := 0
var _reward_busy := false


func _ready() -> void:
	_load_recipes()
	_load_rewards()
	if Online.recipes_loaded.is_connected(_on_friends) == false:
		Online.recipes_loaded.connect(_on_friends)
	if Online.recipe_published.is_connected(_on_published) == false:
		Online.recipe_published.connect(_on_published)
	if Online.recipe_liked.is_connected(_on_liked) == false:
		Online.recipe_liked.connect(_on_liked)
	if Online.rewards_loaded.is_connected(_on_rewards) == false:
		Online.rewards_loaded.connect(_on_rewards)
	call_deferred("sync_rewards")


func _load_recipes() -> void:
	recipes.clear()
	if not FileAccess.file_exists(RECIPE_PATH):
		return
	var file := FileAccess.open(RECIPE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		return
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var recipe_data := _sanitize_recipe(entry, str(entry.get("id", "")))
		if recipe_data.is_empty():
			continue
		recipes.append(recipe_data)
		MealData.register_custom(recipe_data)


func _load_rewards() -> void:
	if not FileAccess.file_exists(REWARD_PATH):
		return
	var file := FileAccess.open(REWARD_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	bonus_days = clampi(int(parsed.get("bonus_days", 0)), 0, MAX_BONUS_DAYS)
	reward_likes_seen = maxi(0, int(parsed.get("likes_seen", 0)))


func _save_rewards() -> void:
	var file := FileAccess.open(REWARD_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"bonus_days": bonus_days, "likes_seen": reward_likes_seen}))
	file.close()


func _save_recipes() -> void:
	var file := FileAccess.open(RECIPE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(recipes))
	file.close()


func create_recipe(recipe_name: String, items: Array, form: String, method: String = "") -> Dictionary:
	var clean_name := _clean_name(recipe_name)
	var clean_items: Array = []
	for item_id in items:
		var text := str(item_id)
		if MealData.INGREDIENTS.has(text) and not clean_items.has(text) and clean_items.size() < MAX_ITEMS:
			clean_items.append(text)
	if clean_name.is_empty() or clean_items.is_empty():
		return {}
	var recipe_id := "custom_%d_%d" % [int(Time.get_ticks_usec()), randi() % 10000]
	var recipe_data := MealData.build_custom_recipe(recipe_id, clean_name, clean_items, form, [], method)
	recipe_data["like_count"] = 0
	recipe_data["liked"] = false
	recipe_data["remote_id"] = ""
	recipes.append(recipe_data)
	MealData.register_custom(recipe_data)
	_save_recipes()
	return recipe_data


func _clean_name(value: String) -> String:
	var text := value.strip_edges().replace("\n", " ").replace("\t", " ")
	if text.length() > 12:
		text = text.substr(0, 12)
	return text


func _sanitize_recipe(entry: Dictionary, forced_id: String = "") -> Dictionary:
	var name_value := _clean_name(str(entry.get("name", "")))
	var items: Array = []
	for item_id in entry.get("items", []):
		var text := str(item_id)
		if MealData.INGREDIENTS.has(text) and not items.has(text) and items.size() < MAX_ITEMS:
			items.append(text)
	if name_value.is_empty() or items.is_empty():
		return {}
	var form := str(entry.get("form", "plate"))
	if not form in MealData.CUSTOM_FORMS:
		form = "plate"
	var method := str(entry.get("method", ""))
	if not MealData.COOK_METHODS.has(method):
		method = MealData.suggest_method(items)
	var recipe_id := forced_id if not forced_id.is_empty() else "custom_%d_%d" % [int(Time.get_ticks_usec()), randi() % 10000]
	var colors: Array = []
	for color in entry.get("colors", []):
		var text := str(color)
		if text.begins_with("#") and text.length() == 7:
			colors.append(text)
	var recipe_data := MealData.build_custom_recipe(recipe_id, name_value, items, form, colors, method)
	recipe_data["like_count"] = maxi(0, int(entry.get("like_count", 0)))
	recipe_data["liked"] = bool(entry.get("liked", false))
	recipe_data["remote_id"] = str(entry.get("remote_id", ""))
	recipe_data["creator"] = bool(entry.get("creator", true))
	return recipe_data


func get_recipe(recipe_id: String) -> Dictionary:
	for entry in recipes:
		if entry.id == recipe_id:
			return entry
	return {}


func share_code(recipe_id: String) -> String:
	var entry := get_recipe(recipe_id)
	if entry.is_empty():
		return ""
	var payload := {
		"v": 1,
		"name": entry.name,
		"items": entry.items,
		"form": entry.form,
		"method": MealData.method_of(entry),
		"colors": entry.colors,
	}
	return "EAT1:" + Marshalls.utf8_to_base64(JSON.stringify(payload))


func import_code(code: String) -> Dictionary:
	var text := code.strip_edges()
	if text.begins_with("EAT1:"):
		text = text.substr(5)
	var decoded := Marshalls.base64_to_utf8(text)
	var parsed = JSON.parse_string(decoded)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var entry := _sanitize_recipe(parsed)
	if entry.is_empty():
		return {}
	entry["creator"] = false
	entry["remote_id"] = ""
	entry["like_count"] = 0
	entry["liked"] = false
	recipes.append(entry)
	MealData.register_custom(entry)
	_save_recipes()
	return entry


func sync_like_counts(entries: Array) -> void:
	var changed := false
	for entry in entries:
		var remote_id := str(entry.get("id", ""))
		for local in recipes:
			if str(local.get("remote_id", "")) == remote_id:
				var count := int(entry.get("like_count", 0))
				if int(local.get("like_count", 0)) != count:
					local["like_count"] = count
					changed = true
	if changed:
		_save_recipes()


func import_remote(entry: Dictionary) -> Dictionary:
	var remote_id := str(entry.get("id", ""))
	if remote_id.is_empty():
		return {}
	for local in recipes:
		if str(local.get("remote_id", "")) == remote_id:
			return local
	var parsed := _sanitize_recipe(entry)
	if parsed.is_empty():
		return {}
	parsed["creator"] = false
	parsed["remote_id"] = remote_id
	parsed["like_count"] = maxi(0, int(entry.get("like_count", 0)))
	parsed["liked"] = false
	recipes.append(parsed)
	MealData.register_custom(parsed)
	_save_recipes()
	return parsed


func has_remote(remote_id: String) -> bool:
	for local in recipes:
		if str(local.get("remote_id", "")) == remote_id:
			return true
	return false


func like_remote(remote_id: String) -> void:
	if not Online.enabled:
		like_result.emit(false, "線上未連線", "", 0)
		return
	Online.like_recipe(remote_id)


func delete_recipe(recipe_id: String) -> void:
	for i in range(recipes.size()):
		if recipes[i].id == recipe_id:
			recipes.remove_at(i)
			for j in range(MealData.custom_recipes.size() - 1, -1, -1):
				if MealData.custom_recipes[j].id == recipe_id:
					MealData.custom_recipes.remove_at(j)
			_save_recipes()
			return


func publish(recipe_id: String) -> bool:
	if not Online.enabled:
		return false
	var entry := get_recipe(recipe_id)
	if entry.is_empty():
		return false
	return Online.publish_recipe(entry)


func like(recipe_id: String) -> void:
	var entry := get_recipe(recipe_id)
	if entry.is_empty():
		return
	var remote := str(entry.get("remote_id", ""))
	if not remote.is_empty() and Online.enabled:
		if not Online.like_recipe(remote):
			like_result.emit(false, "暫時連唔到讚好", recipe_id, int(entry.get("like_count", 0)))
		return
	if bool(entry.get("creator", true)):
		like_result.emit(false, "自己讚自己唔算數", recipe_id, int(entry.get("like_count", 0)))
		return
	entry["like_count"] = int(entry.get("like_count", 0)) + 1
	entry["liked"] = true
	_save_recipes()
	like_result.emit(true, "已讚好（本機）", recipe_id, int(entry.like_count))


func fetch_friends() -> bool:
	if not Online.enabled:
		friends_result.emit(false, "線上食譜未連線", [])
		return false
	return Online.fetch_recipes()


func sync_rewards() -> void:
	if not Online.enabled or _reward_busy:
		return
	_reward_busy = true
	if not Online.fetch_rewards(SaveData.get_device_id()):
		_reward_busy = false


func bonus_amount() -> int:
	return BONUS_AMOUNT if bonus_days > 0 else 0


func tick_bonus_day() -> void:
	if bonus_days <= 0:
		return
	bonus_days -= 1
	_save_rewards()


func _apply_reward_likes(total: int) -> void:
	if total <= reward_likes_seen:
		reward_likes_seen = maxi(reward_likes_seen, total)
		_save_rewards()
		return
	var new_likes := total - reward_likes_seen
	reward_likes_seen = total
	bonus_days = mini(MAX_BONUS_DAYS, bonus_days + new_likes * BONUS_DAYS_PER_LIKE)
	_save_rewards()
	rewards_changed.emit(new_likes, bonus_days)


func _on_rewards(ok: bool, likes: int) -> void:
	_reward_busy = false
	if ok:
		_apply_reward_likes(likes)


func _on_published(ok: bool, message: String, recipe_id: String, remote_id: String) -> void:
	if ok:
		var entry := get_recipe(recipe_id)
		if not entry.is_empty():
			entry["remote_id"] = remote_id
			entry["creator"] = true
			_save_recipes()
	publish_result.emit(ok, message, recipe_id, remote_id)


func _on_liked(ok: bool, message: String, remote_id: String, like_count: int) -> void:
	if ok:
		for entry in recipes:
			if str(entry.get("remote_id", "")) == remote_id:
				entry["like_count"] = like_count
				entry["liked"] = true
				_save_recipes()
				like_result.emit(true, message, str(entry.id), like_count)
				return
	like_result.emit(ok, message, "", like_count)


func _on_friends(ok: bool, message: String, entries: Array) -> void:
	friends_result.emit(ok, message, entries)
