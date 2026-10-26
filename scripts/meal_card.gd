class_name MealCard
extends Button

## 主畫面其中一餐嘅卡片：空白時叫你去煮，煮完顯示菜式同評分。

var slot := 0

var _food: DishArt
var _name_label: Label
var _footer_label: Label
var _tag_label: Label
var _crowns: CrownBadge

const SLOT_COLORS := [
	{"bg": Color("#FFF0CC"), "fg": Color("#A97716")},
	{"bg": Color("#DFF1E7"), "fg": Color("#3F7D5F")},
	{"bg": Color("#E2EFF8"), "fg": Color("#3F6E92")},
]


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 230)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = false
	text = ""

	add_theme_stylebox_override("normal", UIKit.box(UIKit.PAPER, 26, 6))
	add_theme_stylebox_override("hover", UIKit.box(UIKit.PAPER.lightened(0.03), 26, 10))
	add_theme_stylebox_override("pressed", UIKit.box(UIKit.SAND.lightened(0.25), 26, 4))
	add_theme_stylebox_override("disabled", UIKit.box(UIKit.PAPER, 26, 6))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)

	var pill := UIKit.panel(SLOT_COLORS[slot].bg, 999, 0, Color.TRANSPARENT, 0, 0)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_margin := MarginContainer.new()
	pill_margin.add_theme_constant_override("margin_left", 10)
	pill_margin.add_theme_constant_override("margin_right", 10)
	pill_margin.add_theme_constant_override("margin_top", 4)
	pill_margin.add_theme_constant_override("margin_bottom", 4)
	pill_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_label := UIKit.label(MealData.MEAL_NAMES[slot], 13, SLOT_COLORS[slot].fg, true)
	pill_margin.add_child(pill_label)
	pill.add_child(pill_margin)
	header.add_child(pill)
	header.add_child(UIKit.spacer_h())

	_crowns = CrownBadge.new()
	_crowns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_crowns)

	_tag_label = UIKit.label("", 12, UIKit.MUTED, true)
	_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_tag_label)

	_food = DishArt.new()
	_food.custom_minimum_size = Vector2(88, 88)
	_food.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_food.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_food)

	_name_label = UIKit.wrapped("未煮", 19, UIKit.MUTED, true)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.max_lines_visible = 2
	_name_label.custom_minimum_size.y = 50
	box.add_child(_name_label)

	_footer_label = UIKit.label("撳一下煮飯", 12, UIKit.MUTED, false)
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_footer_label)


func refresh(record) -> void:
	if record == null or record.is_empty():
		disabled = false
		_food.recipe_id = ""
		_food.recipe_data = {}
		_food.burnt = false
		_crowns.level = 0
		_name_label.text = "未煮"
		_name_label.add_theme_color_override("font_color", UIKit.MUTED)
		_footer_label.text = "撳一下煮飯"
		_footer_label.add_theme_color_override("font_color", UIKit.MUTED)
		_tag_label.text = "＋"
		_tag_label.add_theme_color_override("font_color", SLOT_COLORS[slot].fg)
		tooltip_text = ""
		return

	var recipe := MealData.recipe(record.recipe_id)
	var quality := MealData.quality(record.quality)
	var method := MealData.method_info(MealData.method_of(recipe))
	disabled = true
	_food.recipe_id = record.recipe_id
	_food.burnt = record.quality == "burnt"
	_crowns.level = FoodBook.crown_level_for_recipe(str(record.recipe_id))
	_name_label.text = str(recipe.name)
	_name_label.add_theme_color_override("font_color", UIKit.INK)
	_footer_label.text = "%s · %s · %s" % [method.name, quality.name, "雪櫃" if int(record.cost) == 0 and not record.get("fridge_used", {}).is_empty() else "$%d" % int(record.cost)]
	var quality_color := UIKit.MUTED
	if record.quality == "perfect":
		quality_color = UIKit.MINT
	elif record.quality == "burnt":
		quality_color = UIKit.BROWN
	_footer_label.add_theme_color_override("font_color", quality_color)
	_tag_label.text = str(method.name)
	_tag_label.add_theme_color_override("font_color", Color(method.color))
	tooltip_text = MealData.item_names(recipe)
