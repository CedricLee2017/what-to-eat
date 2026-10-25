class_name CookMethodGame
extends Control

## 六種煮法，六種完全唔同嘅操作：
## 煎 = 按住升溫、放手起鍋；炸 = 三件輪流撳金黃圈；
## 炆 = 拖住火候；燉 = 記住落料次序；焗 = 較溫度再入爐；蒸 = 捉蒸氣節奏。

signal judged(quality: String)

const GAME_W := 600.0
const GAME_H := 300.0

var method_id := "pan_fry"
var colors: Array = []
var items: Array = []
var running := true

var _done := false
var _t := 0.0
var _hint := ""

# 煎
var _power := 0.0
var _holding := false

# 炸
var _pieces: Array = []

# 炆
var _knob := 0.18
var _target := 0.5
var _braise_score := 0.0
var _braise_ticks := 0.0
var _braise_done := false
var _left_held := false
var _right_held := false
var _dragging := false

# 燉
var _order: Array = []
var _stew_expected := 0
var _stew_mistakes := 0
var _stew_elapsed := 0.0
var _stew_flash := 0.0
var _stew_flash_ok := true

# 焗
var _temp := 138.0
var _dragging_dial := false

# 蒸
var _puff := 0.86
var _puff_dir := -1.0
var _steam_hits := 0
var _steam_attempts := 0
var _steam_flash := 0.0
var _steam_flash_ok := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(0, 280)
	resized.connect(queue_redraw)
	_reset()


func _reset() -> void:
	match method_id:
		"pan_fry":
			_power = 0.0
			_holding = false
			_hint = str(MealData.method_info(method_id).action)
		"deep_fry":
			_pieces = [
				{"t": 0.0, "speed": 0.52, "done": false, "score": 0.0, "pos": Vector2(-150, 6)},
				{"t": 0.10, "speed": 0.62, "done": false, "score": 0.0, "pos": Vector2(-8, -16)},
				{"t": 0.22, "speed": 0.46, "done": false, "score": 0.0, "pos": Vector2(142, 10)},
			]
			_hint = str(MealData.method_info(method_id).action)
		"braise":
			_knob = 0.18
			_target = 0.5
			_braise_score = 0.0
			_braise_ticks = 0.0
			_braise_done = false
			_dragging = false
			_hint = str(MealData.method_info(method_id).action)
		"stew":
			_stew_expected = 0
			_stew_mistakes = 0
			_stew_elapsed = 0.0
			_stew_flash = 0.0
			_order = _make_order(_stew_tile_count())
			_hint = str(MealData.method_info(method_id).action)
		"bake":
			_temp = 138.0
			_dragging_dial = false
			_hint = str(MealData.method_info(method_id).action)
		"steam":
			_puff = 0.05
			_puff_dir = 1.0
			_steam_hits = 0
			_steam_attempts = 0
			_steam_flash = 0.0
			_hint = str(MealData.method_info(method_id).action)
	queue_redraw()


func _make_order(count: int = 3) -> Array:
	var order: Array = []
	for i in range(count):
		order.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_usec()) + int(Time.get_unix_time_from_system())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = order[i]
		order[i] = order[j]
		order[j] = temp
	return order


func _stew_tile_count() -> int:
	if items.is_empty():
		return 3
	return clampi(items.size(), 1, 3)


func _stew_centers() -> Array:
	var count := _stew_tile_count()
	if count <= 1:
		return [0.0]
	if count == 2:
		return [-112.0, 112.0]
	return [-180.0, 0.0, 180.0]


func _stew_tile_width() -> float:
	var count := _stew_tile_count()
	if count <= 1:
		return 260.0
	if count == 2:
		return 196.0
	return 136.0


func _stew_item_name(index: int) -> String:
	if index >= 0 and index < items.size():
		var item_id := str(items[index])
		if MealData.INGREDIENTS.has(item_id):
			return str(MealData.INGREDIENTS[item_id].name)
	return "材料 %d" % (index + 1)


