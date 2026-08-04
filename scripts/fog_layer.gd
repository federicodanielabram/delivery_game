extends Node2D

@export var parallax:  float = 1.2
@export var fog_color: Color = Color(0.82, 0.84, 0.88, 0.05)
@export var y_offset:  float = 0.0
@export var tex_w:      int   = 512
@export var tex_h:      int   = 320
@export var drift_speed: float = 20.0  # px/s, positivo = deriva a la derecha

var _tw:      float
var _cy:      float
var _drift:   float = 0.0
var _started := false

func _ready() -> void:
	var tex := _make_texture()
	_tw = float(tex_w)
	for i in range(4):
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		add_child(sp)

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam: return
	if not _started:
		_cy = cam.get_screen_center_position().y
		_started = true
	_drift = fmod(_drift + drift_speed * delta, _tw)
	var cx   := cam.get_screen_center_position().x
	var base: float = floor(cx * parallax / _tw) * _tw
	var ox:   float = cx * (1.0 - parallax) + base + _drift
	var oy   := _cy + y_offset
	get_child(0).global_position = Vector2(ox - _tw * 1.5, oy)
	get_child(1).global_position = Vector2(ox - _tw * 0.5, oy)
	get_child(2).global_position = Vector2(ox + _tw * 0.5, oy)
	get_child(3).global_position = Vector2(ox + _tw * 1.5, oy)

func _make_texture() -> ImageTexture:
	var img := Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	var k1  := TAU * 4.0 / tex_w
	var k2  := TAU * 7.0 / tex_w
	for x in range(tex_w):
		var hx := (sin(x * k1) * 0.35 + sin(x * k2 + 1.1) * 0.25) * 0.5 + 0.55
		for y in range(tex_h):
			var fy := float(y) / float(tex_h - 1)
			var a  := sin(fy * PI) * fog_color.a * hx
			img.set_pixel(x, y, Color(fog_color.r, fog_color.g, fog_color.b, a))
	return ImageTexture.create_from_image(img)
