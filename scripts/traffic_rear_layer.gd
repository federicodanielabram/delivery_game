extends Node2D

@export var parallax: float = 1.2
@export var car_count: int = 300
@export var moto_count: int = 150
@export var car_scale: float = 0.515
@export var moto_scale: float = 0.211
@export var min_edge_gap: float = 5.0

const LEVEL_WIDTH: int = 32000
const CAR_FRAME_COUNT: int = 9
const MOTO_FRAME_COUNT: int = 18
const FLOOR_TOP_Y: float = 655.0
const LAMP_SPACING: float = 500.0
const LAMP_HEAD_OFFSET: float = 140.0
const LAMP_CLEAR: float = 110.0

var _objects: Array = []  # [{cx, hw, base_y, sp}]
var _rng := RandomNumberGenerator.new()
var _car_textures: Array = []
var _moto_textures: Array = []
var _moto_frame_data: Array = []
var _moto_target_h: float = 0.0

func get_placed_x() -> Array:
	var result: Array = []
	for obj in _objects:
		result.append(obj["cx"])
	return result

func _near_lamp(x: float) -> bool:
	var rel := fmod(x - LAMP_HEAD_OFFSET + LAMP_SPACING * 10000.0, LAMP_SPACING)
	return rel < LAMP_CLEAR or rel > LAMP_SPACING - LAMP_CLEAR

func _conflicts(cx: float, hw: float) -> bool:
	if _near_lamp(cx):
		return true
	for obj in _objects:
		var gap := absf(cx - float(obj["cx"])) - hw - float(obj["hw"])
		if gap < min_edge_gap:
			return true
	return false

func _safe_x(hw: float) -> float:
	for _try in range(200):
		var x := _rng.randf_range(0.0, LEVEL_WIDTH)
		if not _conflicts(x, hw):
			return x
	return -1.0

func _scan_moto(tex: Texture2D) -> void:
	var img := tex.get_image()
	if not img:
		_moto_frame_data.append({"max_y": tex.get_height() - 1, "actual_h": tex.get_height()})
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
	_moto_frame_data.append({"max_y": max_y, "actual_h": max_y - min_y + 1})

func _ready() -> void:
	_rng.randomize()

	for i in range(CAR_FRAME_COUNT):
		_car_textures.append(load("res://assets/sprites/cars/frames/frame_%02d.png" % i))

	for i in range(MOTO_FRAME_COUNT):
		var tex: Texture2D = load("res://assets/sprites/motorcycles/frames/frame_%02d.png" % i)
		_moto_textures.append(tex)
		if tex:
			_scan_moto(tex)
		else:
			_moto_frame_data.append({"max_y": 300, "actual_h": 300})

	var total_h := 0.0
	for d in _moto_frame_data:
		total_h += float(d["actual_h"])
	_moto_target_h = total_h / float(_moto_frame_data.size())

	var items: Array = []
	var car_order := range(CAR_FRAME_COUNT)
	car_order.shuffle()
	for i in range(car_count):
		items.append({"is_moto": false, "frame": car_order[i % car_order.size()]})
	var moto_order := range(MOTO_FRAME_COUNT)
	moto_order.shuffle()
	for i in range(moto_count):
		items.append({"is_moto": true, "frame": moto_order[i % moto_order.size()]})
	items.shuffle()

	for item in items:
		var fi: int = item["frame"]
		if item["is_moto"]:
			var tex: Texture2D = _moto_textures[fi]
			if not tex: continue
			var fd: Dictionary = _moto_frame_data[fi]
			var sc := moto_scale * (_moto_target_h / float(fd["actual_h"]))
			var tw := tex.get_width()
			var th := tex.get_height()
			var hw := tw * sc * 0.5
			var cx := _safe_x(hw)
			if cx < 0.0: continue
			var ratio := float(fd["max_y"]) / float(th)
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.scale = Vector2(sc, sc)
			sp.z_index = 2

			add_child(sp)
			_objects.append({"cx": cx, "hw": hw, "base_y": FLOOR_TOP_Y - th * sc * ratio, "sp": sp})
		else:
			var tex: Texture2D = _car_textures[fi]
			if not tex: continue
			var tw := tex.get_width()
			var th := tex.get_height()
			var sc := car_scale
			var hw := tw * sc * 0.5
			var cx := _safe_x(hw)
			if cx < 0.0: continue
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.scale = Vector2(sc, sc)
			sp.z_index = 2

			add_child(sp)
			_objects.append({"cx": cx, "hw": hw, "base_y": FLOOR_TOP_Y - th * sc, "sp": sp})

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)
	var cam_base := cam.get_screen_center_position().x * parallax
	for obj in _objects:
		var sp: Sprite2D = obj["sp"]
		var tw := sp.texture.get_width()
		var sc := sp.scale.x
		sp.global_position.x = float(obj["cx"]) + world_offset - tw * sc * 0.5
		sp.global_position.y = float(obj["base_y"])
		if float(obj["cx"]) < cam_base - 2000.0:
			var hw: float = obj["hw"]
			var placed := false
			for _t in range(100):
				var c := cam_base + _rng.randf_range(200.0, 50000.0)
				if not _conflicts(c, hw):
					obj["cx"] = c
					placed = true
					break
			if not placed:
				obj["cx"] = cam_base + _rng.randf_range(200.0, 50000.0)
