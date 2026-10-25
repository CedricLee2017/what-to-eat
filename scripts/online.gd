extends Node

## 線上排行榜客戶端。所有失敗都會 fallback 返本機排行榜。

signal submit_finished(ok: bool, message: String, rank: int)
signal top_finished(ok: bool, message: String, entries: Array)
signal recipes_loaded(ok: bool, message: String, entries: Array)
signal recipe_published(ok: bool, message: String, recipe_id: String, remote_id: String)
signal recipe_liked(ok: bool, message: String, remote_id: String, like_count: int)
signal rewards_loaded(ok: bool, likes: int)

var enabled := true
var endpoint := ""
var device_id := ""

var _submit_busy := false
var _top_busy := false
var _recipe_busy := false
var _like_busy := false
var _reward_busy := false


func _ready() -> void:
	_load_config()
	device_id = SaveData.get_device_id()


func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load("res://config/online.cfg") == OK:
		enabled = bool(config.get_value("online", "enabled", true))
		endpoint = str(config.get_value("online", "endpoint", "")).strip_edges()

	if endpoint.is_empty() and OS.has_feature("web"):
		var origin := ""
		if JavaScriptBridge is Object:
			origin = str(JavaScriptBridge.eval("window.location.origin", true))
		if origin.begins_with("http"):
			endpoint = origin.trim_suffix("/") + "/api/leaderboard"

	endpoint = endpoint.trim_suffix("/")
	if endpoint.is_empty():
		enabled = false


