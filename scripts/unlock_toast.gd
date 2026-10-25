class_name UnlockToast
extends Control

## 煮完飯後彈出嘅新王冠／成就／稱號提示。唔會阻擋輸入，幾秒後自動消失。

func setup(events: Array) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if events.is_empty():
		queue_free()
		return

	var holder := VBoxContainer.new()
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.anchor_top = 0.0
	holder.anchor_bottom = 0.0
	holder.offset_left = -196.0
	holder.offset_right = 196.0
	holder.offset_top = 24.0
	holder.offset_bottom = 0.0
	holder.alignment = BoxContainer.ALIGNMENT_BEGIN
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var panel := UIKit.panel(UIKit.PAPER, 22, 12, UIKit.SUN, 2, 14)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	header.add_child(UIKit.pill("新解鎖", UIKit.SUN_SOFT, Color("#8A6216"), 11))
	header.add_child(UIKit.spacer_h())
	header.add_child(UIKit.label("繼續煮落去", 10, UIKit.MUTED, false))

	var shown := 0
	for event in events:
		if shown >= 4:
			break
		box.add_child(_event_row(event))
		shown += 1
	if events.size() > shown:
		box.add_child(UIKit.label("＋%d 個其他解鎖" % (events.size() - shown), 11, UIKit.MUTED, false))

	Sfx.play("coin")
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_interval(3.0)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)


func _event_row(event: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var event_type := str(event.get("type", ""))
	var badge_color := UIKit.SUN_SOFT
	var badge_fg := Color("#8A6216")
	var badge_text := "冠"
	if event_type == "achievement":
		badge_color = UIKit.MINT_SOFT
		badge_fg = Color("#3F7D5F")
		badge_text = "成"
	elif event_type == "title":
		badge_color = UIKit.GRAPE_SOFT
		badge_fg = Color("#6B5B95")
		badge_text = "稱"
	var badge := UIKit.panel(badge_color, 12, 0, Color.TRANSPARENT, 0, 0)
	badge.custom_minimum_size = Vector2(28, 28)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var badge_label := UIKit.label(badge_text, 13, badge_fg, true)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", -1)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	text_box.add_child(UIKit.label(str(event.get("title", "解鎖")), 10, UIKit.MUTED, false))
	var text := UIKit.label(str(event.get("text", "")), 15, UIKit.INK, true)
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(text)
	return row
