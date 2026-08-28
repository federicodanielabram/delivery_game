extends Node2D

@export var parallax: float = 1.35
@export var car_count: int = 100
@export var moto_count: int = 50
@export var car_scale: float = 1.056
@export var moto_scale: float = 0.55
@export var min_edge_gap: float = 5.0
@export var moto_y_offset: float = 80.0

const LEVEL_WIDTH: int = 32000
const CAR_FRAME_COUNT: int = 8
const MOTO_FRAME_COUNT: int = 18

var _objects: Array = []  # [{cx, hw, sp, is_moto}]
var _rng := RandomNumberGenerator.new()
var _car_textures: Array = []
var _moto_textures: Array = []
var _screen_bottom: float = 0.0

func _conflicts(center_x: float, half_w: float) -> bool:
	for obj in _objects:
		var gap := absf(center_x - float(obj["cx"])) - half_w - float(obj["hw"])
		if gap < min_edge_gap:
			return true
	return false

func _safe_x(half_w: float) -> float:
	for _try in range(300):
		var x := _rng.randf_range(0.0, LEVEL_WIDTH)
		if not _conflicts(x, half_w):
			return x
	return -1.0

func _ready() -> void:
	_rng.randomize()
	call_deferred("_init_screen_bottom")

	for i in range(CAR_FRAME_COUNT):
		_car_textures.append(load("res://assets/sprites/cars/frames_front/frame_%02d.png" % i))
	for i in range(MOTO_FRAME_COUNT):
		_moto_textures.append(load("res://assets/sprites/motorcycles/frames/frame_%02d.png" % i))

	# Armar lista mezclada de items y colocar todos juntos
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
		var is_moto: bool = item["is_moto"]
		var tex: Texture2D = _moto_textures[item["frame"]] if is_moto else _car_textures[item["frame"]]
		if not tex:
			continue
		var sc := moto_scale if is_moto else car_scale
		var hw := tex.get_width() * sc * 0.5
		var cx := _safe_x(hw)
		if cx < 0.0:
			continue

		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.scale = Vector2(sc, sc)
		sp.z_index = 4
		add_child(sp)
		_objects.append({"cx": cx, "hw": hw, "sp": sp, "is_moto": is_moto})

func _init_screen_bottom() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		_screen_bottom = cam.get_screen_center_position().y + get_viewport().get_visible_rect().size.y * 0.5
	else:
		_screen_bottom = get_viewport().get_visible_rect().size.y

func get_placed_x() -> Array:
	var result: Array = []
	for obj in _objects:
		result.append(obj["cx"])
	return result

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)

	for obj in _objects:
		var sp: Sprite2D = obj["sp"]
		var tw := sp.texture.get_width()
		var th := sp.texture.get_height()
		var sc := sp.scale.x
		var cx: float = obj["cx"]
		sp.global_position.x = cx + world_offset - tw * sc * 0.5
		var y_off := moto_y_offset if obj["is_moto"] else 0.0
		sp.global_position.y = _screen_bottom - th * sc * 0.75 + y_off
