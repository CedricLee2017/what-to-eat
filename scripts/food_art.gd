class_name FoodArt
extends Control

## 把每道菜畫成一隻極簡碟／碗／杯／多士／鑊。

var recipe_id := "":
	set(value):
		recipe_id = value
		queue_redraw()
var recipe_data: Dictionary = {}:
	set(value):
		recipe_data = value
		queue_redraw()
var burnt := false:
	set(value):
		burnt = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(80, 80)
	resized.connect(queue_redraw)


func _draw() -> void:
	var scale_factor := minf(size.x, size.y) / 200.0
	var center := size * 0.5
	draw_set_transform(center + Vector2(0, 74.0 * scale_factor * 0.5), 0.0, Vector2(scale_factor, scale_factor * 0.24))
	draw_circle(Vector2.ZERO, 74.0, Color(0.3, 0.24, 0.18, 0.08))
	draw_set_transform(center, 0.0, Vector2(scale_factor, scale_factor))

	if recipe_id.is_empty() and recipe_data.is_empty():
		_empty_plate()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var recipe := recipe_data if not recipe_data.is_empty() else MealData.recipe(recipe_id)
	if recipe.is_empty():
		_empty_plate()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var colors := _colors(recipe)
	var method := MealData.method_of(recipe)
	match method:
		"pan_fry":
			_pan_vessel(colors)
		"deep_fry":
			_fryer_vessel(colors)
		"braise":
			_clay_pot_vessel(colors)
		"stew":
			_soup_pot_vessel(colors)
		"bake":
			_oven_vessel(colors)
		"steam":
			_steamer_vessel(colors)
		_:
			match str(recipe.form):
				"bowl":
					_bowl(colors)
				"toast":
					_toast(colors)
				"cup":
					_cup(colors)
				"pan":
					_pan(colors)
				_:
					_plate(colors)
	if burnt:
		_burn_marks()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _colors(recipe: Dictionary) -> Array:
	var result: Array = []
	for hex in recipe.get("colors", []):
		var color := Color(hex)
		if burnt:
			color = color.darkened(0.38)
		result.append(color)
	while result.size() < 3:
		result.append(UIKit.SAND)
	return result


func _plate(colors: Array) -> void:
	draw_circle(Vector2.ZERO, 78.0, UIKit.PAPER)
	draw_circle(Vector2.ZERO, 61.0, Color("#F2E7D3"))
	draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 64, Color(1, 1, 1, 0.8), 2.0, true)
	draw_circle(Vector2(-25, -14), 26.0, colors[0])
	draw_circle(Vector2(24, -8), 22.0, colors[1])
	draw_circle(Vector2(2, 25), 19.0, colors[2])
	draw_circle(Vector2(-6, 4), 5.0, Color(1, 1, 1, 0.25))
	_garnish(colors)


func _bowl(colors: Array) -> void:
	draw_circle(Vector2.ZERO, 78.0, UIKit.PAPER)
	draw_circle(Vector2(0, 4), 62.0, Color("#F2E7D3"))
	draw_circle(Vector2(0, 4), 52.0, colors[0])
	draw_arc(Vector2(0, 4), 52.0, 0.0, TAU, 64, Color(1, 1, 1, 0.55), 5.0, true)
	draw_circle(Vector2(-20, -3), 15.0, colors[1])
	draw_circle(Vector2(22, 12), 12.0, colors[2])
	draw_circle(Vector2(16, -16), 8.0, colors[1])
	draw_arc(Vector2(0, -22), 30.0, 1.15 * PI, 1.85 * PI, 20, Color(1, 1, 1, 0.35), 2.5, true)
	_garnish(colors)


