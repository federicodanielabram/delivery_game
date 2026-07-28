extends Camera2D

var _fixed_y: float

func _ready() -> void:
	_fixed_y = global_position.y

func _process(_delta: float) -> void:
	global_position.y = _fixed_y
