extends Node2D

@export var parallax: float = 1.2
@export var puddle_count: int = 40
@export var scale_min: float = 0.22
@export var scale_max: float = 0.45
@export var alpha: float = 0.75

const LEVEL_WIDTH: int = 32000
const FLOOR_Y_MIN: int = 658
const FLOOR_Y_MAX: int = 710
const COLS: int = 3
const ROWS: int = 4
const FRAME_W: int = 341
const FRAME_H: int = 256

var _base_x: Array = []
var _sprites: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 42

	var sheet: Texture2D = load("res://assets/sprites/puddles/puddles.png")
	if not sheet:
		return

	for i in range(puddle_count):
		var frame_idx := _rng.randi_range(0, COLS * ROWS - 1)
		var col := frame_idx % COLS
		var row := frame_idx / COLS

		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
		atlas.filter_clip = true

		var sp := Sprite2D.new()
		sp.texture = atlas
		sp.centered = true

		var px := _rng.randf_range(0.0, LEVEL_WIDTH)
		var py := _rng.randf_range(float(FLOOR_Y_MIN), float(FLOOR_Y_MAX))

		var depth := (py - FLOOR_Y_MIN) / (FLOOR_Y_MAX - FLOOR_Y_MIN)
		var sc := lerpf(scale_min, scale_max, depth)
		sp.scale = Vector2(sc, sc * 0.5)
		sp.position = Vector2(px, py)
		sp.z_index = 1
		# Charcos: tinte oscuro azulado semi-transparente sobre el piso
		sp.modulate = Color(0.30, 0.32, 0.42, 0.70)
		add_child(sp)

		_base_x.append(px)
		_sprites.append(sp)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)

	for i in range(_sprites.size()):
		var new_x: float = _base_x[i] + world_offset
		(_sprites[i] as Sprite2D).global_position.x = new_x
