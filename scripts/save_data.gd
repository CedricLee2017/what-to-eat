class_name SaveData
extends RefCounted

## 本機存檔：進行中嘅一局 + 本機排行榜（user://，Web 版會存去 IndexedDB）。

const RUN_PATH := "user://run.json"
const BEST_PATH := "user://bests.json"
const DEVICE_PATH := "user://device_id.txt"
const MAX_RECORDS := 10


static func get_device_id() -> String:
	if FileAccess.file_exists(DEVICE_PATH):
		var existing := FileAccess.get_file_as_string(DEVICE_PATH).strip_edges()
		if _valid_device_id(existing):
			return existing
	var crypto := Crypto.new()
	var generated := crypto.generate_random_bytes(16).hex_encode()
	var file := FileAccess.open(DEVICE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(generated)
		file.close()
	return generated


static func _valid_device_id(value: String) -> bool:
	if value.length() < 16 or value.length() > 64:
		return false
	for i in range(value.length()):
		var code := value.unicode_at(i)
		var ok := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 95 or code == 45
		if not ok:
			return false
	return true


static func save_run(state: MealGameState) -> void:
	var file := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"saved_at": int(Time.get_unix_time_from_system()),
		"state": state.to_dict(),
	}))
	file.close()


static func peek_run() -> Dictionary:
	if not FileAccess.file_exists(RUN_PATH):
		return {}
	var file := FileAccess.open(RUN_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var state = parsed.get("state", {})
	if typeof(state) != TYPE_DICTIONARY:
		return {}
	if int(state.get("version", 0)) != MealGameState.SAVE_VERSION:
		return {}
	return state


static func load_run() -> MealGameState:
	var data := peek_run()
	if data.is_empty():
		return null
	return MealGameState.from_dict(data)


static func clear_run() -> void:
	if not FileAccess.file_exists(RUN_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("run.json")


static func load_bests() -> Dictionary:
	if not FileAccess.file_exists(BEST_PATH):
		return {"runs": []}
	var file := FileAccess.open(BEST_PATH, FileAccess.READ)
	if file == null:
		return {"runs": []}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"runs": []}
	var runs = parsed.get("runs", [])
	if typeof(runs) != TYPE_ARRAY:
		runs = []
	return {"runs": runs}


static func save_bests(data: Dictionary) -> void:
	var file := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()


static func add_result(state: MealGameState, report: Dictionary) -> Dictionary:
	var data := load_bests()
	var runs: Array = data.get("runs", [])
	var record := {
		"id": "%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000],
		"finished_at": int(Time.get_unix_time_from_system()),
		"mode": str(report.get("mode", state.mode)),
		"date_key": str(state.challenge_date),
		"day_label": MealGameState.today_key(),
		"grade": str(report.grade),
		"average": round(float(report.average) * 10.0) / 10.0,
		"savings": int(report.savings),
		"favourite": str(report.favourite),
		"distinct": int(report.distinct),
		"perfect": int(report.perfect),
		"burnt": int(report.burnt),
		"fridge_left": int(report.fridge_left),
		"seed": int(report.seed),
		"stats": state.stats.duplicate(),
	}
	runs.append(record)
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var avg_a := float(a.get("average", 0.0))
		var avg_b := float(b.get("average", 0.0))
		if not is_equal_approx(avg_a, avg_b):
			return avg_a > avg_b
		return int(a.get("savings", 0)) > int(b.get("savings", 0))
	)
	if runs.size() > MAX_RECORDS:
		runs.resize(MAX_RECORDS)
	data["runs"] = runs
	save_bests(data)
	var rank := 0
	for i in range(runs.size()):
		if str(runs[i].get("id", "")) == str(record.id):
			rank = i + 1
			break
	return {"rank": rank, "runs": runs, "record": record, "best_today": best_today(runs)}


static func best_today(runs: Array) -> Dictionary:
	var today := MealGameState.today_key()
	var best := {}
	for run in runs:
		if str(run.get("mode", "")) != "daily":
			continue
		if str(run.get("date_key", "")) != today:
			continue
		if best.is_empty() or float(run.get("average", 0.0)) > float(best.get("average", 0.0)):
			best = run
	return best


static func today_best() -> Dictionary:
	return best_today(load_bests().get("runs", []))


static func overall_best() -> Dictionary:
	var runs: Array = load_bests().get("runs", [])
	return runs[0] if not runs.is_empty() else {}
