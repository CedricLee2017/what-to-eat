class_name StatIcon
extends Control

var key := "body":
	set(value):
		key = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(28, 28)
	resized.connect(queue_redraw)


func set_key(value: String) -> void:
	key = value
	queue_redraw()


func _draw() -> void:
	var color := MealData.stat_color(key)
	var scale_factor := minf(size.x, size.y) / 28.0
	draw_set_transform(size * 0.5, 0.0, Vector2(scale_factor, scale_factor))
	match key:
		"body":
			draw_circle(Vector2(-4.5, -2.5), 6.0, color)
			draw_circle(Vector2(4.5, -2.5), 6.0, color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-10.5, -1.0), Vector2(10.5, -1.0), Vector2(0.0, 11.0),
			]), color)
		"vitc":
			draw_circle(Vector2(0, 2), 10.0, color)
			draw_circle(Vector2(0, 2), 7.2, Color(1, 1, 1, 0.25))
			for i in 6:
				var angle := TAU * float(i) / 6.0
				draw_line(Vector2(0, 2), Vector2(cos(angle) * 8.5, 2.0 + sin(angle) * 8.5), Color(1, 1, 1, 0.55), 1.0, true)
			draw_set_transform(size * 0.5, -0.6, Vector2(scale_factor, scale_factor))
			draw_circle(Vector2(6, -10), 3.6, UIKit.MINT)
		"vitd":
			draw_circle(Vector2(0, 0), 7.5, color)
			for i in 8:
				var angle := TAU * float(i) / 8.0
				draw_line(Vector2(cos(angle) * 10.0, sin(angle) * 10.0), Vector2(cos(angle) * 13.0, sin(angle) * 13.0), color, 2.2, true)
		"fiber":
			draw_set_transform(size * 0.5, -0.7, Vector2(scale_factor, scale_factor * 0.6))
			draw_circle(Vector2(0, 0), 11.0, color)
			draw_set_transform(size * 0.5, 0.0, Vector2(scale_factor, scale_factor))
			draw_line(Vector2(-8, 9), Vector2(7, -8), color.darkened(0.15), 1.6, true)
		"mood":
			draw_circle(Vector2(0, 0), 10.5, color)
			draw_circle(Vector2(-3.6, -2.5), 1.5, UIKit.PAPER)
			draw_circle(Vector2(3.6, -2.5), 1.5, UIKit.PAPER)
			draw_arc(Vector2(0, -0.5), 5.0, 0.2 * PI, 0.8 * PI, 16, UIKit.PAPER, 1.8, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
