extends Node2D

@export var parallax:   float = 1.2
@export var car_scale:  float = 0.137

const FRAME_COUNT:    int   = 8
const FLOOR_TOP_Y:    float = 665.0
const LOOKAHEAD:      float = 2000.0
const CLEANUP_BEHIND: float = 1500.0
const SPACING_MIN:    float = 210.0
const SPACING_MAX:    float = 520.0

var _sprites:    Array = []
var _base_x:     Array = []
var _rng             := RandomNumberGenerator.new()
var _textures:   Array = []
var _gen_head_x: float = 0.0
var _stop_x:     float = -1.0

func stop_at(x: float) -> void:
	_stop_x = x

func get_placed_x() -> Array:
	return _base_x

func _ready() -> void:
	_rng.randomize()
	for i in range(FRAME_COUNT):
		_textures.append(load("res://assets/sprites/cars/side_test/car_side_%02d.png" % i))

func _spawn_car(cx: float) -> void:
	var fi  := _rng.randi() % FRAME_COUNT
	var tex: Texture2D = _textures[fi]
	if not tex: return
	var tw := tex.get_width()
	var th := tex.get_height()
	var sc := car_scale
	var sp := Sprite2D.new()
	sp.texture  = tex
	sp.centered = false
	sp.scale    = Vector2(sc, sc)
	sp.z_index  = 2
	add_child(sp)
	_base_x.append(cx)
	_sprites.append(sp)

func _fill_lookahead(cam_base: float) -> void:
	var limit := (cam_base + LOOKAHEAD) if _stop_x < 0.0 else minf(cam_base + LOOKAHEAD, _stop_x)
	while _gen_head_x < limit:
		_spawn_car(_gen_head_x)
		_gen_head_x += _rng.randf_range(SPACING_MIN, SPACING_MAX)

func _cleanup_old(cam_base: float) -> void:
	var cutoff := cam_base - CLEANUP_BEHIND
	var i := 0
	while i < _sprites.size():
		if _base_x[i] < cutoff:
			(_sprites[i] as Node).queue_free()
			_base_x.remove_at(i)
			_sprites.remove_at(i)
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
	for i in range(_sprites.size()):
		var sp: Sprite2D = _sprites[i] as Sprite2D
		var tw := sp.texture.get_width()
		var th := sp.texture.get_height()
		var sc := sp.scale.x
		sp.global_position.x = _base_x[i] + world_offset - tw * sc * 0.5
		sp.global_position.y = FLOOR_TOP_Y - th * sc
