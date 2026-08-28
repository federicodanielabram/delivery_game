extends Node2D

@export var bus_scale: float = 0.588
@export var parallax:  float = 1.237

const LEVEL_WIDTH: int   = 32000
const FLOOR_Y:     float = 695.0
const START_X:     float = 3000.0
const ROOF_OFFSET: float = 15.0    # px desde el top del canvas hasta el techo plano

# Por frame: canvas width, canvas height total (con margen sombra), altura del cuerpo del bus
const BUS_DATA: Array = [
	{"cw": 1007.0, "ch": 400.0, "body_h": 320.0},  # bus_01
	{"cw": 1007.0, "ch": 386.0, "body_h": 309.0},  # bus_02
	{"cw": 1009.0, "ch": 394.0, "body_h": 315.0},  # bus_03
]

const MIN_DIST_CAR: float = 350.0  # distancia mínima borde-a-borde con autos del mid layer
const MIN_DIST_BUS: float = 900.0  # distancia mínima entre buses

var _rng    := RandomNumberGenerator.new()
var _base_x: Array = []
var _bodies: Array = []

func _ready() -> void:
	_rng.randomize()
	z_index = 2
	call_deferred("_place_buses")

func _place_buses() -> void:
	var sc := bus_scale

	var textures: Array = []
	for i in range(1, BUS_DATA.size() + 1):
		textures.append(load("res://assets/sprites/buses/bus_0%d.png" % i))

	var mid := get_node_or_null("../CarMidLayer")
	var car_x: Array = []
	if mid:
		car_x = mid.call("get_placed_x")

	for _i in range(60):
		for _try in range(80):
			var x := _rng.randf_range(START_X, float(LEVEL_WIDTH) - 1500.0)
			if not _valid(x, car_x, sc):
				continue

			var fi: int = _rng.randi() % BUS_DATA.size()
			var d: Dictionary = BUS_DATA[fi]
			var cw: float = d.cw
			var ch: float = d.ch
			var bh: float = d.body_h
			var shadow_h: float = ch - bh

			var tex: Texture2D = textures[fi]
			if not tex:
				break

			var body := StaticBody2D.new()
			# Anclar para que las ruedas queden en FLOOR_Y
			body.position       = Vector2(x, FLOOR_Y + shadow_h * sc)
			body.collision_layer = 1
			body.collision_mask  = 0
			add_child(body)

			var sp := Sprite2D.new()
			sp.texture  = tex
			sp.centered = false
			sp.scale    = Vector2(sc, sc)
			sp.position = Vector2(-cw * sc * 0.5, -ch * sc)
			body.add_child(sp)

			# Colisión one-way en el techo: rectángulo fino, sin costados
			var col   := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(cw * sc * 0.80, 6.0)
			col.shape                = shape
			col.one_way_collision    = true
			col.position             = Vector2(0.0, -(ch - ROOF_OFFSET) * sc)
			body.add_child(col)

			_base_x.append(x)
			_bodies.append(body)
			break

func _valid(x: float, car_x: Array, sc: float) -> bool:
	var bus_hw := BUS_DATA[0].cw * sc * 0.5
	for cx in car_x:
		if absf(x - float(cx)) < bus_hw + MIN_DIST_CAR:
			return false
	for bx in _base_x:
		if absf(x - float(bx)) < MIN_DIST_BUS:
			return false
	return true

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var offset := cam.get_screen_center_position().x * (1.0 - parallax)
	for i in range(_bodies.size()):
		var body: Node2D = _bodies[i]
		body.global_position.x = _base_x[i] + offset