func _process(delta: float) -> void:
	if not running:
		return
	_t += delta
	match method_id:
		"pan_fry":
			if _holding:
				_power = minf(1.0, _power + delta / 1.15)
		"deep_fry":
			_tick_deep_fry(delta)
		"braise":
			_tick_braise(delta)
		"stew":
			_tick_stew(delta)
		"bake":
			pass
		"steam":
			_puff += _puff_dir * 0.62 * delta
			if _puff <= 0.04:
				_puff = 0.04
				_puff_dir = 1.0
			elif _puff >= 0.96:
				_puff = 0.96
				_puff_dir = -1.0
	queue_redraw()


func _tick_deep_fry(delta: float) -> void:
	var all_done := true
	for piece in _pieces:
		if bool(piece.done):
			continue
		piece.t = float(piece.t) + float(piece.speed) * delta
		if float(piece.t) >= 1.25:
			piece.done = true
			piece.score = 0.0
		else:
			all_done = false
	if all_done:
		var total := 0.0
		for piece in _pieces:
			total += float(piece.score)
		_finish_score(total / float(maxi(1, _pieces.size())))


func _tick_braise(delta: float) -> void:
	if _left_held:
		_knob = maxf(0.0, _knob - delta * 0.58)
	if _right_held:
		_knob = minf(1.0, _knob + delta * 0.58)
	_target = 0.5 + 0.28 * sin(_t * 1.55)
	if _t > 0.55 and not _braise_done:
		var error := absf(_knob - _target)
		var frame_score := 0.0
		if error <= 0.065:
			frame_score = 1.0
		elif error <= 0.17:
			frame_score = 0.55
		_braise_score += frame_score * delta
		_braise_ticks += delta
	if _t >= 4.4 and not _braise_done:
		_braise_done = true
		var score := _braise_score / maxf(0.01, _braise_ticks)
		_finish_score(score)


func _tick_stew(delta: float) -> void:
	if _stew_flash > 0.0:
		_stew_flash = maxf(0.0, _stew_flash - delta)
	_stew_elapsed += delta
	if _stew_elapsed >= 10.0:
		_finish_score(0.0)


func _press(pos: Vector2) -> void:
	if not running:
		return
	match method_id:
		"pan_fry":
			_holding = true
			_power = 0.0
		"deep_fry":
			_deep_tap(_nearest_piece(pos))
		"braise":
			_dragging = true
			_knob = clampf((pos.x + 220.0) / 440.0, 0.0, 1.0)
		"stew":
			_stew_tap(_stew_tile_at(pos))
		"bake":
			if pos.y >= 68.0:
				_dragging_dial = true
				_set_temp_from_x(pos.x)
			else:
				_confirm_bake()
		"steam":
			_steam_tap()


func _release() -> void:
	if not running:
		return
	match method_id:
		"pan_fry":
			if _holding:
				_holding = false
				var score := 1.0
				if _power >= 0.58 and _power <= 0.78:
					score = 1.0
				elif _power >= 0.34 and _power <= 0.92:
					score = 0.58
				else:
					score = 0.0
				_finish_score(score)
		"braise":
			_dragging = false
		"bake":
			_dragging_dial = false


func _drag(pos: Vector2) -> void:
	if not running:
		return
	if method_id == "braise" and _dragging:
		_knob = clampf((pos.x + 220.0) / 440.0, 0.0, 1.0)
	elif method_id == "bake" and _dragging_dial:
		_set_temp_from_x(pos.x)


func _set_temp_from_x(x: float) -> void:
	_temp = 120.0 + clampf((x + 200.0) / 400.0, 0.0, 1.0) * 120.0


func _confirm_bake() -> void:
	if not running:
		return
	var diff := absf(_temp - 180.0)
	var score := 0.0
	if diff <= 7.0:
		score = 1.0
	elif diff <= 18.0:
		score = 0.62
	elif diff <= 35.0:
		score = 0.30
	_finish_score(score)