func _toast(colors: Array) -> void:
	var crust := UIKit.box(colors[0].darkened(0.12), 22, 0, colors[0].darkened(0.24), 3)
	draw_style_box(crust, Rect2(-76, -48, 78, 94))
	draw_style_box(crust, Rect2(-2, -40, 78, 94))
	var inner := UIKit.box(colors[2], 18)
	draw_style_box(inner, Rect2(-68, -40, 62, 78))
	draw_style_box(inner, Rect2(6, -32, 62, 78))
	# 太陽蛋
	draw_circle(Vector2(-37, -2), 21.0, UIKit.PAPER)
	draw_circle(Vector2(-37, -2), 10.0, UIKit.SUN)
	# 香蕉片
	draw_circle(Vector2(27, -6), 10.0, colors[1])
	draw_circle(Vector2(46, 6), 9.0, colors[1])
	draw_circle(Vector2(30, 22), 8.0, colors[1])
	draw_circle(Vector2(27, -6), 3.0, colors[1].darkened(0.12))
	draw_circle(Vector2(46, 6), 3.0, colors[1].darkened(0.12))
	draw_circle(Vector2(30, 22), 3.0, colors[1].darkened(0.12))


func _cup(colors: Array) -> void:
	var glass := UIKit.box(Color(1, 1, 1, 0.92), 24, 0, Color("#E8DDCB"), 3)
	draw_style_box(glass, Rect2(-42, -58, 84, 120))
	draw_circle(Vector2(0, 44), 34.0, colors[2])
	var fill := UIKit.box(colors[1], 18)
	draw_style_box(fill, Rect2(-36, 12, 72, 44))
	draw_circle(Vector2(-16, 8), 11.0, colors[0])
	draw_circle(Vector2(13, 3), 10.0, colors[0])
	draw_circle(Vector2(2, 26), 10.0, colors[0])
	draw_circle(Vector2(-16, 8), 3.0, colors[0].darkened(0.12))
	draw_circle(Vector2(13, 3), 3.0, colors[0].darkened(0.12))
	draw_arc(Vector2(0, 62), 34.0, 0.0, PI, 24, UIKit.LINE, 3.0, true)
	draw_line(Vector2(24, -54), Vector2(34, -86), UIKit.CORAL, 6.0, true)


func _pan(colors: Array) -> void:
	var handle := UIKit.box(Color("#57504A"), 10)
	draw_style_box(handle, Rect2(46, -9, 64, 18))
	draw_circle(Vector2(-10, 4), 62.0, Color("#4A443F"))
	draw_circle(Vector2(-10, 4), 54.0, Color("#6B635B"))
	draw_circle(Vector2(-24, -9), 24.0, colors[0])
	draw_circle(Vector2(15, 6), 19.0, colors[1])
	draw_circle(Vector2(-16, 25), 15.0, colors[2])
	draw_circle(Vector2(-30, -14), 4.0, Color(1, 1, 1, 0.18))
	_garnish(colors)


func _oval(center: Vector2, radius_x: float, radius_y: float, color: Color, points: int = 28) -> void:
	var polygon := PackedVector2Array()
	for i in range(points):
		var angle := TAU * float(i) / float(points)
		polygon.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(polygon, color)


func _pan_vessel(colors: Array) -> void:
	for i in range(4):
		_oval(Vector2(-54.0 + 36.0 * float(i), 54), 13, 9, Color(0.95, 0.55, 0.25, 0.42))
	draw_line(Vector2(48, -12), Vector2(110, -46), Color("#4A443F"), 12.0, true)
	draw_circle(Vector2(110, -46), 7.0, Color("#4A443F"))
	_oval(Vector2(-8, 8), 68, 60, Color("#4A443F"))
	_oval(Vector2(-8, 4), 59, 51, Color("#6B635B"))
	_oval(Vector2(-8, 4), 48, 41, Color("#8A8178"))
	_oval(Vector2(-32, -8), 25, 19, colors[0])
	_oval(Vector2(14, -10), 22, 17, colors[1])
	_oval(Vector2(-2, 22), 19, 14, colors[2])
	draw_circle(Vector2(-39, -15), 4.0, Color(1, 1, 1, 0.28))
	for i in range(3):
		var offset := float(i) * 9.0
		draw_arc(Vector2(-7.0 + offset, -62), 12, 0.4, 2.7, 12, Color(1, 1, 1, 0.48), 2.5, true)
	_garnish(colors)


