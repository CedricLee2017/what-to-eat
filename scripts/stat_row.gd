class_name StatRow
extends HBoxContainer

var show_delta := false

var _icon: StatIcon
var _name_label: Label
var _bar: ProgressBar
var _value_label: Label
var _delta_label: Label


func _init(key: String = "body", with_delta: bool = false) -> void:
	show_delta = with_delta
	custom_minimum_size = Vector2(0, 42)
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_icon = StatIcon.new()
	_icon.key = key
	_icon.custom_minimum_size = Vector2(28, 28)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_icon)

	_name_label = UIKit.label(MealData.STATS[key].name, 18, UIKit.INK, false)
	_name_label.custom_minimum_size.x = 90
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_name_label)

	_bar = ProgressBar.new()
	_bar.max_value = 100.0
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 10
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", UIKit.box(UIKit.SAND, 6))
	_bar.add_theme_stylebox_override("fill", UIKit.box(MealData.stat_color(key), 6))
	add_child(_bar)

	_value_label = UIKit.label("60", 18, UIKit.INK, true)
	_value_label.custom_minimum_size.x = 42
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_value_label)

	if show_delta:
		_delta_label = UIKit.label("", 16, UIKit.MINT, true)
		_delta_label.custom_minimum_size.x = 52
		_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_delta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_delta_label)


func set_values(value: float, delta: float = NAN, animate: bool = false) -> void:
	if animate:
		var tween := create_tween()
		tween.tween_property(_bar, "value", value, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_bar.value = value
	_value_label.text = str(int(round(value)))
	if _delta_label != null:
		if is_nan(delta):
			_delta_label.text = ""
		elif delta > 0.0:
			_delta_label.text = "+%d" % int(round(delta))
			_delta_label.add_theme_color_override("font_color", UIKit.MINT)
		elif delta < 0.0:
			_delta_label.text = "%d" % int(round(delta))
			_delta_label.add_theme_color_override("font_color", UIKit.CORAL)
		else:
			_delta_label.text = "±0"
			_delta_label.add_theme_color_override("font_color", UIKit.MUTED)