func _nearest_piece(pos: Vector2) -> int:
	var best := -1
	var best_distance := 96.0
	for i in range(_pieces.size()):
		if bool(_pieces[i].done):
			continue
		var piece_pos: Vector2 = _pieces[i].pos
		var distance: float = pos.distance_to(piece_pos)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func _deep_tap(index: int) -> void:
	if index < 0 or index >= _pieces.size() or bool(_pieces[index].done):
		return
	var piece: Dictionary = _pieces[index]
	piece.done = true
	var t := float(piece.t)
	if absf(t - 0.55) <= 0.085:
		piece.score = 1.0
		Sfx.play("perfect")
	elif absf(t - 0.55) <= 0.20:
		piece.score = 0.58
		Sfx.play("good")
	else:
		piece.score = 0.0
		Sfx.play("burnt")
	var all_done := true
	for item in _pieces:
		if not bool(item.done):
			all_done = false
	if all_done:
		var total := 0.0
		for item in _pieces:
			total += float(item.score)
		_finish_score(total / float(_pieces.size()))


func _stew_tile_at(pos: Vector2) -> int:
	if pos.y < 35.0 or pos.y > 125.0:
		return -1
	var centers := _stew_centers()
	var half_width := _stew_tile_width() * 0.5
	for i in range(centers.size()):
		if absf(pos.x - float(centers[i])) <= half_width:
			return i
	return -1


func _stew_tap(index: int) -> void:
	if index < 0 or _done:
		return
	if _stew_expected >= _order.size():
		return
	if int(_order[_stew_expected]) == index:
		_stew_expected += 1
		_stew_flash = 0.28
		_stew_flash_ok = true
		Sfx.play("click")
		if _stew_expected >= _order.size():
			var score := clampf(1.0 - float(_stew_mistakes) * 0.34 - maxf(0.0, _stew_elapsed - 3.0) * 0.08, 0.0, 1.0)
			_finish_score(score)
	else:
		_stew_mistakes += 1
		_stew_flash = 0.34
		_stew_flash_ok = false
		Sfx.play("burnt")


func _steam_tap() -> void:
	if not running:
		return
	_steam_attempts += 1
	var score := 0.0
	if _puff >= 0.55 and _puff <= 0.88:
		score = 1.0 if (_puff >= 0.65 and _puff <= 0.80) else 0.62
		_steam_hits += 1
		_steam_flash = 0.3
		_steam_flash_ok = true
		Sfx.play("good")
	else:
		_steam_flash = 0.3
		_steam_flash_ok = false
		Sfx.play("burnt")
	_puff = 0.05
	_puff_dir = 1.0
	if _steam_hits >= 3:
		var total := 3.0
		var attempts := maxi(3, _steam_attempts)
		_finish_score(clampf(total / float(attempts), 0.0, 1.0))
	elif _steam_attempts >= 5:
		_finish_score(0.0)


func _finish_score(score: float) -> void:
	if _done:
		return
	_done = true
	running = false
	queue_redraw()
	judged.emit(quality_for_score(score))


static func quality_for_score(score: float) -> String:
	if score >= 0.78:
		return "perfect"
	if score >= 0.42:
		return "good"
	return "burnt"


## 開發用：用 0–1 直接指定表現，0.5 = 完美。
func force_result_at(value: float) -> void:
	if not running:
		return
	var score := clampf(1.0 - absf(value - 0.5) * 1.8, 0.0, 1.0)
	_finish_score(score)


