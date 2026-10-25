class_name RecipeBookScreen
extends Control

signal back_pressed
signal create_pressed

var _content: VBoxContainer
var _tab_mine: Button
var _tab_friends: Button
var _mode := "mine"
var _status: Label
var _import_edit: LineEdit
var _friends: Array = []
var _like_labels: Dictionary = {}


func _ready() -> void:
	modulate.a = 0.0
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(UIKit.pill("食譜簿", UIKit.SUN_SOFT, Color("#9A6C12"), 12))
	header.add_child(UIKit.spacer_h())
	var note := UIKit.label("創作 · 分享 · 讚好", 11, UIKit.MUTED, false)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(note)

	box.add_child(UIKit.label("你嘅廚房", 30, UIKit.INK, true))
	box.add_child(UIKit.label("自創食譜會加入揀菜清單；朋友讚好會送你每日預算 +$5。", 12, UIKit.MUTED, false))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	_tab_mine = _tab_button("我嘅食譜", "mine")
	_tab_friends = _tab_button("朋友食譜", "friends")
	tabs.add_child(_tab_mine)
	tabs.add_child(_tab_friends)
	tabs.add_child(UIKit.spacer_h())
	_status = UIKit.label("", 11, UIKit.MUTED, false)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tabs.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scroll_theme := Theme.new()
	scroll_theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	scroll_theme.set_stylebox("grabber", "VScrollBar", UIKit.box(UIKit.LINE, 3))
	scroll.theme = scroll_theme
	box.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	var back := UIKit.button("返回", UIKit.PAPER, UIKit.INK, 22, 17, true, Vector2(0, 48))
	back.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 22, 0, UIKit.LINE, 1, 12))
	back.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 22, 0, UIKit.LINE, 1, 12))
	back.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 22, 0, UIKit.LINE, 1, 12))
	back.pressed.connect(func() -> void:
		Sfx.play("click")
		back_pressed.emit()
	)
	box.add_child(back)

	if RecipeBook.friends_result.is_connected(_on_friends_result) == false:
		RecipeBook.friends_result.connect(_on_friends_result)
	if RecipeBook.like_result.is_connected(_on_like_result) == false:
		RecipeBook.like_result.connect(_on_like_result)
	if Online.recipe_liked.is_connected(_on_online_like) == false:
		Online.recipe_liked.connect(_on_online_like)
	_switch("mine")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)


func _tab_button(text: String, mode: String) -> Button:
	var button := UIKit.button(text, UIKit.PAPER, UIKit.MUTED, 17, 13, true, Vector2(112, 36))
	button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 17, 0, UIKit.LINE, 1, 9))
	button.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 17, 0, UIKit.LINE, 1, 9))
	button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 17, 0, UIKit.LINE, 1, 9))
	button.pressed.connect(func() -> void:
		Sfx.play("click")
		_switch(mode)
	)
	return button


func _switch(mode: String) -> void:
	_mode = mode
	_style_tab(_tab_mine, mode == "mine")
	_style_tab(_tab_friends, mode == "friends")
	_status.text = ""
	_clear_content()
	if mode == "mine":
		_render_mine()
	else:
		_render_friends_start()


func _style_tab(button: Button, selected: bool) -> void:
	var bg := UIKit.CORAL_SOFT if selected else UIKit.PAPER
	var fg := UIKit.CORAL if selected else UIKit.MUTED
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg)
	button.add_theme_color_override("font_pressed_color", fg)
	button.add_theme_stylebox_override("normal", UIKit.box(bg, 17, 0, UIKit.LINE, 1, 9))
	button.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.03), 17, 0, UIKit.LINE, 1, 9))


func _clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func refresh_mine() -> void:
	if _mode == "mine":
		_switch("mine")


func _render_mine() -> void:
	var create := UIKit.button("＋ 創作新食譜", UIKit.CORAL, Color.WHITE, 20, 16, true, Vector2(0, 48))
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.pressed.connect(func() -> void:
		Sfx.play("click")
		create_pressed.emit()
	)
	_content.add_child(create)

	if RecipeBook.recipes.is_empty():
		_content.add_child(_empty_panel("仲未有自創食譜。試下用三樣材料創作一道菜。"))
		return
	for recipe in RecipeBook.recipes:
		_content.add_child(_mine_row(recipe))
	_content.add_child(UIKit.gap(0, 8))


func _mine_row(recipe: Dictionary) -> Control:
	var panel := UIKit.panel(UIKit.PAPER, 20, 4, Color.TRANSPARENT, 0, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var art := DishArt.new()
	art.recipe_id = str(recipe.id)
	art.custom_minimum_size = Vector2(56, 56)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	text.add_child(UIKit.label(str(recipe.name), 17, UIKit.INK, true))
	text.add_child(UIKit.label(MealData.item_names(recipe), 11, UIKit.MUTED, false))
	var note := "%s · 讚好 %d" % [MealData.method_name(MealData.method_of(recipe)), int(recipe.get("like_count", 0))]
	if not str(recipe.get("remote_id", "")).is_empty():
		note += " · 已發佈"
	text.add_child(UIKit.label(note, 10, UIKit.MUTED, false))
	var share := UIKit.button("分享", UIKit.SUN_SOFT, Color("#9A6C12"), 16, 12, true, Vector2(66, 34))
	share.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	share.pressed.connect(func() -> void:
		var dialog := ShareDialog.new()
		dialog.recipe_id = str(recipe.id)
		dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dialog)
	)
	row.add_child(share)
	return panel