func submit_daily(state: MealGameState, report: Dictionary) -> bool:
	if not enabled or _submit_busy:
		return false
	if state == null or state.mode != "daily" or state.challenge_date.is_empty():
		return false
	_submit_busy = true
	var payload := {
		"device_id": device_id,
		"date_key": state.challenge_date,
		"stats": state.stats,
		"savings": int(report.get("savings", 0)),
		"distinct": int(report.get("distinct", 0)),
		"perfect": int(report.get("perfect", 0)),
		"burnt": int(report.get("burnt", 0)),
		"favourite": str(report.get("favourite", "")),
	}
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		_submit_busy = false
		_on_submit_response(result, response_code, body)
	)
	var err := request.request(
		endpoint,
		PackedStringArray(["Content-Type: application/json", "Accept: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload),
	)
	if err != OK:
		request.queue_free()
		_submit_busy = false
		submit_finished.emit(false, "線上暫時連唔到，成績已存本機", 0)
		return false
	return true


func fetch_board(date_key: String = "") -> bool:
	if not enabled or _top_busy:
		return false
	_top_busy = true
	var date := date_key if not date_key.is_empty() else MealGameState.today_key()
	var url := "%s?date=%s&limit=10" % [endpoint, date]
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		_top_busy = false
		_on_top_response(result, response_code, body)
	)
	var err := request.request(
		url,
		PackedStringArray(["Accept: application/json"]),
		HTTPClient.METHOD_GET,
	)
	if err != OK:
		request.queue_free()
		_top_busy = false
		top_finished.emit(false, "線上排行榜暫時連唔到", [])
		return false
	return true


func fetch_today() -> bool:
	return fetch_board("")


func publish_recipe(entry: Dictionary) -> bool:
	if not enabled or _recipe_busy:
		return false
	_recipe_busy = true
	var payload := {
		"device_id": device_id,
		"name": str(entry.get("name", "")),
		"items": entry.get("items", []),
		"form": str(entry.get("form", "plate")),
		"method": MealData.method_of(entry),
		"colors": entry.get("colors", []),
	}
	var url := _base_url() + "/recipes"
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		_recipe_busy = false
		_on_publish_response(result, code, body, str(entry.get("id", "")))
	)
	var err := request.request(url, PackedStringArray(["Content-Type: application/json", "Accept: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		request.queue_free()
		_recipe_busy = false
		recipe_published.emit(false, "線上暫時連唔到", str(entry.get("id", "")), "")
		return false
	return true


func fetch_recipes() -> bool:
	if not enabled or _recipe_busy:
		return false
	_recipe_busy = true
	var url := _base_url() + "/recipes?limit=20"
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		_recipe_busy = false
		_on_recipes_response(result, code, body)
	)
	var err := request.request(url, PackedStringArray(["Accept: application/json"]), HTTPClient.METHOD_GET)
	if err != OK:
		request.queue_free()
		_recipe_busy = false
		recipes_loaded.emit(false, "朋友食譜暫時連唔到", [])
		return false
	return true


func like_recipe(remote_id: String) -> bool:
	if not enabled or _like_busy or remote_id.is_empty():
		return false
	_like_busy = true
	var url := _base_url() + "/recipes/%s/like" % remote_id.uri_encode()
	var payload := {"device_id": device_id}
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		_like_busy = false
		_on_like_response(result, code, body)
	)
	var err := request.request(url, PackedStringArray(["Content-Type: application/json", "Accept: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		request.queue_free()
		_like_busy = false
		recipe_liked.emit(false, "暫時連唔到讚好", remote_id, 0)
		return false
	return true


func fetch_rewards(for_device: String) -> bool:
	if not enabled or _reward_busy or for_device.is_empty():
		return false
	_reward_busy = true
	var url := _base_url() + "/rewards?device_id=%s" % for_device.uri_encode()
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		_reward_busy = false
		_on_rewards_response(result, code, body)
	)
	var err := request.request(url, PackedStringArray(["Accept: application/json"]), HTTPClient.METHOD_GET)
	if err != OK:
		request.queue_free()
		_reward_busy = false
		rewards_loaded.emit(false, 0)
		return false
	return true


func _base_url() -> String:
	var base := endpoint
	if base.ends_with("/api/leaderboard"):
		base = base.trim_suffix("/leaderboard")
	return base.trim_suffix("/")


func _on_publish_response(result: int, code: int, body: PackedByteArray, recipe_id: String) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		recipe_published.emit(false, "發佈失敗，稍後再試", recipe_id, "")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not bool(data.get("ok", false)):
		recipe_published.emit(false, "發佈失敗", recipe_id, "")
		return
	recipe_published.emit(true, "已發佈到朋友食譜", recipe_id, str(data.get("id", "")))


func _on_recipes_response(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		recipes_loaded.emit(false, "朋友食譜暫時連唔到", [])
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not bool(data.get("ok", false)):
		recipes_loaded.emit(false, "朋友食譜暫時連唔到", [])
		return
	var entries = data.get("recipes", [])
	if typeof(entries) != TYPE_ARRAY:
		entries = []
	recipes_loaded.emit(true, "朋友食譜", entries)


func _on_like_response(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		recipe_liked.emit(false, "暫時連唔到讚好", "", 0)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		recipe_liked.emit(false, "讚好失敗", "", 0)
		return
	if code == 403:
		recipe_liked.emit(false, "唔可以讚自己", "", 0)
		return
	if code != 200 or not bool(data.get("ok", false)):
		recipe_liked.emit(false, "讚好失敗", "", 0)
		return
	recipe_liked.emit(true, "已讚好", str(data.get("id", "")), int(data.get("like_count", 0)))


func _on_rewards_response(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		rewards_loaded.emit(false, 0)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not bool(data.get("ok", false)):
		rewards_loaded.emit(false, 0)
		return
	rewards_loaded.emit(true, int(data.get("likes", 0)))


func _on_submit_response(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		submit_finished.emit(false, "線上暫時連唔到，成績已存本機", 0)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		submit_finished.emit(false, "線上回覆格式有問題，成績已存本機", 0)
		return
	if code == 409 or str(data.get("error", "")) == "already_submitted":
		submit_finished.emit(true, "今日已提交過（以第一次為準）", 0)
		return
	if code != 200 or not bool(data.get("ok", false)):
		var message := "線上暫時連唔到，成績已存本機"
		if code == 429:
			message = "提交太頻密，請遲啲再試"
		elif code == 400:
			message = "線上拒絕咗呢個成績"
		submit_finished.emit(false, message, 0)
		return
	var rank := int(data.get("rank", 0))
	var total := int(data.get("total", 0))
	var text := "線上已提交"
	if rank > 0:
		text += " · 第 %d 名" % rank
	if total > 0:
		text += " / %d 人" % total
	submit_finished.emit(true, text, rank)


func _on_top_response(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		top_finished.emit(false, "線上排行榜暫時連唔到", [])
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or code != 200 or not bool(data.get("ok", false)):
		top_finished.emit(false, "線上排行榜暫時連唔到", [])
		return
	var entries = data.get("entries", [])
	if typeof(entries) != TYPE_ARRAY:
		entries = []
	var total := int(data.get("total", 0))
	top_finished.emit(true, "共 %d 人提交" % total, entries)