func _fryer_vessel(colors: Array) -> void:
	_oval(Vector2(0, 62), 70, 12, Color(0.3, 0.24, 0.18, 0.10))
	draw_line(Vector2(-34, -52), Vector2(-16, -8), Color("#7A7168"), 6.0, true)
	draw_line(Vector2(34, -52), Vector2(16, -8), Color("#7A7168"), 6.0, true)
	var pot := PackedVector2Array([Vector2(-62, -4), Vector2(62, -4), Vector2(54, 52), Vector2(-54, 52)])
	draw_colored_polygon(pot, Color("#5A544E"))
	_oval(Vector2(0, -4), 62, 18, Color("#6B635B"))
	_oval(Vector2(0, -4), 54, 14, Color("#E8B44A"))
	draw_arc(Vector2(0, -4), 54, 0, TAU, 40, Color(1, 1, 1, 0.24), 2.0, true)
	for i in range(4):
		var angle := TAU * float(i) / 4.0 + 0.4
		draw_circle(Vector2(cos(angle) * 36.0, -4 + sin(angle) * 9.0), 3.0, Color(1, 1, 1, 0.35))
	for i in range(3):
		var x := -32.0 + 32.0 * float(i)
		draw_circle(Vector2(x, -6.0 + float(i % 2) * 7.0), 13.0, colors[i % colors.size()])
		draw_circle(Vector2(x, -6.0 + float(i % 2) * 7.0), 8.0, colors[i % colors.size()].lightened(0.16))
	for i in range(3):
		var offset := float(i) * 9.0
		draw_arc(Vector2(-16.0 + offset, -66), 12, 0.4, 2.7, 12, Color(1, 1, 1, 0.45), 2.5, true)


func _clay_pot_vessel(colors: Array) -> void:
	_oval(Vector2(0, 66), 72, 12, Color(0.3, 0.24, 0.18, 0.10))
	draw_line(Vector2(-62, -14), Vector2(-78, 4), UIKit.BROWN, 8.0, true)
	draw_line(Vector2(62, -14), Vector2(78, 4), UIKit.BROWN, 8.0, true)
	_oval(Vector2(0, 22), 64, 48, Color("#8B5E3C"))
	_oval(Vector2(0, 10), 62, 42, Color("#A06C45"))
	_oval(Vector2(0, 6), 52, 33, colors[0].darkened(0.06))
	_oval(Vector2(-20, 2), 17, 12, colors[1])
	_oval(Vector2(18, 10), 15, 11, colors[2])
	_oval(Vector2(0, -30), 46, 18, Color("#B0764F"))
	draw_circle(Vector2(0, -46), 9.0, Color("#8B5E3C"))
	for i in range(3):
		var offset := sin(float(i) * 1.7) * 6.0
		draw_arc(Vector2(-24.0 + 24.0 * float(i) + offset, -62), 11, 0.4, 2.7, 12, Color(1, 1, 1, 0.5), 2.5, true)
	_garnish(colors)


func _soup_pot_vessel(colors: Array) -> void:
	_oval(Vector2(0, 66), 72, 12, Color(0.3, 0.24, 0.18, 0.10))
	draw_line(Vector2(-62, -12), Vector2(-78, 8), Color("#5F7F96"), 8.0, true)
	draw_line(Vector2(62, -12), Vector2(78, 8), Color("#5F7F96"), 8.0, true)
	var pot := PackedVector2Array([Vector2(-64, -24), Vector2(64, -24), Vector2(56, 52), Vector2(-56, 52)])
	draw_colored_polygon(pot, Color("#6FA8D6"))
	_oval(Vector2(0, -24), 64, 20, Color("#8FBBDD"))
	_oval(Vector2(0, -24), 55, 16, colors[0].darkened(0.04))
	_oval(Vector2(-22, -26), 15, 9, colors[1])
	_oval(Vector2(18, -20), 13, 8, colors[2])
	_oval(Vector2(2, -30), 9, 6, colors[1].lightened(0.12))
	for i in range(3):
		var offset := sin(float(i) * 1.4) * 7.0
		draw_arc(Vector2(-22.0 + 22.0 * float(i) + offset, -54), 11, 0.4, 2.7, 12, Color(1, 1, 1, 0.48), 2.5, true)
	_garnish(colors)


