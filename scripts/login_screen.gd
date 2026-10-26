class_name LoginScreen
extends Control

signal login_pressed(nickname: String)
signal guest_pressed

var _profile: Dictionary = {}
var _existing_box: VBoxContainer
var _new_box: VBoxContainer
var _name_edit: LineEdit
var _pin_edit: LineEdit
var _new_name_edit: LineEdit
var _new_pin_edit: LineEdit
var _status: Label
var _login_button: Button


func _ready() -> void:
	modulate.a = 0.0
	_profile = ProfileData.load_profile()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var badge_center := CenterContainer.new()
	badge_center.add_child(UIKit.pill("無職日記 · 玩家登入", UIKit.MINT_SOFT, Color("#3F7D5F"), 13))
	box.add_child(badge_center)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	title_row.add_child(UIKit.label("今日", 52, UIKit.INK, true))
	title_row.add_child(UIKit.label("食咩好？", 52, UIKit.CORAL, true))
	box.add_child(title_row)

	var subtitle := UIKit.label("登入會記住你嘅名；訪客都可以照玩。", 16, UIKit.MUTED, false)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var character := CharacterArt.new()
	character.mood = 0.86
	character.custom_minimum_size = Vector2(230, 238)
	character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(character)

	var card := UIKit.panel(UIKit.PAPER, 30, 8, Color.TRANSPARENT, 0, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(card)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	card.add_child(card_box)

	_existing_box = VBoxContainer.new()
	_existing_box.add_theme_constant_override("separation", 7)
	card_box.add_child(_existing_box)
	_build_existing(_existing_box)

	_new_box = VBoxContainer.new()
	_new_box.add_theme_constant_override("separation", 7)
	card_box.add_child(_new_box)
	_build_new(_new_box)

	var guest_button := UIKit.button("訪客遊玩 · 唔使登入", UIKit.MINT_SOFT, Color("#3F7D5F"), 21, 16, true, Vector2(0, 48))
	guest_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guest_button.pressed.connect(func() -> void:
		Sfx.play("start")
		ProfileData.set_guest()
		guest_pressed.emit()
	)
	box.add_child(guest_button)

	_status = UIKit.label("", 12, UIKit.CORAL, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	var footer := UIKit.label("進度、食譜簿同排行榜都存在呢部機。", 11, Color(0.55, 0.51, 0.45, 0.78), false)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(footer)

	var sound_button := UIKit.button("音" if not Sfx.muted else "靜", UIKit.PAPER, UIKit.INK, 20, 13, true, Vector2(40, 40))
	sound_button.anchor_left = 1.0
	sound_button.anchor_right = 1.0
	sound_button.offset_left = -68.0
	sound_button.offset_right = -28.0
	sound_button.offset_top = 24.0
	sound_button.offset_bottom = 64.0
	sound_button.add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 20, 0, UIKit.LINE, 1, 4))
	sound_button.add_theme_stylebox_override("hover", UIKit.box(UIKit.SUN_SOFT, 20, 0, UIKit.LINE, 1, 4))
	sound_button.add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND, 20, 0, UIKit.LINE, 1, 4))
	sound_button.pressed.connect(func() -> void:
		Sfx.toggle_mute()
		sound_button.text = "靜" if Sfx.muted else "音"
		Sfx.play("click")
	)
	add_child(sound_button)

	_show_existing(not _profile.is_empty())
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)


func _build_existing(parent: VBoxContainer) -> void:
	if _profile.is_empty():
		return
	var nickname := str(_profile.get("nickname", ""))
	var hello := UIKit.label("歡迎回來", 12, UIKit.MUTED, false)
	parent.add_child(hello)
	parent.add_child(UIKit.label(nickname, 30, UIKit.INK, true))
	var has_pin := not str(_profile.get("pin_hash", "")).is_empty()
	var note := UIKit.label("輸入 4 位 PIN 繼續。" if has_pin else "你嘅本機檔案已經準備好。", 12, UIKit.MUTED, false)
	parent.add_child(note)

	_pin_edit = _make_line_edit("4 位 PIN", 4, true)
	_pin_edit.visible = has_pin
	_pin_edit.text_submitted.connect(func(_text: String) -> void: _submit_existing())
	parent.add_child(_pin_edit)

	_login_button = UIKit.button("登入 · %s" % nickname, UIKit.CORAL, Color.WHITE, 23, 18, true, Vector2(0, 50))
	_login_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_login_button.pressed.connect(_submit_existing)
	parent.add_child(_login_button)

	var switch_button := UIKit.ghost_button("用其他名／建立新玩家", UIKit.MUTED, 12, Vector2(0, 32))
	switch_button.pressed.connect(func() -> void:
		Sfx.play("click")
		_show_existing(false)
	)
	parent.add_child(switch_button)


