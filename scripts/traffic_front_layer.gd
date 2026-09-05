extends Node2D

@export var parallax:      float = 1.35
@export var car_scale:     float = 0.67    # sobre canvas 1424x642 (mismos frames que los autos de piso del medio)
@export var moto_scale:    float = 0.55
@export var moto_y_offset: float = 80.0

const CAR_FRAME_COUNT:  int   = 8
const MOTO_FRAME_COUNT: int   = 18
const LOOKAHEAD:        float = 2000.0
const CLEANUP_BEHIND:   float = 1500.0
const GAP_MAX:          float = 2.0    # separación máx. paragolpe a paragolpe — tráfico empaquetado
const CAR_Y_OFFSET:     float = 100.0  # baja los autos (no motos) 100px respecto al anclaje anterior
const ALL_Y_OFFSET:     float = 20.0   # ajuste extra solo de autos, encima de CAR_Y_OFFSET
# Ajuste extra por frame, encima de CAR_Y_OFFSET (índices de car_side_%02d.png)
const CAR_FRAME_Y_EXTRA: Dictionary = {
	2: 100.0,
	4: 100.0,
	6: 100.0,
}

var _objects: Array = []  # [{cx, sp, is_moto}]
var _rng             := RandomNumberGenerator.new()
var _car_textures:   Array = []
var _moto_textures:  Array = []
var _screen_bottom:  float = 0.0
var _gen_head_x:     float = 0.0
var _stop_x:         float = -1.0

func stop_at(x: float) -> void:
	_stop_x = x

func _ready() -> void:
	_rng.randomize()
	call_deferred("_init_screen_bottom")
	for i in range(CAR_FRAME_COUNT):
		_car_textures.append(load("res://assets/sprites/cars/side_test/car_side_%02d.png" % i))
	for i in range(MOTO_FRAME_COUNT):
		_moto_textures.append(load("res://assets/sprites/motorcycles/frames/frame_%02d.png" % i))

func _init_screen_bottom() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		_screen_bottom = cam.get_screen_center_position().y + get_viewport().get_visible_rect().size.y * 0.5
	else:
		_screen_bottom = get_viewport().get_visible_rect().size.y

## Coloca un vehículo con su borde izquierdo en left_x y devuelve su borde derecho
## (left_x + ancho real), para que el llamador encadene el siguiente pegado a este.
func _place_vehicle(left_x: float) -> float:
	var is_moto := _rng.randf() < 0.333
	var sc  := moto_scale if is_moto else car_scale
	var fi  := _rng.randi() % (MOTO_FRAME_COUNT if is_moto else CAR_FRAME_COUNT)
	var tex: Texture2D = _moto_textures[fi] if is_moto else _car_textures[fi]
	if not tex: return left_x + 50.0   # evita loop sin avance si falta el asset
	var tw := tex.get_width()
	var w  := tw * sc
	var cx := left_x + w * 0.5
	var sp := Sprite2D.new()
	sp.texture  = tex
	sp.centered = false
	sp.scale    = Vector2(sc, sc)
	sp.z_index  = 4
	sp.modulate = Color(0.55, 0.50, 0.65)
	add_child(sp)
	_objects.append({"cx": cx, "sp": sp, "is_moto": is_moto, "fi": fi})
	return left_x + w

func _fill_lookahead(cam_base: float) -> void:
	var limit := (cam_base + LOOKAHEAD) if _stop_x < 0.0 else minf(cam_base + LOOKAHEAD, _stop_x)
	while _gen_head_x < limit:
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
	var cam_center   := cam.get_screen_center_position().x
	var world_offset := cam_center * (1.0 - parallax)
	var cam_base     := cam_center * parallax
	_fill_lookahead(cam_base)
	_cleanup_old(cam_base)
	for obj in _objects:
		var sp: Sprite2D = obj["sp"]
		var tw := sp.texture.get_width()
		var th := sp.texture.get_height()
		var sc := sp.scale.x
		sp.global_position.x = float(obj["cx"]) + world_offset - tw * sc * 0.5
		var y_off: float
		if obj["is_moto"]:
			y_off = moto_y_offset
		else:
			y_off = CAR_Y_OFFSET + float(CAR_FRAME_Y_EXTRA.get(obj["fi"], 0.0)) + ALL_Y_OFFSET
		sp.global_position.y = _screen_bottom - th * sc * 0.75 + y_off
