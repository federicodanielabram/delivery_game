extends Node2D

const LEVEL_WIDTH: int = 500000
const DEPTH: int = 400

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, LEVEL_WIDTH, DEPTH), Color(0.08, 0.08, 0.12))
