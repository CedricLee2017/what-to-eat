class_name CrownBadge
extends Control

## 細細個王冠列：1 銅冠、2 銀冠、3 金冠、4 彩虹冠。

var level := 0:
	set(value):
		level = clampi(value, 0, 4)
		visible = level > 0
		custom_minimum_size = Vector2(14.0 * float(level), 17) if level > 0 else Vector2.ZERO
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO and level > 0:
		custom_minimum_size = Vector2(14.0 * float(level), 17)
	resized.connect(queue_redraw)


func _draw() -> void:
	if level <= 0:
		return
	for i in range(level):
		var crown_color := FoodBook.crown_color(level)
		if level >= 4:
			crown_color = FoodBook.CROWN_COLORS[1 + (i % 4)]
		_draw_crown(Vector2(float(i) * 14.0, 1.0), 12.0, 15.0, crown_color)


func _draw_crown(pos: Vector2, width: float, height: float, color: Color) -> void:
	var base_y := pos.y + height - 2.0
	draw_rect(Rect2(pos.x + 1.0, base_y - 3.0, width - 2.0, 3.0), color)
	var points := PackedVector2Array([
		Vector2(pos.x, base_y - 3.0),
		Vector2(pos.x + 1.0, pos.y + 4.0),
		Vector2(pos.x + width * 0.28, pos.y + 7.0),
		Vector2(pos.x + width * 0.5, pos.y),
		Vector2(pos.x + width * 0.72, pos.y + 7.0),
		Vector2(pos.x + width - 1.0, pos.y + 4.0),
		Vector2(pos.x + width, base_y - 3.0),
	])
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.22, 0.16, 0.10, 0.32), 1.0, true)
	draw_circle(Vector2(pos.x + width * 0.5, pos.y + 4.0), 1.4, Color(1, 1, 1, 0.5))
