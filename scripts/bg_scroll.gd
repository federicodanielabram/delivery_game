extends Node2D

@export var parallax: float = 1.0
@export var y_offset: float = 0.0

var _w: float
var _cy: float
var _ready_done := false

func _ready() -> void:
	_w = $SpriteA.texture.get_width()
	$SpriteB.texture = $SpriteA.texture
	$SpriteC.texture = $SpriteA.texture

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	if not _ready_done:
		_cy = cam.get_screen_center_position().y
		_ready_done = true
	var cx: float = cam.get_screen_center_position().x
	var scroll: float = cx * parallax
	var base: float = floor(scroll / _w) * _w
	var world_offset: float = cx * (1.0 - parallax)
	var cy: float = _cy + y_offset
	$SpriteA.global_position = Vector2(world_offset + base - _w * 0.5, cy)
	$SpriteB.global_position = Vector2(world_offset + base + _w * 0.5, cy)
	$SpriteC.global_position = Vector2(world_offset + base + _w * 1.5, cy)
