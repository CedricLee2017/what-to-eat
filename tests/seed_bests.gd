extends Node

## 開發用：造幾個排行榜紀錄。


func _ready() -> void:
	var today := MealGameState.today_key()
	var records := [
		[86.4, "S", "daily", today, 27, "香煎三文魚飯", 14],
		[79.2, "A", "daily", today, 32, "雞胸沙律", 12],
		[75.6, "A", "free", "", 41, "番茄炒蛋", 10],
		[68.0, "B", "free", "", 18, "咖喱薯仔雞", 8],
		[57.4, "C", "daily", "20261024", 9, "即食麵加蛋", 5],
	]
	for entry in records:
		var mode: String = entry[2]
		var date_key: String = entry[3]
		var state := MealGameState.new(1000 + int(entry[0]), mode, date_key)
		var report := {
			"average": entry[0],
			"grade": entry[1],
			"mode": mode,
			"savings": entry[4],
			"favourite": entry[5],
			"distinct": entry[6],
			"perfect": 6,
			"burnt": 1,
			"fridge_left": 2,
			"seed": state.run_seed,
		}
		SaveData.add_result(state, report)
	print("SEEDED BESTS: " + str(SaveData.load_bests().get("runs", []).size()))
	get_tree().quit(0)
