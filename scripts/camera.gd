extends Camera2D

var _fixed_y    : float
var _base_offset: Vector2

func _ready() -> void:
	_fixed_y              = global_position.y
	_base_offset          = offset
	position_smoothing_enabled = false
	limit_left            = -10000000
	limit_right           = 10000000

func _process(_delta: float) -> void:
	global_position.y = _fixed_y
	offset            = _base_offset
