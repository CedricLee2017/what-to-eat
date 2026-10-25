class_name Backdrop
extends Control

## 奶油色底 + 幾粒大色塊，超簡約但有溫度。


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UIKit.CREAM)
	draw_circle(Vector2(size.x * 1.04, -20), 300.0, Color(0.44, 0.72, 0.58, 0.13))
	draw_circle(Vector2(-80, size.y * 0.9), 330.0, Color(0.94, 0.45, 0.36, 0.09))
	draw_circle(Vector2(size.x * 0.94, size.y * 0.62), 190.0, Color(0.94, 0.73, 0.3, 0.08))

	var random := RandomNumberGenerator.new()
	random.seed = 77
	for i in 40:
		var point := Vector2(random.randf_range(0.0, size.x), random.randf_range(0.0, size.y))
		draw_circle(point, random.randf_range(1.2, 2.8), Color(0.24, 0.2, 0.16, 0.04))
