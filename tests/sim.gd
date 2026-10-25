extends Node

## 平衡分析工具（非測試）：暴力搜尋每日最佳組合，睇下 $60 夠唔夠食得健康。


func _ready() -> void:
	var state := MealGameState.new(2026)
	var days: Array = []
	for day_index in range(7):
		var best := _best_combo(state)
		print("DAY %d  weather=%s  sale=%s" % [state.day, state.weather, str(state.sale_ids)])
		print("  best=%s cost=$%d ratios=%s" % [str(best.ids), best.cost, _fmt(best.ratios)])
		var all_target := _cheapest_all_target(state)
		if all_target.is_empty():
			print("  all-target: impossible")
		else:
			print("  all-target cheapest=$%d %s" % [all_target.cost, str(all_target.ids)])
		for i in range(3):
			state.cook(i, best.ids[i], "good")
		var summary := state.settle_day()
		print("  stats=%s saved=$%d kcal=%d" % [_fmt_stats(state.stats), int(summary.saved), int(summary.kcal)])
		if day_index < 6:
			state.next_day()
	var report := state.report()
	print("REPORT grade=%s avg=%.1f savings=%d favourite=%s perfect=%d burnt=%d" % [
		report.grade, report.average, report.savings, report.favourite, report.perfect, report.burnt,
	])
	get_tree().quit(0)


func _best_combo(state: MealGameState) -> Dictionary:
	var best := {"score": -1.0, "ids": [], "cost": 0, "ratios": {}}
	for a in MealData.RECIPES:
		for b in MealData.RECIPES:
			for c in MealData.RECIPES:
				var ids := [a.id, b.id, c.id]
				var cost := 0
				for rid in ids:
					cost += state.price_of(rid)
				if cost > state.remaining():
					continue
				var ratios := _ratios(state, ids)
				var minimum := 9.0
				var total := 0.0
				for key in MealData.STAT_KEYS:
					minimum = minf(minimum, float(ratios[key]))
					total += minf(float(ratios[key]), 1.25)
				var score := minimum * 2.0 + total / float(MealData.STAT_KEYS.size())
				if score > float(best.score):
					best = {"score": score, "ids": ids, "cost": cost, "ratios": ratios}
	return best


func _cheapest_all_target(state: MealGameState) -> Dictionary:
	var best := {}
	for a in MealData.RECIPES:
		for b in MealData.RECIPES:
			for c in MealData.RECIPES:
				var ids := [a.id, b.id, c.id]
				var cost := 0
				for rid in ids:
					cost += state.price_of(rid)
				if cost > state.remaining():
					continue
				var ratios := _ratios(state, ids)
				var ok := true
				for key in MealData.STAT_KEYS:
					if float(ratios[key]) < 1.0:
						ok = false
				if ok and (best.is_empty() or cost < int(best.cost)):
					best = {"cost": cost, "ids": ids, "ratios": ratios}
	return best


func _ratios(state: MealGameState, ids: Array) -> Dictionary:
	var counts := {}
	var totals := {"body": 0.0, "vitc": 0.0, "vitd": 0.0, "fiber": 0.0, "mood": 0.0}
	var kcal := 0
	var unique := {}
	for rid in ids:
		var recipe := MealData.recipe(rid)
		var repeat: int = int(counts.get(rid, 0)) + state.week_count(rid)
		var mood_mult: float = maxf(0.4, 1.0 - 0.18 * float(repeat))
		totals.body += float(recipe.protein)
		totals.vitc += float(recipe.vitc)
		totals.vitd += float(recipe.vitd)
		totals.fiber += float(recipe.fiber)
		totals.mood += float(recipe.mood) * mood_mult
		kcal += int(recipe.kcal)
		unique[rid] = true
		counts[rid] = int(counts.get(rid, 0)) + 1
	totals.mood += float(unique.size()) * 2.0
	if state.weather == "sunny":
		totals.vitd += 2.0
		totals.mood += 2.0
	elif state.weather == "rainy":
		totals.mood -= 3.0
	if kcal < 1150:
		totals.body *= 0.8
	var ratios := {}
	for key in MealData.STAT_KEYS:
		ratios[key] = totals[key] / float(MealData.STATS[key].target)
	return ratios


func _fmt(ratios: Dictionary) -> String:
	var parts: Array[String] = []
	for key in MealData.STAT_KEYS:
		parts.append("%s=%.0f%%" % [key, float(ratios[key]) * 100.0])
	return " ".join(parts)


func _fmt_stats(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for key in MealData.STAT_KEYS:
		parts.append("%s=%d" % [key, int(round(float(stats[key])))])
	return " ".join(parts)