func _render_friends_start() -> void:
	_add_import_row()
	if not Online.enabled:
		_content.add_child(_empty_panel("線上食譜未連線。\n仍然可以用朋友嘅分享碼匯入。"))
		return
	_content.add_child(_empty_panel("連線到朋友食譜…"))
	RecipeBook.fetch_friends()


func _add_import_row() -> void:
	var import_row := HBoxContainer.new()
	import_row.add_theme_constant_override("separation", 6)
	_content.add_child(import_row)
	_import_edit = LineEdit.new()
	_import_edit.placeholder_text = "貼上朋友嘅 EAT1: 分享碼"
	_import_edit.custom_minimum_size.y = 40
	_import_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_import_edit.add_theme_font_override("font", UIKit.font(false))
	_import_edit.add_theme_font_size_override("font_size", 12)
	_import_edit.add_theme_color_override("font_color", UIKit.INK)
	_import_edit.add_theme_color_override("font_placeholder_color", Color(0.6, 0.56, 0.5, 0.6))
	_import_edit.add_theme_stylebox_override("normal", UIKit.box(UIKit.CREAM, 14, 0, UIKit.LINE, 1, 9))
	import_row.add_child(_import_edit)
	var import_button := UIKit.button("匯入", UIKit.MINT, Color.WHITE, 16, 12, true, Vector2(64, 40))
	import_button.pressed.connect(_import_code)
	import_row.add_child(import_button)


func _on_friends_result(ok: bool, message: String, entries: Array) -> void:
	if _mode != "friends" or not is_inside_tree():
		return
	_clear_content()
	_add_import_row()
	if not ok:
		_content.add_child(_empty_panel("朋友食譜暫時連唔到。\n" + message))
		return
	_friends = entries
	RecipeBook.sync_like_counts(entries)
	if entries.is_empty():
		_content.add_child(_empty_panel("未有人分享食譜。你可以做第一個。"))
		return
	for entry in entries:
		_content.add_child(_friend_row(entry))
	_content.add_child(UIKit.gap(0, 8))


func _friend_row(entry: Dictionary) -> Control:
	var remote_id := str(entry.get("id", ""))
	var preview := MealData.build_custom_recipe("preview", str(entry.get("name", "食譜")), entry.get("items", []), str(entry.get("form", "plate")), entry.get("colors", []), str(entry.get("method", "")))
	var panel := UIKit.panel(UIKit.PAPER, 20, 4, Color.TRANSPARENT, 0, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var art := DishArt.new()
	art.recipe_data = preview
	art.custom_minimum_size = Vector2(56, 56)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	text.add_child(UIKit.label(str(entry.get("name", "食譜")), 16, UIKit.INK, true))
	text.add_child(UIKit.label(MealData.item_names(preview), 10, UIKit.MUTED, false))
	var like_label := UIKit.label("♥ %d" % int(entry.get("like_count", 0)), 11, UIKit.CORAL, true)
	text.add_child(like_label)
	_like_labels[remote_id] = like_label

	var add_button := UIKit.button("加入", UIKit.MINT_SOFT, Color("#3F7D5F"), 15, 11, true, Vector2(58, 32))
	add_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if RecipeBook.has_remote(remote_id):
		add_button.text = "已加入"
		add_button.disabled = true
	else:
		add_button.pressed.connect(func() -> void:
			var imported := RecipeBook.import_remote(entry)
			if not imported.is_empty():
				add_button.text = "已加入"
				add_button.disabled = true
				_status.text = "已加入你嘅食譜"
				_status.add_theme_color_override("font_color", UIKit.MINT)
				Sfx.play("coin")
		)
	row.add_child(add_button)

	var like_button := UIKit.button("讚好", UIKit.CORAL_SOFT, UIKit.CORAL, 15, 11, true, Vector2(58, 32))
	like_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	like_button.pressed.connect(func() -> void:
		like_button.disabled = true
		_status.text = "讚好中…"
		RecipeBook.like_remote(remote_id)
	)
	row.add_child(like_button)
	return panel


func _import_code() -> void:
	if _import_edit == null:
		return
	var entry := RecipeBook.import_code(_import_edit.text)
	if entry.is_empty():
		_status.text = "分享碼無效"
		_status.add_theme_color_override("font_color", UIKit.CORAL)
		return
	_import_edit.text = ""
	_status.text = "已匯入：%s" % str(entry.name)
	_status.add_theme_color_override("font_color", UIKit.MINT)
	Sfx.play("coin")


func _on_like_result(ok: bool, message: String, _recipe_id: String, _count: int) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", UIKit.MINT if ok else UIKit.CORAL)


func _on_online_like(ok: bool, message: String, remote_id: String, count: int) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", UIKit.MINT if ok else UIKit.CORAL)
	if ok and _like_labels.has(remote_id):
		_like_labels[remote_id].text = "♥ %d" % count


func _empty_panel(text: String) -> PanelContainer:
	var panel := UIKit.panel(UIKit.CREAM, 20, 0, Color.TRANSPARENT, 0, 18)
	var label := UIKit.label(text, 13, UIKit.MUTED, false)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _exit_tree() -> void:
	if RecipeBook.friends_result.is_connected(_on_friends_result):
		RecipeBook.friends_result.disconnect(_on_friends_result)
	if RecipeBook.like_result.is_connected(_on_like_result):
		RecipeBook.like_result.disconnect(_on_like_result)
	if Online.recipe_liked.is_connected(_on_online_like):
		Online.recipe_liked.disconnect(_on_online_like)
