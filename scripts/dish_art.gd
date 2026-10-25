class_name DishArt
extends Control

## 顯示菜式圖：有 pixel-food 圖片就用圖片，冇就 fallback 去原本嘅 FoodArt。
## 圖片以 nearest-neighbor 放大，保持 pixel art 銳利。

const MANIFEST_PATH := "res://assets/pixel_food/manifest.json"
const ART_ROOT := "res://assets/pixel_food/"

static var _manifest: Dictionary = {}
static var _texture_cache: Dictionary = {}

var recipe_id := "":
	set(value):
		recipe_id = value
		if not value.is_empty():
			recipe_data = {}
		_refresh()
var recipe_data: Dictionary = {}:
	set(value):
		recipe_data = value
		if not value.is_empty():
			recipe_id = ""
		_refresh()
var burnt := false:
	set(value):
		burnt = value
		_apply_burnt()
		queue_redraw()

var _texture_rect: TextureRect
var _fallback: FoodArt
var _has_texture := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(80, 80)
	clip_contents = false
	resized.connect(queue_redraw)

	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_texture_rect)

	_fallback = FoodArt.new()
	_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fallback)

	_refresh()


func _refresh() -> void:
	if _texture_rect == null or _fallback == null:
		return
	var recipe := _recipe()
	var texture := texture_for(recipe)
	_has_texture = texture != null
	if _has_texture:
		_texture_rect.texture = texture
		_texture_rect.visible = true
		_fallback.visible = false
	else:
		_texture_rect.texture = null
		_texture_rect.visible = false
		_fallback.visible = true
		_fallback.recipe_id = ""
		_fallback.recipe_data = recipe
		_fallback.burnt = burnt
	_apply_burnt()
	queue_redraw()


func _recipe() -> Dictionary:
	if not recipe_data.is_empty():
		return recipe_data
	if recipe_id.is_empty():
		return {}
	return MealData.recipe(recipe_id)


func uses_pixel_art() -> bool:
	return _has_texture


func _apply_burnt() -> void:
	if _texture_rect == null:
		return
	_texture_rect.modulate = Color(0.68, 0.58, 0.48) if burnt else Color.WHITE
	if not _has_texture and _fallback != null:
		_fallback.burnt = burnt


func _draw() -> void:
	if not _has_texture or not burnt:
		return
	var unit := minf(size.x, size.y)
	draw_circle(size * Vector2(0.34, 0.40), unit * 0.055, Color(0.12, 0.08, 0.04, 0.38))
	draw_circle(size * Vector2(0.56, 0.34), unit * 0.040, Color(0.12, 0.08, 0.04, 0.32))
	draw_circle(size * Vector2(0.48, 0.58), unit * 0.032, Color(0.12, 0.08, 0.04, 0.28))


static func manifest() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_manifest = parsed
	return _manifest


static func art_path_for(recipe: Dictionary) -> String:
	if recipe.is_empty():
		return ""
	var explicit := str(recipe.get("art", ""))
	if explicit.begins_with("res://"):
		return explicit
	var recipe_key := str(recipe.get("id", ""))
	var recipes: Dictionary = manifest().get("recipes", {})
	var entry = recipes.get(recipe_key, {})
	if typeof(entry) == TYPE_DICTIONARY and entry.has("file"):
		return ART_ROOT + str(entry.file)
	return ""


static func texture_for(recipe: Dictionary) -> Texture2D:
	var path := art_path_for(recipe)
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var loaded = load(path)
	if loaded == null or not (loaded is Texture2D):
		return null
	_texture_cache[path] = loaded
	return loaded


static func mapped_recipe_count() -> int:
	return manifest().get("recipes", {}).size()