func _oven_vessel(colors: Array) -> void:
	_oval(Vector2(0, 66), 74, 12, Color(0.3, 0.24, 0.18, 0.10))
	draw_line(Vector2(-62, 20), Vector2(-82, 20), Color("#8A8178"), 9.0, true)
	draw_line(Vector2(62, 20), Vector2(82, 20), Color("#8A8178"), 9.0, true)
	draw_style_box(UIKit.box(Color("#8A8178"), 14, 0, Color("#6B635B"), 3), Rect2(-66, -22, 132, 82))
	draw_style_box(UIKit.box(Color("#E8C58C"), 10), Rect2(-56, -14, 112, 62))
	_oval(Vector2(-18, 2), 30, 20, colors[0])
	_oval(Vector2(22, 8), 26, 19, colors[1])
	_oval(Vector2(0, 24), 22, 14, colors[2])
	draw_circle(Vector2(-24, -6), 8.0, Color(1, 0.94, 0.72, 0.75))
	draw_circle(Vector2(16, -2), 6.0, Color(1, 0.94, 0.72, 0.70))
	draw_circle(Vector2(4, 18), 5.0, Color(1, 0.94, 0.72, 0.65))
	for i in range(3):
		var offset := sin(float(i) * 1.8 + 0.3) * 7.0
		draw_arc(Vector2(-26.0 + 26.0 * float(i) + offset, -44), 12, 0.4, 2.7, 12, Color(1, 1, 1, 0.48), 2.5, true)
	_garnish(colors)


func _steamer_vessel(colors: Array) -> void:
	_oval(Vector2(0, 68), 72, 12, Color(0.3, 0.24, 0.18, 0.10))
	draw_style_box(UIKit.box(Color("#D9B87A"), 14, 0, Color("#B58A5C"), 2), Rect2(-64, 2, 128, 30))
	draw_style_box(UIKit.box(Color("#D9B87A"), 14, 0, Color("#B58A5C"), 2), Rect2(-64, 26, 128, 30))
	for i in range(5):
		draw_line(Vector2(-48.0 + 24.0 * float(i), 6), Vector2(-48.0 + 24.0 * float(i), 24), Color(1, 1, 1, 0.20), 2.0)
		draw_line(Vector2(-48.0 + 24.0 * float(i), 30), Vector2(-48.0 + 24.0 * float(i), 50), Color(1, 1, 1, 0.20), 2.0)
	_oval(Vector2(0, 2), 64, 17, Color("#E8C58C"))
	_oval(Vector2(-20, 0), 20, 9, colors[0])
	_oval(Vector2(18, 2), 17, 8, colors[1])
	_oval(Vector2(0, -8), 13, 7, colors[2])
	draw_circle(Vector2(0, -14), 8.0, Color("#B58A5C"))
	for i in range(3):
		var offset := sin(float(i) * 1.5) * 8.0
		draw_arc(Vector2(-22.0 + 22.0 * float(i) + offset, -38), 12, 0.4, 2.7, 12, Color(1, 1, 1, 0.52), 2.5, true)
	_garnish(colors)


func _empty_plate() -> void:
	draw_circle(Vector2.ZERO, 76.0, Color(1, 1, 1, 0.55))
	draw_circle(Vector2.ZERO, 58.0, Color(0.95, 0.9, 0.82, 0.5))
	draw_arc(Vector2.ZERO, 74.0, 0.0, TAU, 64, UIKit.LINE, 2.0, true)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		draw_circle(Vector2(cos(angle) * 35.0, sin(angle) * 35.0), 2.0, Color(0.55, 0.5, 0.44, 0.28))
	draw_line(Vector2(-13, 0), Vector2(13, 0), UIKit.MUTED, 4.0, true)
	draw_line(Vector2(0, -13), Vector2(0, 13), UIKit.MUTED, 4.0, true)


func _garnish(colors: Array) -> void:
	var accent := UIKit.MINT if colors[1].g > colors[1].r else UIKit.CORAL
	draw_circle(Vector2(-38, 42), 4.0, accent)
	draw_circle(Vector2(46, -36), 3.0, accent)
	draw_circle(Vector2(36, 45), 2.4, UIKit.SUN)


func _burn_marks() -> void:
	for point in [Vector2(-18, -6), Vector2(22, 14), Vector2(4, -30)]:
		draw_circle(point, 6.0, Color(0.2, 0.13, 0.08, 0.5))
	draw_circle(Vector2(-32, 20), 3.0, Color(0.2, 0.13, 0.08, 0.4))
