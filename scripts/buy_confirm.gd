class_name BuyConfirm
extends Control

signal confirmed
signal cancelled

var state: MealGameState
var slot := 0
var recipe_id := ""


func _ready() -> void:
	modulate.a = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.13, 0.1, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_cancel()
	)
	add_child(dim)

	var recipe := MealData.recipe(recipe_id)
	var missing := state.missing_items(recipe_id)
	var cost := state.price_of(recipe_id)
	var missing_names: Array[String] = []
	for item_id in missing:
		var amount := int(missing[item_id])
		var name := str(MealData.INGREDIENTS[item_id].name)
		missing_names.append(name if amount <= 1 else "%s ×%d" % [name, amount])

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 456.0
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, 30, 20, Color.TRANSPARENT, 0, 24))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(UIKit.pill("雪櫃唔夠料", UIKit.CORAL_SOFT, UIKit.CORAL, 12))
	top.add_child(UIKit.spacer_h())

	box.add_child(UIKit.label("想煮：%s" % str(recipe.name), 23, UIKit.INK, true))
	var stock_line := "雪櫃有 %d / %d 樣材料" % [state.fridge_covered(recipe_id), state.required_count(recipe_id)]
	box.add_child(UIKit.label(stock_line, 12, UIKit.MUTED, false))

	var missing_panel := UIKit.panel(UIKit.CORAL_SOFT, 18, 0, Color.TRANSPARENT, 0, 12)
	box.add_child(missing_panel)
	var missing_box := VBoxContainer.new()
	missing_box.add_theme_constant_override("separation", 2)
	missing_panel.add_child(missing_box)
	missing_box.add_child(UIKit.label("需要補購：%s" % "、".join(missing_names), 14, UIKit.CORAL, true))
	missing_box.add_child(UIKit.label("補購費用 $%d · 補購後剩 $%d" % [cost, maxi(0, state.remaining() - cost)], 13, UIKit.INK, true))
	missing_box.add_child(UIKit.label("會先用雪櫃存貨；同意後才會買缺少嘅材料。", 11, UIKit.MUTED, false))

	box.add_child(UIKit.spacer_v())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	var cancel := UIKit.button("取消", UIKit.PAPER, UIKit.INK, 22, 17, true, Vector2(0, 48))
	cancel.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 22, 0, UIKit.LINE, 1, 10))
	cancel.add_theme_stylebox_override("hover", UIKit.box(UIKit.SAND, 22, 0, UIKit.LINE, 1, 10))
	cancel.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND.darkened(0.05), 22, 0, UIKit.LINE, 1, 10))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_cancel)
	buttons.add_child(cancel)
	var confirm := UIKit.button("同意 · 補購 $%d" % cost, UIKit.CORAL, Color.WHITE, 22, 15, true, Vector2(0, 48))
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(func() -> void:
		Sfx.play("coin")
		confirmed.emit()
	)
	buttons.add_child(confirm)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)


func _cancel() -> void:
	Sfx.play("click")
	cancelled.emit()
