extends Node

## 檢查匯入後嘅字型資源有冇缺字（唔靠系統 fallback）。


func _ready() -> void:
	var words := "無職日記七日篇開始一個星期每日三餐一種身體由唔使返工嘅人主演蛋白質纖維多樣性"
	for weight in ["Regular", "Bold"]:
		var font: FontFile = load("res://assets/fonts/NotoSansTC-%s.ttf" % weight)
		var missing := ""
		for i in range(words.length()):
			if not font.has_char(words.unicode_at(i)):
				missing += words[i]
		print("%s: %d glyphs, missing=%s" % [weight, font.get_supported_chars().length(), missing])
	get_tree().quit(0)
