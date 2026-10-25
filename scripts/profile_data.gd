class_name ProfileData
extends RefCounted

## 本機玩家檔案：暱稱 + 可選 4 位 PIN。
## 唔需要後端；PIN 只係用嚟分辨同一部機嘅玩家，唔係高安全性帳戶。

const PROFILE_PATH := "user://profile.json"

static var session_name := ""
static var session_guest := true
static var session_active := false


static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_PATH):
		return {}
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var nickname := _clean_name(str(parsed.get("nickname", "")))
	if nickname.is_empty():
		return {}
	return {
		"nickname": nickname,
		"pin_hash": str(parsed.get("pin_hash", "")),
		"created_at": int(parsed.get("created_at", 0)),
	}


static func has_profile() -> bool:
	return not load_profile().is_empty()


static func save_profile(nickname: String, pin: String) -> Dictionary:
	var clean := _clean_name(nickname)
	if clean.is_empty():
		return {}
	var data := {
		"nickname": clean,
		"pin_hash": pin.sha256_text() if not pin.is_empty() else "",
		"created_at": int(Time.get_unix_time_from_system()),
	}
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()
	set_session(clean, false)
	return data


static func verify_pin(pin: String) -> bool:
	var profile := load_profile()
	if profile.is_empty():
		return false
	var stored := str(profile.get("pin_hash", ""))
	if stored.is_empty():
		return true
	return pin.sha256_text() == stored


static func profile_has_pin() -> bool:
	return not str(load_profile().get("pin_hash", "")).is_empty()


static func set_session(nickname: String, guest: bool = false) -> void:
	session_name = _clean_name(nickname) if not guest else ""
	session_guest = guest
	session_active = true


static func set_guest() -> void:
	set_session("", true)


static func logout() -> void:
	session_name = ""
	session_guest = true
	session_active = false


static func clear_profile() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove("profile.json")
	logout()


static func current_name() -> String:
	if session_guest or session_name.is_empty():
		return "訪客"
	return session_name


static func is_guest() -> bool:
	return session_guest or session_name.is_empty()


static func _clean_name(value: String) -> String:
	var text := value.strip_edges().replace("\n", " ").replace("\t", " ")
	if text.length() > 12:
		text = text.substr(0, 12)
	return text
