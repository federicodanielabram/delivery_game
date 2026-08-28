extends Node2D

@export var parallax: float = 1.2
const LEVEL_WIDTH: int = 32000
const FLOOR_Y: int = 655
const ALPHA_THRESHOLD: int = 10

var _base_x: Array = []
var _bounds_cache: Dictionary = {}
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

	var textures: Array = []
	for p in paths:
		var t = load(p)
		if t:
			textures.append(t)

	var rng := RandomNumberGenerator.new()
	rng.seed = 13

	var x := 0
	while x < LEVEL_WIDTH:
		var tex: Texture2D = textures[rng.randi() % textures.size()]
		var bounds := _content_bounds(tex)
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.position = Vector2(x - bounds.position.x, FLOOR_Y - tex.get_height())
		add_child(sp)
		_base_x.append(x - bounds.position.x)
		x += bounds.size.x - 15

	# Pizzeria: último edificio, continúa justo después del strip
	var piz_tex := load("res://assets/buildings/pizzeria.png") as Texture2D
	if piz_tex:
		const PIZ_H := 266.0
		var sc         := PIZ_H / float(piz_tex.get_height())
		var piz_scaled_w := float(piz_tex.get_width()) * sc
		var piz_x      := float(x) - 25.0   # offset fino de alineación

		var sp := Sprite2D.new()
		sp.name     = "Pizzeria"
		sp.texture  = piz_tex
		sp.centered = false
		sp.scale    = Vector2(sc, sc)
		sp.position = Vector2(piz_x, FLOOR_Y - PIZ_H + 3.0)   # subida 25px respecto al anterior
		add_child(sp)
		pizzeria_base_x = piz_x
		_base_x.append(piz_x)

		# Edificio fijo a la DERECHA de la pizzeria (siempre textures[0] = e1.png)
		if textures.size() > 0:
			var right_tex   : Texture2D = textures[0]
			var right_bounds := _content_bounds(right_tex)
			var right_x      := piz_x + piz_scaled_w - 35.0
			var rsp := Sprite2D.new()
			rsp.texture  = right_tex
			rsp.centered = false
			rsp.position = Vector2(right_x - right_bounds.position.x, FLOOR_Y - right_tex.get_height())
			add_child(rsp)
			_base_x.append(right_x - right_bounds.position.x)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)
	for i in range(get_child_count()):
		get_child(i).global_position.x = _base_x[i] + world_offset

func _content_bounds(tex: Texture2D) -> Rect2i:
	var key := tex.resource_path
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var left := w
	var right := 0
	for y in range(h):
		for px in range(w):
			if img.get_pixel(px, y).a8 > ALPHA_THRESHOLD:
				if px < left: left = px
				if px > right: right = px
	var result := Rect2i(0, 0, w, h) if right < left else Rect2i(left, 0, right - left + 1, h)
	_bounds_cache[key] = result
	return result
