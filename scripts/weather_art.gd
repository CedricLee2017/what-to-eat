class_name WeatherArt
extends Control

var kind := "sunny":
	set(value):
		kind = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(32, 32)
	resized.connect(queue_redraw)


func set_kind(value: String) -> void:
	kind = value
	queue_redraw()

func _draw() -> void:
	var scale_factor := minf(size.x, size.y) / 40.0
	draw_set_transform(size * 0.5, 0.0, Vector2(scale_factor, scale_factor))
	match kind:
		"rainy":
			_cloud(Color("#C9D8E2"))
			draw_line(Vector2(-9, 7), Vector2(-12, 14), UIKit.SKY, 2.6, true)
			draw_line(Vector2(0, 8), Vector2(-3, 15), UIKit.SKY, 2.6, true)
			draw_line(Vector2(9, 7), Vector2(6, 14), UIKit.SKY, 2.6, true)
		"cloudy":
			_cloud(Color("#C9D8E2"))
			draw_circle(Vector2(9, -10), 6.0, UIKit.SUN)
		_:
			draw_circle(Vector2(0, 0), 8.5, UIKit.SUN)
			for i in 8:
				var angle := TAU * float(i) / 8.0
				draw_line(Vector2(cos(angle) * 12.0, sin(angle) * 12.0), Vector2(cos(angle) * 17.0, sin(angle) * 17.0), UIKit.SUN, 2.4, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _cloud(color: Color) -> void:
	draw_circle(Vector2(-10, 2), 7.0, color)
	draw_circle(Vector2(0, -2), 9.0, color)
	draw_circle(Vector2(10, 2), 7.0, color)
	var box := UIKit.box(color, 8)
	draw_style_box(box, Rect2(-15, 1, 30, 9))
