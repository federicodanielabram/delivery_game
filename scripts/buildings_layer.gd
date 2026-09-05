extends Node2D

@export var parallax: float = 1.2
const FLOOR_Y:        int   = 655
const ALPHA_THRESHOLD: int  = 10
const LOOKAHEAD:      float = 2000.0
const CLEANUP_BEHIND: float = 2000.0

var _base_x:      Array = []
var _sprites:     Array = []
var _bounds_cache: Dictionary = {}

var _textures:   Array = []
var _rng:        RandomNumberGenerator = null
var _gen_head_x: float = 0.0

# Exportado para compatibilidad (level1.gd lo lee pero ya no lo usa en modo infinito)
var pizzeria_base_x: float = 0.0

func _ready() -> void:
	var paths := [
		"res://assets/buildings/e1.png",
		"res://assets/buildings/e2.png",
		"res://assets/buildings/e3.png",
		"res://assets/buildings/e4.png",
		"res://assets/buildings/e5.png",
		"res://assets/buildings/e6.png",
		"res://assets/buildings/e7.png",
		"res://assets/buildings/e8.png",
	]
	for p in paths:
		var t = load(p)
		if t: _textures.append(t)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 13
	_gen_head_x = 0.0
	_fill_buildings(0.0)

func _spawn_building(x: float) -> float:
	var tex: Texture2D = _textures[_rng.randi() % _textures.size()]
	var bounds := _content_bounds(tex)
	if bounds.size.x <= 0:
		return x + 200.0
	var sp := Sprite2D.new()
	sp.texture  = tex
	sp.centered = false
	sp.position = Vector2(x - bounds.position.x, FLOOR_Y - tex.get_height())
	add_child(sp)
	_base_x.append(x - bounds.position.x)
	_sprites.append(sp)
	return x + bounds.size.x - 15

func _fill_buildings(cam_x: float) -> void:
	var target_x := cam_x * parallax + LOOKAHEAD
	while _gen_head_x < target_x:
		_gen_head_x = _spawn_building(_gen_head_x)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var cam_x        := cam.get_screen_center_position().x
	var world_offset := cam_x * (1.0 - parallax)

	for i in range(_sprites.size()):
		(_sprites[i] as Sprite2D).global_position.x = _base_x[i] + world_offset

	if _gen_head_x < cam_x * parallax + LOOKAHEAD:
		_fill_buildings(cam_x)

	var cutoff := cam_x * parallax - CLEANUP_BEHIND
	var i := 0
	while i < _base_x.size():
		if _base_x[i] < cutoff:
			(_sprites[i] as Node).queue_free()
			_base_x.remove_at(i)
			_sprites.remove_at(i)
		else:
			i += 1

func _content_bounds(tex: Texture2D) -> Rect2i:
	var key := tex.resource_path
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var left  := w
	var right := 0
	for y in range(h):
		for px in range(w):
			if img.get_pixel(px, y).a8 > ALPHA_THRESHOLD:
				if px < left:  left  = px
				if px > right: right = px
	var result := Rect2i(0, 0, w, h) if right < left else Rect2i(left, 0, right - left + 1, h)
	_bounds_cache[key] = result
	return result
