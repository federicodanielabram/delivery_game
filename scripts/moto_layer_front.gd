extends Node2D

@export var parallax: float = 1.35
@export var moto_count: int = 30
@export var moto_scale: float = 0.55

const LEVEL_WIDTH: int = 32000
const FRAME_COUNT: int = 18
const MIN_DIST_MOTO_MOTO: float = 220.0
const MIN_DIST_MOTO_CAR: float = 400.0

var _base_x: Array = []
var _sprites: Array = []
var _rng := RandomNumberGenerator.new()
var _textures: Array = []
var _car_positions: Array = []

func get_placed_x() -> Array:
	return _base_x

func _conflicts(x: float) -> bool:
	for mx in _base_x:
		if absf(x - float(mx)) < MIN_DIST_MOTO_MOTO:
			return true
	for cx in _car_positions:
		if absf(x - float(cx)) < MIN_DIST_MOTO_CAR:
			return true
	return false

func _safe_x() -> float:
	for _try in range(200):
		var x := _rng.randf_range(0.0, LEVEL_WIDTH)
		if not _conflicts(x):
			return x
	return _rng.randf_range(0.0, LEVEL_WIDTH)

func _ready() -> void:
	_rng.randomize()
	for i in range(FRAME_COUNT):
		var path := "res://assets/sprites/motorcycles/frames/frame_%02d.png" % i
		var tex: Texture2D = load(path)
		_textures.append(tex)
	call_deferred("_place_motos")

func _place_motos() -> void:
	var car_front := get_node_or_null("../CarLayerFront")
	if car_front:
		_car_positions = car_front.call("get_placed_x")

	var order: Array = range(FRAME_COUNT)
	order.shuffle()
	for i in range(moto_count):
		var frame_idx: int = order[i % order.size()]
		var tex: Texture2D = _textures[frame_idx]
		if not tex:
			continue
		var tw := tex.get_width()
		var px := _safe_x()

		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.scale = Vector2(moto_scale, moto_scale)
		sp.position = Vector2(px - tw * moto_scale * 0.5, 0.0)
		sp.z_index = 4
		add_child(sp)

		_base_x.append(px)
		_sprites.append(sp)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var screen_bottom := cam.get_screen_center_position().y + get_viewport().get_visible_rect().size.y * 0.5
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)

	for i in range(_sprites.size()):
		var sp: Sprite2D = _sprites[i] as Sprite2D
		var tw := sp.texture.get_width()
		var th := sp.texture.get_height()
		var sc := sp.scale.x
		sp.global_position.x = _base_x[i] + world_offset - tw * sc * 0.5
		sp.global_position.y = screen_bottom - th * sc * 0.75 + 80.0
