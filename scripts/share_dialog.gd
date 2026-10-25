class_name ShareDialog
extends Control

var recipe_id := ""

var _code: LineEdit
var _status: Label
var _publish: Button


func _ready() -> void:
	modulate.a = 0.0
	var recipe := RecipeBook.get_recipe(recipe_id)
	var code := RecipeBook.share_code(recipe_id)

	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.13, 0.1, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close()
	)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -310.0
	panel.offset_right = 310.0
	panel.offset_top = -240.0
	panel.offset_bottom = 240.0
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, 30, 20, Color.TRANSPARENT, 0, 22))
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(UIKit.pill("分享食譜", UIKit.SUN_SOFT, Color("#9A6C12"), 12))
	header.add_child(UIKit.spacer_h())
	var close := UIKit.ghost_button("×", UIKit.MUTED, 26, Vector2(44, 44))
	close.pressed.connect(_close)
	header.add_child(close)

	box.add_child(UIKit.label(str(recipe.get("name", "食譜")), 26, UIKit.INK, true))
	var art_row := HBoxContainer.new()
	art_row.add_theme_constant_override("separation", 10)
	box.add_child(art_row)
	var art := DishArt.new()
	art.recipe_id = recipe_id
	art.custom_minimum_size = Vector2(70, 70)
	art_row.add_child(art)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art_row.add_child(info)
	info.add_child(UIKit.label(MealData.item_names(recipe), 13, UIKit.MUTED, false))
	info.add_child(UIKit.label("%s · %d kcal · 讚好 %d" % [MealData.method_name(MealData.method_of(recipe)), int(recipe.get("kcal", 0)), int(recipe.get("like_count", 0))], 11, UIKit.MUTED, false))

	box.add_child(UIKit.label("分享碼（朋友可以貼上匯入）", 11, UIKit.MUTED, false))
	_code = LineEdit.new()
	_code.text = code
	_code.editable = false
	_code.custom_minimum_size.y = 44
	_code.add_theme_font_override("font", UIKit.font(false))
	_code.add_theme_font_size_override("font_size", 11)
	_code.add_theme_color_override("font_color", UIKit.INK)
	_code.add_theme_color_override("font_uneditable_color", UIKit.INK)
	_code.add_theme_stylebox_override("normal", UIKit.box(UIKit.CREAM, 14, 0, UIKit.LINE, 1, 10))
	_code.add_theme_stylebox_override("read_only", UIKit.box(UIKit.CREAM, 14, 0, UIKit.LINE, 1, 10))
	box.add_child(_code)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var copy := UIKit.button("複製分享碼", UIKit.SUN, UIKit.INK, 18, 13, true, Vector2(0, 42))
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(code)
		Sfx.play("coin")
		_status.text = "已複製，傳俾朋友啦。"
		_status.add_theme_color_override("font_color", UIKit.MINT)
	)
	actions.add_child(copy)

	_publish = UIKit.button("發佈到朋友食譜", UIKit.CORAL, Color.WHITE, 18, 12, true, Vector2(0, 42))
	_publish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_publish.pressed.connect(_publish_recipe)
	_publish.visible = Online.enabled and str(recipe.get("remote_id", "")).is_empty()
	actions.add_child(_publish)

	_status = UIKit.label("", 11, UIKit.MUTED, false)
	box.add_child(_status)
	if not str(recipe.get("remote_id", "")).is_empty():
		_status.text = "已發佈 · 等朋友讚好，你會收到人氣預算。"
	if not Online.enabled:
		_status.text = "離線分享碼模式；朋友讚好只會記錄喺佢部機。"
	if RecipeBook.publish_result.is_connected(_on_published) == false:
		RecipeBook.publish_result.connect(_on_published)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _publish_recipe() -> void:
	_publish.disabled = true
	_status.text = "發佈中…"
	if not RecipeBook.publish(recipe_id):
		_status.text = "暫時連唔到線上食譜。"
		_publish.disabled = false


func _on_published(ok: bool, message: String, published_id: String, _remote_id: String) -> void:
	if published_id != recipe_id:
		return
	_status.text = message
	_status.add_theme_color_override("font_color", UIKit.MINT if ok else UIKit.CORAL)
	_publish.visible = not ok
	if ok:
		_publish.disabled = false


func _close() -> void:
	Sfx.play("click")
	queue_free()
