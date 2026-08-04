extends Node2D

@export var parallax: float = 1.2
@export var moto_count: int = 22
@export var moto_scale: float = 0.211

const LEVEL_WIDTH: int = 32000
const FRAME_COUNT: int = 18
const FLOOR_TOP_Y: float = 663.0
const LAMP_SPACING: float = 500.0
const LAMP_HEAD_OFFSET: float = 140.0
const LAMP_CLEAR: float = 110.0
const MIN_DIST_MOTO_MOTO: float = 160.0
const MIN_DIST_MOTO_CAR: float = 180.0

var _base_x: Array = []
var _sprites: Array = []
var _rng := RandomNumberGenerator.new()
var _frame_data: Array = []
var _target_h: float = 0.0
var _textures: Array = []
var _car_positions: Array = []

func get_placed_x() -> Array:
	return _base_x

func _scan_texture(tex: Texture2D) -> void:
	var img := tex.get_image()
	if not img:
		_frame_data.append({ "max_y": tex.get_height() - 1, "actual_h": tex.get_height() })
		return
	var w := img.get_width()
	var h := img.get_height()
	var min_y := h - 1
	var max_y := 0
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				if y < min_y: min_y = y
				if y > max_y: max_y = y
	_frame_data.append({ "max_y": max_y, "actual_h": max_y - min_y + 1 })

func _near_lamp(x: float) -> bool:
	var rel := fmod(x - LAMP_HEAD_OFFSET + LAMP_SPACING * 10000.0, LAMP_SPACING)
	return rel < LAMP_CLEAR or rel > LAMP_SPACING - LAMP_CLEAR

func _conflicts(x: float) -> bool:
	if _near_lamp(x):
		return true
	for mx in _base_x:
		if absf(x - float(mx)) < MIN_DIST_MOTO_MOTO:
			return true
	for cx in _car_positions:
		if absf(x - float(cx)) < MIN_DIST_MOTO_CAR:
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

	for i in range(FRAME_COUNT):
		var path := "res://assets/sprites/motorcycles/frames/frame_%02d.png" % i
		var tex: Texture2D = load(path)
		_textures.append(tex)
		if tex:
			_scan_texture(tex)
		else:
			_frame_data.append({ "max_y": 300, "actual_h": 300 })

	var total_h := 0.0
	for d in _frame_data:
		total_h += float(d["actual_h"])
	_target_h = total_h / float(_frame_data.size())

	call_deferred("_place_motos")

func _place_motos() -> void:
	var car_layer := get_node_or_null("../CarLayer")
	if car_layer:
		_car_positions = car_layer.call("get_placed_x")

	for i in range(moto_count):
		var frame_idx := _rng.randi_range(0, FRAME_COUNT - 1)
		var tex: Texture2D = _textures[frame_idx]
		if not tex:
			continue

		var tw := tex.get_width()
		var th := tex.get_height()
		var fd: Dictionary = _frame_data[frame_idx]
		var sc := moto_scale * (_target_h / float(fd["actual_h"]))
		var ratio := float(fd["max_y"]) / float(th)
		var px := _safe_x()

		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.scale = Vector2(sc, sc)
		sp.position = Vector2(px - tw * sc * 0.5, FLOOR_TOP_Y - th * sc * ratio)
		sp.z_index = 2
		add_child(sp)

		_base_x.append(px)
		_sprites.append(sp)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)

	for i in range(_sprites.size()):
		var sp: Sprite2D = _sprites[i] as Sprite2D
		var tw := sp.texture.get_width()
		var sc := sp.scale.x
		sp.global_position.x = _base_x[i] + world_offset - tw * sc * 0.5
