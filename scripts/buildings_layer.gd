extends Node2D

@export var parallax: float = 1.2
const LEVEL_WIDTH: int = 15360
const FLOOR_Y: int = 655
const ALPHA_THRESHOLD: int = 10

var _base_x: Array = []

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

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)
	for i in range(get_child_count()):
		get_child(i).global_position.x = _base_x[i] + world_offset

func _content_bounds(tex: Texture2D) -> Rect2i:
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
	if right < left:
		return Rect2i(0, 0, w, h)
	return Rect2i(left, 0, right - left + 1, h)
