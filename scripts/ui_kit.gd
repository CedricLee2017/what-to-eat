class_name UIKit
extends RefCounted

## 極簡超休閒風格嘅共用 UI 工具：顏色、字型、圓角卡片、按鈕。

static var CREAM := Color("#FBF4E6")
static var PAPER := Color("#FFFDF8")
static var INK := Color("#3F3A34")
static var MUTED := Color("#8C857A")
static var LINE := Color("#EDE2D0")
static var CORAL := Color("#EF745E")
static var CORAL_SOFT := Color("#FFE3DA")
static var MINT := Color("#6FB794")
static var MINT_SOFT := Color("#DFF1E7")
static var SUN := Color("#F0B94A")
static var SUN_SOFT := Color("#FFF0CC")
static var SKY := Color("#6FA8D6")
static var SKY_SOFT := Color("#E2EFF8")
static var GRAPE := Color("#A78BC8")
static var GRAPE_SOFT := Color("#EEE7F6")
static var SAND := Color("#F3E6CE")
static var BROWN := Color("#9A6B4A")

static var font_regular: Font
static var font_bold: Font


static func setup() -> void:
	if font_regular == null:
		font_regular = load("res://assets/fonts/NotoSansTC-Regular.ttf")
		font_bold = load("res://assets/fonts/NotoSansTC-Bold.ttf")


static func font(bold: bool = false) -> Font:
	setup()
	return font_bold if bold else font_regular


static func make_theme() -> Theme:
	setup()
	var theme := Theme.new()
	theme.default_font = font_regular
	theme.default_font_size = 20
	return theme


static func box(bg: Color, radius: int = 24, shadow: int = 0, border: Color = Color.TRANSPARENT, border_width: int = 0, pad: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.anti_aliasing = true
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border_width > 0:
		sb.border_color = border
		sb.border_width_left = border_width
		sb.border_width_top = border_width
		sb.border_width_right = border_width
		sb.border_width_bottom = border_width
	if shadow > 0:
		sb.shadow_color = Color(0.25, 0.2, 0.14, 0.08)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


static func label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font(bold))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func wrapped(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := label(text, size, color, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func panel(bg: Color, radius: int = 24, shadow: int = 0, border: Color = Color.TRANSPARENT, border_width: int = 0, pad: int = 0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(bg, radius, shadow, border, border_width, pad))
	return panel


static func button(text: String, bg: Color, fg: Color, radius: int = 22, size: int = 22, bold: bool = true, min_size: Vector2 = Vector2.ZERO) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = min_size
	node.add_theme_font_override("font", font(bold))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", fg)
	node.add_theme_color_override("font_hover_color", fg)
	node.add_theme_color_override("font_pressed_color", fg)
	node.add_theme_color_override("font_disabled_color", fg)
	node.add_theme_stylebox_override("normal", box(bg, radius, 0, Color.TRANSPARENT, 0, 18))
	node.add_theme_stylebox_override("hover", box(bg.lightened(0.05), radius, 0, Color.TRANSPARENT, 0, 18))
	node.add_theme_stylebox_override("pressed", box(bg.darkened(0.06), radius, 0, Color.TRANSPARENT, 0, 18))
	node.add_theme_stylebox_override("disabled", box(bg, radius, 0, Color.TRANSPARENT, 0, 18))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return node


static func ghost_button(text: String, fg: Color, size: int = 20, min_size: Vector2 = Vector2.ZERO) -> Button:
	var node := button(text, Color(1, 1, 1, 0), fg, 18, size, true, min_size)
	node.add_theme_stylebox_override("normal", box(Color(1, 1, 1, 0), 18))
	node.add_theme_stylebox_override("hover", box(Color(1, 1, 1, 0.55), 18))
	node.add_theme_stylebox_override("pressed", box(Color(1, 1, 1, 0.35), 18))
	return node


static func pill(text: String, bg: Color, fg: Color, size: int = 14, bold: bool = true) -> PanelContainer:
	var container := panel(bg, 999, 0, Color.TRANSPARENT, 0, 0)
	var label := label(text, size, fg, bold)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.add_child(label)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(margin)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return container


static func set_margins(node: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	if node != null:
		margin.add_child(node)
	return margin


static func spacer_h() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


static func spacer_v() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


static func gap(width: float, height: float) -> Control:
	var gap_node := Control.new()
	gap_node.custom_minimum_size = Vector2(width, height)
	gap_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap_node


static func ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)
