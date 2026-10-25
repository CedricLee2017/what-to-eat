extends Node

## 開發用：造一個第 3 日、有雪櫃存貨嘅存檔，方便測試「繼續上次」。


func _ready() -> void:
	var state := MealGameState.new(24680, "daily", MealGameState.today_key())
	for d in range(2):
		for slot in range(3):
			state.cook(slot, ["egg_toast", "tofu_soup", "milk_oats"][slot], "good")
		state.settle_day()
		state.next_day()
	state.buy_ingredient("tomato")
	state.buy_ingredient("egg")
	state.cook(0, "tomato_egg", "perfect")
	SaveData.save_run(state)
	print("SEEDED SAVE day=%d mode=%s fridge=%d" % [state.day, state.mode, state.fridge_total()])
	get_tree().quit(0)
