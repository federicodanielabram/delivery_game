extends Node2D

@export var parallax:   float = 1.2
@export var moto_scale: float = 0.211

const FRAME_COUNT:    int   = 18
const FLOOR_TOP_Y:    float = 663.0
const LOOKAHEAD:      float = 6000.0
const CLEANUP_BEHIND: float = 3000.0
const SPACING_MIN:    float = 120.0
const SPACING_MAX:    float = 380.0

var _motos:      Array = []  # [{cx, base_y, sp}]
var _rng             := RandomNumberGenerator.new()
var _frame_data: Array = []
var _target_h:   float = 0.0
var _textures:   Array = []
var _gen_head_x: float = 0.0
var _stop_x:     float = -1.0

func stop_at(x: float) -> void:
	_stop_x = x

func get_placed_x() -> Array:
	var result: Array = []
	for m in _motos:
		result.append(m["cx"])
	return result

func _scan_texture(tex: Texture2D) -> void:
	var img := tex.get_image()
	if not img:
		_frame_data.append({"max_y": tex.get_height() - 1, "actual_h": tex.get_height()})
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
	_frame_data.append({"max_y": max_y, "actual_h": max_y - min_y + 1})

func _ready() -> void:
	_rng.randomize()
	for i in range(FRAME_COUNT):
		var path := "res://assets/sprites/motorcycles/frames/frame_%02d.png" % i
		var tex: Texture2D = load(path)
		_textures.append(tex)
		if tex:
			_scan_texture(tex)
		else:
			_frame_data.append({"max_y": 300, "actual_h": 300})
	var total_h := 0.0
	for d in _frame_data:
		total_h += float(d["actual_h"])
	_target_h = total_h / float(_frame_data.size())

func _spawn_moto(cx: float) -> void:
	var fi  := _rng.randi() % FRAME_COUNT
	var tex: Texture2D = _textures[fi]
	if not tex: return
	var fd: Dictionary = _frame_data[fi]
	var sc    := moto_scale * (_target_h / float(fd["actual_h"]))
	var tw    := tex.get_width()
	var th    := tex.get_height()
	var ratio := float(fd["max_y"]) / float(th)
	var sp := Sprite2D.new()
	sp.texture  = tex
	sp.centered = false
	sp.scale    = Vector2(sc, sc)
	sp.z_index  = 2
	add_child(sp)
	_motos.append({"cx": cx, "base_y": FLOOR_TOP_Y - th * sc * ratio, "sp": sp})

func _fill_lookahead(cam_base: float) -> void:
	var limit := (cam_base + LOOKAHEAD) if _stop_x < 0.0 else minf(cam_base + LOOKAHEAD, _stop_x)
	while _gen_head_x < limit:
		_spawn_moto(_gen_head_x)
		_gen_head_x += _rng.randf_range(SPACING_MIN, SPACING_MAX)

func _cleanup_old(cam_base: float) -> void:
	var cutoff := cam_base - CLEANUP_BEHIND
	var i := 0
	while i < _motos.size():
		if float(_motos[i]["cx"]) < cutoff:
			(_motos[i]["sp"] as Node).queue_free()
			_motos.remove_at(i)
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
	for m in _motos:
		var sp: Sprite2D = m["sp"]
		var tw := sp.texture.get_width()
		var sc := sp.scale.x
		sp.global_position.x = float(m["cx"]) + world_offset - tw * sc * 0.5
		sp.global_position.y = float(m["base_y"])