func _gui_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(_game_pos(event.position))
			accept_event()
		else:
			_release()
			accept_event()
	elif event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag(_game_pos(event.position))
	elif event is InputEventScreenTouch:
		if event.pressed:
			_press(_game_pos(event.position))
			accept_event()
		else:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		_drag(_game_pos(event.position))


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventKey):
		return
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if method_id == "pan_fry":
			if event.pressed and not event.echo:
				_press(Vector2.ZERO)
			elif not event.pressed:
				_release()
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.echo and method_id in ["steam"]:
			_steam_tap()
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.echo and method_id == "bake":
			_confirm_bake()
			get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_LEFT:
		_left_held = event.pressed
		if method_id == "bake" and event.pressed and not event.echo:
			_temp = maxf(120.0, _temp - 6.0)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_RIGHT:
		_right_held = event.pressed
		if method_id == "bake" and event.pressed and not event.echo:
			_temp = minf(240.0, _temp + 6.0)
		get_viewport().set_input_as_handled()
	elif event.pressed and not event.echo:
		if method_id == "deep_fry" and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_deep_tap(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		elif method_id == "stew" and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_stew_tap(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()


func _game_pos(pos: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	var scale_factor := minf(size.x / GAME_W, size.y / GAME_H)
	if scale_factor <= 0.001:
		return Vector2.ZERO
	return (pos - size * 0.5) / scale_factor


func _draw() -> void:
	var scale_factor := minf(size.x / GAME_W, size.y / GAME_H)
	if scale_factor <= 0.001:
		return
	draw_set_transform(size * 0.5, 0.0, Vector2(scale_factor, scale_factor))
	draw_style_box(UIKit.box(Color(1, 1, 1, 0.52), 24), Rect2(-GAME_W * 0.5 + 6, -GAME_H * 0.5 + 6, GAME_W - 12, GAME_H - 12))
	match method_id:
		"pan_fry":
			_draw_pan()
		"deep_fry":
			_draw_deep_fry()
		"braise":
			_draw_braise()
		"stew":
			_draw_stew()
		"bake":
			_draw_bake()
		"steam":
			_draw_steam()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _food_color(index: int) -> Color:
	if colors.is_empty():
		return [UIKit.CORAL, UIKit.SUN, UIKit.MINT][index % 3]
	var value = colors[index % colors.size()]
	if value is Color:
		return value
	return Color(str(value))


func _ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color, points: int = 32) -> void:
	var polygon := PackedVector2Array()
	for i in range(points):
		var angle := TAU * float(i) / float(points)
		polygon.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(polygon, color)


func _draw_pan() -> void:
	_ellipse(Vector2(0, 74), 196, 19, Color(0.3, 0.24, 0.18, 0.10))
	# 火焰
	for i in range(5):
		var x := -120.0 + 60.0 * float(i)
		_ellipse(Vector2(x, 76), 17, 12, Color(0.95, 0.55, 0.25, 0.45))
	# 鑊
	draw_line(Vector2(120, -12), Vector2(272, -56), Color("#57504A"), 18.0, true)
	draw_circle(Vector2(274, -57), 11.0, Color("#57504A"))
	_ellipse(Vector2(-14, 12), 178, 76, Color("#4A443F"))
	_ellipse(Vector2(-14, 8), 158, 61, Color("#6B635B"))
	_ellipse(Vector2(-14, 8), 140, 50, Color("#8A8178"))
	# 食物
	_ellipse(Vector2(-74, 0), 42, 28, _food_color(0))
	_ellipse(Vector2(6, -8), 36, 24, _food_color(1))
	_ellipse(Vector2(66, 12), 30, 22, _food_color(2))
	_ellipse(Vector2(-78, -10), 16, 9, Color(1, 1, 1, 0.20))
	# 熟度尺
	var left := -210.0
	var width := 420.0
	draw_style_box(UIKit.box(UIKit.SAND, 7), Rect2(left, 104, width, 16))
	draw_style_box(UIKit.box(UIKit.SUN_SOFT, 6), Rect2(left + width * 0.34, 104, width * 0.58, 16))
	draw_style_box(UIKit.box(UIKit.MINT, 6), Rect2(left + width * 0.58, 104, width * 0.20, 16))
	draw_style_box(UIKit.box(UIKit.CORAL if not _holding else UIKit.BROWN, 5), Rect2(left + width * _power - 4.0, 97, 8, 30))
	draw_string(UIKit.font(true), Vector2(-256, 136), "生", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.MUTED)
	draw_string(UIKit.font(true), Vector2(238, 136), "燶", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.MUTED)


func _draw_deep_fry() -> void:
	_ellipse(Vector2(0, 80), 210, 16, Color(0.3, 0.24, 0.18, 0.10))
	# 炸鍋
	var pot := PackedVector2Array([Vector2(-205, 10), Vector2(205, 10), Vector2(178, 96), Vector2(-178, 96)])
	draw_colored_polygon(pot, Color("#5A544E"))
	_ellipse(Vector2(0, 10), 205, 42, Color("#6B635B"))
	_ellipse(Vector2(0, 10), 184, 34, Color("#E8B44A"))
	draw_arc(Vector2(0, 10), 184, 0, TAU, 64, Color(1, 1, 1, 0.22), 3.0, true)
	# 籃
	draw_line(Vector2(-120, -90), Vector2(-70, -20), Color("#7A7168"), 8.0, true)
	draw_line(Vector2(120, -90), Vector2(70, -20), Color("#7A7168"), 8.0, true)
	# 油泡
	for i in range(7):
		var angle := TAU * float(i) / 7.0 + _t * 0.5
		draw_circle(Vector2(cos(angle) * 120.0, 10 + sin(angle) * 18.0), 5.0, Color(1, 1, 1, 0.32))
	# 三件
	for i in range(_pieces.size()):
		var piece: Dictionary = _pieces[i]
		var pos: Vector2 = piece.pos
		var t := float(piece.t)
		var ring := 11.0 + minf(t, 1.25) * 48.0
		draw_circle(pos, 17.0, _food_color(i))
		draw_circle(pos, 11.0, _food_color(i).lightened(0.16))
		if bool(piece.done):
			var done_color := UIKit.MINT if float(piece.score) >= 0.78 else (UIKit.SUN if float(piece.score) >= 0.42 else UIKit.BROWN)
			draw_arc(pos, 25.0, 0, TAU, 32, done_color, 5.0, true)
		else:
			draw_arc(pos, 38.0, 0, TAU, 48, Color(0.42, 0.72, 0.58, 0.45), 7.0, true)
			draw_arc(pos, ring, 0, TAU, 48, Color(1, 1, 1, 0.85), 3.0, true)
	for i in range(3):
		var x := -150.0 + 150.0 * float(i)
		draw_string(UIKit.font(true), Vector2(x - 13, -98), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 26, 24, UIKit.MUTED)


func _draw_braise() -> void:
	_ellipse(Vector2(0, 78), 195, 18, Color(0.3, 0.24, 0.18, 0.10))
	# 砂鍋
	draw_line(Vector2(-188, -8), Vector2(-228, 18), Color("#8B5E3C"), 15.0, true)
	draw_line(Vector2(188, -8), Vector2(228, 18), Color("#8B5E3C"), 15.0, true)
	_ellipse(Vector2(0, 30), 190, 68, Color("#8B5E3C"))
	_ellipse(Vector2(0, 12), 188, 62, Color("#A06C45"))
	_ellipse(Vector2(0, 6), 160, 48, _food_color(0).darkened(0.08))
	_ellipse(Vector2(-54, -2), 40, 22, _food_color(1))
	_ellipse(Vector2(48, 10), 35, 20, _food_color(2))
	# 蓋
	_ellipse(Vector2(0, -38), 126, 42, Color("#B0764F"))
	draw_circle(Vector2(0, -66), 18.0, Color("#8B5E3C"))
	# 蒸氣
	for i in range(3):
		var offset := sin(_t * 2.0 + float(i)) * 12.0
		draw_arc(Vector2(-45.0 + 45.0 * float(i) + offset, -90), 16, 0.4, 2.7, 12, Color(1, 1, 1, 0.55), 3.0, true)
	# 慢火尺
	var left := -220.0
	var width := 440.0
	draw_style_box(UIKit.box(UIKit.SAND, 7), Rect2(left, 98, width, 16))
	var target_left := left + (clampf(_target - 0.17, 0.0, 1.0)) * width
	draw_style_box(UIKit.box(UIKit.SUN_SOFT, 6), Rect2(target_left, 98, width * 0.34, 16))
	draw_style_box(UIKit.box(UIKit.MINT, 6), Rect2(left + (_target - 0.065) * width, 97, width * 0.13, 18))
	draw_style_box(UIKit.box(UIKit.CORAL, 5), Rect2(left + _knob * width - 5.0, 90, 10, 32))
	draw_string(UIKit.font(true), Vector2(left, 142), "細火", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.MUTED)
	draw_string(UIKit.font(true), Vector2(-27, 142), "慢炆", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.MUTED)
	draw_string(UIKit.font(true), Vector2(180, 142), "猛火", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.MUTED)


func _draw_stew() -> void:
	_ellipse(Vector2(0, 36), 205, 20, Color(0.3, 0.24, 0.18, 0.10))
	# 湯鍋
	draw_line(Vector2(-192, -26), Vector2(-230, 4), Color("#5F7F96"), 14.0, true)
	draw_line(Vector2(192, -26), Vector2(230, 4), Color("#5F7F96"), 14.0, true)
	var pot := PackedVector2Array([Vector2(-190, -40), Vector2(190, -40), Vector2(166, 46), Vector2(-166, 46)])
	draw_colored_polygon(pot, Color("#6FA8D6"))
	_ellipse(Vector2(0, -40), 190, 46, Color("#8FBBDD"))
	_ellipse(Vector2(0, -40), 166, 37, _food_color(0).darkened(0.05))
	_ellipse(Vector2(-58, -42), 38, 16, _food_color(1))
	_ellipse(Vector2(50, -34), 32, 15, _food_color(2))
	# 材料卡：大字 + 永久次序數字，唔需要死記
	var centers := _stew_centers()
	var tile_width := _stew_tile_width()
	for i in range(centers.size()):
		var center_x := float(centers[i])
		var rect := Rect2(center_x - tile_width * 0.5, 52, tile_width, 70)
		var bg := Color(1, 1, 1, 0.92)
		if _stew_flash > 0.0:
			bg = UIKit.MINT_SOFT if _stew_flash_ok else UIKit.CORAL_SOFT
		var border := UIKit.LINE
		var border_width := 1
		if _stew_expected < _order.size() and int(_order[_stew_expected]) == i:
			border = UIKit.SUN
			border_width = 3
		draw_style_box(UIKit.box(bg, 16, 0, border, border_width), rect)
		var order_number := 1
		for j in range(_order.size()):
			if int(_order[j]) == i:
				order_number = j + 1
				break
		var badge_pos := Vector2(rect.position.x + 21, rect.position.y + 20)
		draw_circle(badge_pos, 16.0, UIKit.SUN_SOFT)
		draw_arc(badge_pos, 16.0, 0.0, TAU, 32, UIKit.SUN, 2.0, true)
		draw_string(UIKit.font(true), badge_pos + Vector2(-9, 7), str(order_number), HORIZONTAL_ALIGNMENT_CENTER, 18, 21, Color("#8A6216"))
		draw_string(UIKit.font(true), Vector2(rect.position.x + 8, rect.position.y + 54), _stew_item_name(i), HORIZONTAL_ALIGNMENT_CENTER, tile_width - 16, 18, UIKit.INK)
	# 計時
	var elapsed_ratio := clampf(_stew_elapsed / 10.0, 0.0, 1.0)
	draw_style_box(UIKit.box(UIKit.SAND, 5), Rect2(-180, 130, 360, 9))
	draw_style_box(UIKit.box(UIKit.MINT if elapsed_ratio < 0.7 else UIKit.CORAL, 5), Rect2(-180, 130, 360 * (1.0 - elapsed_ratio), 9))


func _draw_bake() -> void:
	_ellipse(Vector2(0, 84), 215, 16, Color(0.3, 0.24, 0.18, 0.10))
	# 焗爐
	draw_style_box(UIKit.box(Color("#C9A87A"), 24, 0, Color("#9A7A4E"), 3), Rect2(-218, -104, 436, 178))
	draw_style_box(UIKit.box(Color("#5D4A36"), 18), Rect2(-188, -80, 376, 120))
	# 玻璃窗
	draw_style_box(UIKit.box(Color(0.95, 0.87, 0.68, 0.30), 14), Rect2(-170, -68, 340, 96))
	# 焗盤
	draw_style_box(UIKit.box(Color("#8A8178"), 10), Rect2(-118, 4, 236, 22))
	_ellipse(Vector2(0, 2), 106, 18, _food_color(0))
	_ellipse(Vector2(-42, -2), 34, 14, _food_color(1))
	_ellipse(Vector2(48, 2), 30, 12, _food_color(2))
	# 旋鈕
	var angle := -2.35 + clampf((_temp - 120.0) / 120.0, 0.0, 1.0) * 4.7
	var dial_center := Vector2(0, 106)
	draw_circle(dial_center, 40.0, Color("#5D4A36"))
	draw_circle(dial_center, 32.0, Color("#F3E6CE"))
	draw_line(dial_center, dial_center + Vector2(cos(angle), sin(angle)) * 27.0, UIKit.CORAL, 6.0, true)
	draw_circle(dial_center, 7.0, UIKit.CORAL)
	# 目標刻度 180
	var target_angle := -2.35 + 0.5 * 4.7
	draw_line(dial_center + Vector2(cos(target_angle), sin(target_angle)) * 28.0, dial_center + Vector2(cos(target_angle), sin(target_angle)) * 39.0, UIKit.MINT, 4.0, true)
	draw_string(UIKit.font(true), Vector2(48, 116), "180", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#3F7D5F"))
	draw_string(UIKit.font(true), Vector2(-238, 144), "120", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.MUTED)
	draw_string(UIKit.font(true), Vector2(196, 144), "240", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.MUTED)
	draw_string(UIKit.font(true), Vector2(-80, -112), "%d°C" % int(round(_temp)), HORIZONTAL_ALIGNMENT_CENTER, 160, 30, UIKit.INK)


func _draw_steam() -> void:
	_ellipse(Vector2(0, 88), 205, 17, Color(0.3, 0.24, 0.18, 0.10))
	# 蒸氣柱：由蒸籠一路升到頂，令玩家睇得清氣泡位置
	draw_style_box(UIKit.box(Color(0.88, 0.94, 0.96, 0.78), 24, 0, Color("#C9DEE6"), 2), Rect2(-48, -94, 96, 144))
	draw_style_box(UIKit.box(Color(1, 1, 1, 0.42), 20), Rect2(-40, -86, 80, 128))
	# 蒸籠
	for tier in range(2):
		var y := 44.0 + float(tier) * 28.0
		draw_style_box(UIKit.box(Color("#D9B87A"), 18, 0, Color("#B58A5C"), 2), Rect2(-170, y, 340, 30))
		for i in range(7):
			draw_line(Vector2(-150.0 + 50.0 * float(i), y + 4), Vector2(-150.0 + 50.0 * float(i), y + 26), Color(1, 1, 1, 0.22), 2.0)
	# 蓋
	_ellipse(Vector2(0, 42), 178, 26, Color("#E8C58C"))
	draw_circle(Vector2(0, 30), 14.0, Color("#B58A5C"))
	# 目標帶
	var band_top := -88.0
	var band_bottom := -14.0
	draw_style_box(UIKit.box(UIKit.MINT_SOFT, 16, 0, UIKit.MINT, 1), Rect2(-44, -79, 88, 24))
	draw_style_box(UIKit.box(UIKit.MINT, 12), Rect2(-44, -73, 88, 11))
	# 氣泡
	var puff_y := band_bottom - _puff * (band_bottom - band_top)
	var puff_color := Color.WHITE
	if _steam_flash > 0.0:
		puff_color = UIKit.MINT if _steam_flash_ok else UIKit.CORAL
	draw_circle(Vector2(0, puff_y), 20.0, Color(0.55, 0.72, 0.76, 0.22))
	draw_circle(Vector2(0, puff_y), 16.0, puff_color)
	draw_arc(Vector2(0, puff_y), 16.0, 0, TAU, 32, UIKit.MINT if _steam_flash_ok else UIKit.CORAL, 2.0, true)
	draw_circle(Vector2(-11, puff_y + 11), 10.0, Color(puff_color, 0.78))
	draw_circle(Vector2(12, puff_y + 12), 9.0, Color(puff_color, 0.72))
	# 進度
	for i in range(3):
		draw_circle(Vector2(228, -78.0 + 38.0 * float(i)), 12.0, UIKit.MINT if i < _steam_hits else UIKit.SAND)
	draw_string(UIKit.font(true), Vector2(190, 58), "%d / 3" % _steam_hits, HORIZONTAL_ALIGNMENT_CENTER, 76, 20, UIKit.MUTED)
