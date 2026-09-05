extends Node2D

@export var transition_duration: float = 600.0

const FRAME_COUNT: int = 97

var _textures: Array = []
var _elapsed: float = 0.0
var _current_frame: int = -1
var _cy: float = 0.0
var _ready_done: bool = false

func _ready() -> void:
	$SpriteB.visible = false
	$SpriteC.visible = false
	for i in range(1, FRAME_COUNT + 1):
		_textures.append(load("res://assets/backgrounds/bg_transition/frame_%03d.png" % i))
	_apply_frame(0)

func _apply_frame(idx: int) -> void:
	if idx == _current_frame:
		return
	_current_frame = idx
	$SpriteA.texture = _textures[idx]

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	if not _ready_done:
		_cy = cam.get_screen_center_position().y
		_ready_done = true

	_elapsed = minf(_elapsed + delta, transition_duration)
	var t := _elapsed / transition_duration
	_apply_frame(mini(int(t * (FRAME_COUNT - 1)), FRAME_COUNT - 1))

	$SpriteA.global_position = Vector2(cam.get_screen_center_position().x, _cy - 50.0)
