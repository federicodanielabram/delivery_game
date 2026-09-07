extends Node2D

@export var parallax:   float = 1.2
@export var car_scale:  float = 0.515
@export var moto_scale: float = 0.211

const CAR_FRAME_COUNT:  int   = 9
const MOTO_FRAME_COUNT: int   = 18
const FLOOR_TOP_Y:      float = 655.0
const LAMP_SPACING:     float = 500.0
const LAMP_HEAD_OFFSET: float = 140.0
const LAMP_CLEAR:       float = 110.0
const LOOKAHEAD:        float = 2000.0
const CLEANUP_BEHIND:   float = 1500.0
const GAP_MAX:          float = 2.0    # separación máx. paragolpe a paragolpe — tráfico empaquetado

var _objects: Array = []  # [{cx, base_y, sp}]
var _rng             := RandomNumberGenerator.new()
var _car_textures:   Array = []
var _moto_textures:  Array = []
var _moto_frame_data: Array = []
var _moto_target_h:  float = 0.0
var _gen_head_x:     float = 0.0
var _stop_x:         float = -1.0   # -1 = infinito; >0 = congelar generación ahí

func stop_at(x: float) -> void:
	_stop_x = x

func _near_lamp(x: float) -> bool:
	var rel := fmod(x - LAMP_HEAD_OFFSET + LAMP_SPACING * 10000.0, LAMP_SPACING)
	return rel < LAMP_CLEAR or rel > LAMP_SPACING - LAMP_CLEAR

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

## Coloca un vehículo con su borde izquierdo en left_x y devuelve su borde derecho
## (left_x + ancho real), para que el llamador encadene el siguiente pegado a este.
func _place_vehicle(left_x: float) -> float:
	if _rng.randf() < 0.333:
		var fi := _rng.randi() % MOTO_FRAME_COUNT
		var tex: Texture2D = _moto_textures[fi]
		if not tex: return left_x + 50.0   # evita loop sin avance si falta el asset
		var fd: Dictionary = _moto_frame_data[fi]
		var sc  := moto_scale * (_moto_target_h / float(fd["actual_h"]))
		var tw  := tex.get_width()
		var th  := tex.get_height()
		var ratio := float(fd["max_y"]) / float(th)
		var w   := tw * sc
		var cx  := left_x + w * 0.5
		var sp := Sprite2D.new()
		sp.texture  = tex
		sp.centered = false
		sp.scale    = Vector2(sc, sc)
		sp.z_index  = 1   # por debajo de CarMidLayer (z=2): los cops (z=1, agregados después
						  # en el árbol) tienen que dibujarse delante de esta línea de fondo
		add_child(sp)
		_objects.append({"cx": cx, "base_y": FLOOR_TOP_Y - th * sc * ratio, "sp": sp})
		return left_x + w
	else:
		var fi := _rng.randi() % CAR_FRAME_COUNT
		var tex: Texture2D = _car_textures[fi]
		if not tex: return left_x + 50.0   # evita loop sin avance si falta el asset
		var sc := car_scale
		var tw  := tex.get_width()
		var th  := tex.get_height()
		var w   := tw * sc
		var cx  := left_x + w * 0.5
		var sp := Sprite2D.new()
		sp.texture  = tex
		sp.centered = false
		sp.scale    = Vector2(sc, sc)
		sp.z_index  = 1   # por debajo de CarMidLayer (z=2): los cops (z=1, agregados después
						  # en el árbol) tienen que dibujarse delante de esta línea de fondo
		add_child(sp)
		_objects.append({"cx": cx, "base_y": FLOOR_TOP_Y - th * sc, "sp": sp})
		return left_x + w

func _fill_lookahead(cam_base: float) -> void:
	var limit := (cam_base + LOOKAHEAD) if _stop_x < 0.0 else minf(cam_base + LOOKAHEAD, _stop_x)
	while _gen_head_x < limit:
		if _near_lamp(_gen_head_x):
			_gen_head_x += 20.0
			continue
		_gen_head_x = _place_vehicle(_gen_head_x) + _rng.randf_range(0.0, GAP_MAX)

func _cleanup_old(cam_base: float) -> void:
	var cutoff := cam_base - CLEANUP_BEHIND
	var i := 0
	while i < _objects.size():
		if float(_objects[i]["cx"]) < cutoff:
			(_objects[i]["sp"] as Node).queue_free()
			_objects.remove_at(i)
		else:
			i += 1

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam: return
	var cam_center  := cam.get_screen_center_position().x
	var world_offset := cam_center * (1.0 - parallax)
	var cam_base    := cam_center * parallax
	_fill_lookahead(cam_base)
	_cleanup_old(cam_base)
	for obj in _objects:
		var sp: Sprite2D = obj["sp"]
		var tw := sp.texture.get_width()
		var sc := sp.scale.x
		sp.global_position.x = float(obj["cx"]) + world_offset - tw * sc * 0.5
		sp.global_position.y = float(obj["base_y"])
