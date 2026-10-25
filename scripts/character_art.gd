class_name CharacterArt
extends Control

## 用簡單幾何圖形畫嘅無職主角。會呼吸、眨眼、笑，煮得完美會彈起。

var mood := 0.6
var _time := 0.0
var _blink := 2.8
var _cheer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(180, 280)
	resized.connect(queue_redraw)
	set_process(true)


func cheer() -> void:
	_cheer = 1.1
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_blink -= delta
	if _blink <= 0.0:
		_blink = 3.4 + fmod(_time * 7.3, 1.7)
	if _cheer > 0.0:
		_cheer = maxf(0.0, _cheer - delta)
	queue_redraw()


func _draw() -> void:
	var scale_factor := minf(size.x / 200.0, size.y / 330.0)
	var bob := sin(_time * 1.7) * 2.2
	var jump := 0.0
	if _cheer > 0.0:
		jump = -sin((1.0 - _cheer / 1.1) * PI) * 11.0
	var origin := Vector2(size.x * 0.5, size.y * 0.5 + 6.0 + bob + jump)

	# 地面影
	draw_set_transform(Vector2(size.x * 0.5, size.y - 10.0), 0.0, Vector2(scale_factor, scale_factor * 0.24))
	draw_circle(Vector2.ZERO, 72.0, Color(0.3, 0.24, 0.18, 0.09))
	draw_set_transform(origin, 0.0, Vector2(scale_factor, scale_factor))

	var hoodie := Color("#7FC3A0")
	var hoodie_dark := Color("#69AE8C")
	var skin := Color("#F6D7B8")
	var skin_dark := Color("#EAC4A3")
	var hair := Color("#4A3A2F")
	var ink := Color("#3F3A34")

	# 頸
	var neck := UIKit.box(skin_dark, 10)
	draw_style_box(neck, Rect2(-15, -14, 30, 34))

	# 身體
	var body := UIKit.box(hoodie, 36)
	draw_style_box(body, Rect2(-70, 6, 140, 126))
	var pocket := UIKit.box(hoodie_dark, 16)
	draw_style_box(pocket, Rect2(-32, 76, 64, 30))

	# 手
	draw_circle(Vector2(-68, 60), 23.0, hoodie)
	draw_circle(Vector2(68, 60), 23.0, hoodie)
	draw_circle(Vector2(-68, 86), 12.0, skin)
	draw_circle(Vector2(68, 86), 12.0, skin)

	# 頭
	draw_circle(Vector2(-58, -62), 12.0, skin_dark)
	draw_circle(Vector2(58, -62), 12.0, skin_dark)
	draw_circle(Vector2(0, -64), 62.0, skin)

	# 頭髮
	draw_circle(Vector2(-56, -64), 19.0, hair)
	draw_circle(Vector2(56, -64), 19.0, hair)
	draw_circle(Vector2(-33, -92), 30.0, hair)
	draw_circle(Vector2(0, -100), 35.0, hair)
	draw_circle(Vector2(33, -92), 30.0, hair)

	# 眼
	var blinking := _blink < 0.1
	if blinking:
		draw_line(Vector2(-29, -60), Vector2(-15, -60), ink, 3.0, true)
		draw_line(Vector2(15, -60), Vector2(29, -60), ink, 3.0, true)
	else:
		draw_circle(Vector2(-21, -59), 4.6, ink)
		draw_circle(Vector2(21, -59), 4.6, ink)
		draw_circle(Vector2(-19, -61), 1.6, Color(1, 1, 1, 0.8))
		draw_circle(Vector2(23, -61), 1.6, Color(1, 1, 1, 0.8))

	# 腮紅
	draw_circle(Vector2(-37, -44), 7.5, Color(0.94, 0.55, 0.48, 0.35))
	draw_circle(Vector2(37, -44), 7.5, Color(0.94, 0.55, 0.48, 0.35))

	# 嘴
	if mood >= 0.5:
		draw_arc(Vector2(0, -40), 14.0, 0.2 * PI, 0.8 * PI, 18, ink, 3.0, true)
	elif mood >= 0.32:
		draw_line(Vector2(-9, -36), Vector2(9, -36), ink, 2.6, true)
	else:
		draw_arc(Vector2(0, -28), 13.0, 1.2 * PI, 1.8 * PI, 18, ink, 3.0, true)

	# 碗
	var bowl := UIKit.box(Color("#FFFDF8"), 20)
	draw_style_box(bowl, Rect2(-58, 84, 116, 42))
	draw_set_transform(origin + Vector2(0, 84), 0.0, Vector2(scale_factor, scale_factor * 0.42))
	draw_circle(Vector2.ZERO, 46.0, Color("#F7E8C9"))
	draw_set_transform(origin, 0.0, Vector2(scale_factor, scale_factor))
	draw_circle(Vector2(-18, 82), 9.0, UIKit.CORAL)
	draw_circle(Vector2(13, 80), 8.0, UIKit.MINT)
	draw_circle(Vector2(0, 88), 6.0, UIKit.SUN)

	# 蒸氣
	for i in 3:
		var x := -16.0 + float(i) * 16.0
		draw_arc(Vector2(x, 62), 7.0, 1.2 * PI, 1.85 * PI, 10, Color(0.45, 0.4, 0.35, 0.35), 2.0, true)

	# 開心火花
	if _cheer > 0.0:
		var alpha := minf(1.0, _cheer * 2.5)
		_sparkle(Vector2(-92, -94), 8.0, Color(0.94, 0.73, 0.3, alpha))
		_sparkle(Vector2(90, -72), 6.0, Color(0.94, 0.45, 0.36, alpha))
		_sparkle(Vector2(76, -116), 5.0, Color(0.44, 0.72, 0.58, alpha))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sparkle(center: Vector2, radius: float, color: Color) -> void:
	draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, 2.4, true)
	draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), color, 2.4, true)
