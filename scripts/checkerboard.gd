extends Node2D

const FLOOR_Y := 624.0
const CELL    := 32.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var xf  := get_canvas_transform().affine_inverse()
	var tl  := xf * Vector2.ZERO
	var br  := xf * Vector2(1280.0, 720.0)

	var c0 := floori(tl.x / CELL)
	var c1 := ceili(br.x  / CELL)
	var r0 := floori(tl.y / CELL)
	var r1 := ceili(minf(br.y, FLOOR_Y) / CELL)

	for row in range(r0, r1 + 1):
		for col in range(c0, c1 + 1):
			var light := (row + col) % 2 == 0
			var color := Color(0.22, 0.22, 0.30) if light else Color(0.16, 0.16, 0.23)
			draw_rect(Rect2(col * CELL, row * CELL, CELL, CELL), color)

	draw_rect(Rect2(tl.x, FLOOR_Y, br.x - tl.x, br.y - FLOOR_Y), Color(0.18, 0.14, 0.10))
	draw_rect(Rect2(tl.x, FLOOR_Y, br.x - tl.x, 2.0),            Color(0.12, 0.10, 0.08))