func _build_new(parent: VBoxContainer) -> void:
	parent.add_child(UIKit.label("第一次見", 12, UIKit.MUTED, false))
	parent.add_child(UIKit.label("改個名先", 28, UIKit.INK, true))
	parent.add_child(UIKit.label("唔想改名，可以撳下面「訪客遊玩」。", 12, UIKit.MUTED, false))

	_new_name_edit = _make_line_edit("你嘅暱稱（最多 12 字）", 12, false)
	_new_name_edit.text_submitted.connect(func(_text: String) -> void: _submit_new())
	parent.add_child(_new_name_edit)

	_new_pin_edit = _make_line_edit("4 位 PIN（可留空）", 4, true)
	_new_pin_edit.text_submitted.connect(func(_text: String) -> void: _submit_new())
	parent.add_child(_new_pin_edit)

	var create_button := UIKit.button("建立本機玩家", UIKit.CORAL, Color.WHITE, 23, 18, true, Vector2(0, 50))
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_button.pressed.connect(_submit_new)
	parent.add_child(create_button)

	if not _profile.is_empty():
		var back_button := UIKit.ghost_button("返回 · 用返 %s" % str(_profile.get("nickname", "")), UIKit.MUTED, 12, Vector2(0, 32))
		back_button.pressed.connect(func() -> void:
			Sfx.play("click")
			_show_existing(true)
		)
		parent.add_child(back_button)


func _make_line_edit(placeholder: String, max_length: int, secret: bool) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = max_length
	edit.secret = secret
	edit.custom_minimum_size.y = 56
	edit.add_theme_font_override("font", UIKit.font(false))
	edit.add_theme_font_size_override("font_size", UIKit.scaled_font(18))
	edit.add_theme_color_override("font_color", UIKit.INK)
	edit.add_theme_color_override("font_placeholder_color", Color(0.6, 0.56, 0.5, 0.6))
	edit.add_theme_stylebox_override("normal", UIKit.box(UIKit.CREAM, 16, 0, UIKit.LINE, 1, 12))
	edit.add_theme_stylebox_override("focus", UIKit.box(UIKit.SUN_SOFT, 16, 0, UIKit.SUN, 2, 12))
	if secret:
		edit.text_changed.connect(func(text: String) -> void:
			var digits := ""
			for i in range(text.length()):
				var ch := text.substr(i, 1)
				if ch >= "0" and ch <= "9":
					digits += ch
			if digits != text:
				edit.text = digits
				edit.caret_column = digits.length()
		)
	return edit


func _show_existing(existing: bool) -> void:
	if _existing_box != null:
		_existing_box.visible = existing and not _profile.is_empty()
	if _new_box != null:
		_new_box.visible = not existing or _profile.is_empty()
	if _new_name_edit != null and _new_box.visible:
		_new_name_edit.grab_focus.call_deferred()


func _submit_existing() -> void:
	if _profile.is_empty():
		return
	var nickname := str(_profile.get("nickname", ""))
	if ProfileData.profile_has_pin() and not ProfileData.verify_pin(_pin_edit.text):
		_status.text = "PIN 唔啱，再試一次。"
		Sfx.play("burnt")
		return
	_status.text = ""
	Sfx.play("start")
	ProfileData.set_session(nickname)
	login_pressed.emit(nickname)


func _submit_new() -> void:
	if _new_box == null or not _new_box.visible:
		return
	var nickname := _new_name_edit.text.strip_edges()
	if nickname.is_empty():
		_status.text = "改個名先開始。"
		return
	if not _new_pin_edit.text.is_empty() and _new_pin_edit.text.length() != 4:
		_status.text = "PIN 要 4 個數字，或者留空。"
		return
	var profile := ProfileData.save_profile(nickname, _new_pin_edit.text)
	if profile.is_empty():
		_status.text = "儲存唔到，再試一次。"
		return
	_status.text = ""
	Sfx.play("start")
	login_pressed.emit(str(profile.nickname))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		if _existing_box != null and _existing_box.visible:
			_submit_existing()
		else:
			_submit_new()
