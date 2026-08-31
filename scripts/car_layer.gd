extends Node2D

@export var parallax: float = 1.2
@export var car_count: int = 110
@export var car_scale: float = 0.137

const LEVEL_WIDTH: int = 32000
const FRAME_COUNT: int = 8
const FLOOR_TOP_Y: float = 665.0
const MIN_DIST_CAR_CAR: float = 210.0
const MIN_DIST_CAR_MOTO: float = 130.0

var _base_x: Array = []
var _sprites: Array = []
var _rng := RandomNumberGenerator.new()
var _moto_positions: Array = []
var _textures: Array = []

func get_placed_x() -> Array:
	return _base_x

func _conflicts(x: float) -> bool:
	for mx in _moto_positions:
		if absf(x - float(mx)) < MIN_DIST_CAR_MOTO:
			return true
	for cx in _base_x:
		if absf(x - float(cx)) < MIN_DIST_CAR_CAR:
			return true
	return false

func _safe_x() -> float:
	for _try in range(50):
		var x := _rng.randf_range(0.0, LEVEL_WIDTH)
		if not _conflicts(x):
			return x
	return _rng.randf_range(0.0, LEVEL_WIDTH)

func _ready() -> void:
	_rng.randomize()

	var moto_layer := get_node_or_null("../MotoLayer")
	if moto_layer:
		_moto_positions = moto_layer.call("get_placed_x")

	for i in range(FRAME_COUNT):
		var path := "res://assets/sprites/cars/side_test/car_side_%02d.png" % i
		var tex: Texture2D = load(path)
		_textures.append(tex)

	var order: Array = range(FRAME_COUNT)
	order.shuffle()
	for i in range(car_count):
		var frame_idx: int = order[i % order.size()]
		var tex: Texture2D = _textures[frame_idx]
		if not tex:
			continue

		var tw := tex.get_width()
		var th := tex.get_height()
		var sc := car_scale
		var px := _safe_x()

		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.scale = Vector2(sc, sc)
		# Bottom del sprite recortado = FLOOR_TOP_Y
		sp.position = Vector2(px - tw * sc * 0.5, FLOOR_TOP_Y - th * sc)
		sp.z_index = 2
		add_child(sp)

		_base_x.append(px)
		_sprites.append(sp)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)
	var cam_base := cam.get_screen_center_position().x * parallax

	for i in range(_sprites.size()):
		var sp: Sprite2D = _sprites[i] as Sprite2D
		var tw := sp.texture.get_width()
		var sc := sp.scale.x
		var new_x: float = _base_x[i] + world_offset
		sp.global_position.x = new_x - tw * sc * 0.5
		if _base_x[i] < cam_base - 2000.0:
			var placed := false
			for _t in range(100):
				var c := cam_base + _rng.randf_range(200.0, 50000.0)
				if not _conflicts(c):
					_base_x[i] = c
					placed = true
					break
			if not placed:
				_base_x[i] = cam_base + _rng.randf_range(200.0, 50000.0)
