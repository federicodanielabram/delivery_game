extends Node2D

const THUG_SCENE         := preload("res://scenes/enemies/Thug.tscn")
const WAITER_SCENE       := preload("res://scenes/enemies/Waiter.tscn")
const WAITER_DARK_SCENE  := preload("res://scenes/enemies/WaiterDark.tscn")
const WAITER_LIGHT_SCENE := preload("res://scenes/enemies/WaiterLight.tscn")
const HUD_SCENE          := preload("res://scenes/HUD.tscn")

# Largo del nivel (6x el original de 2560)
const LEVEL_LENGTH := 15360.0

# Colores de obstáculos
const COL_PLATFORM := Color(0.15, 0.15, 0.2,  1.0)
const COL_EDGE     := Color(0.3,  0.8,  1.0,  1.0)
const COL_BOX      := Color(0.6,  0.4,  0.1,  1.0)
const COL_TUNNEL   := Color(0.12, 0.12, 0.18, 1.0)
const COL_DOOR     := Color(0.55, 0.28, 0.08, 1.0)
const COL_FLOOR    := Color(0.15, 0.15, 0.2,  1.0)

# Plataformas elevadas [x_centro, y, ancho]
const PLATFORMS := [
	[200,  168, 80],
	[420,  140, 80],
	[790,  120, 80],
	[1050, 150, 90],
	[1180, 130, 80],
]

func _ready() -> void:
	#for p in PLATFORMS:
		#_create_platform(p[0], p[1], p[2])

	## Cajas para saltar
	#_create_box(300, 24)
	#_create_box(500, 24)
	#_create_box(900, 32)

	## Túnel estrecho (hay que agacharse)
	#_create_tunnel(650, 120, 155)

	## Puerta de madera (hay que golpear con Z)
	#_create_door(1000)

	# HUD
	var hud: Node = HUD_SCENE.instantiate()
	add_child(hud)

	# Extender el límite de cámara al largo del nivel
	_set_camera_limit()

	# Mozos (tiran platos) repartidos a lo largo del nivel, antes del boss (~14600)
	#_spawn_waiter(3000)
	#_spawn_waiter_light(8000)
	#_spawn_waiter_dark(13000)

func _set_camera_limit() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player: return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.limit_right = int(LEVEL_LENGTH)

func _spawn_waiter(x: float) -> void:
	var waiter: Node = WAITER_SCENE.instantiate()
	(waiter as Node2D).position = Vector2(x, 600.0)
	add_child(waiter)

func _spawn_waiter_dark(x: float) -> void:
	var waiter: Node = WAITER_DARK_SCENE.instantiate()
	(waiter as Node2D).position = Vector2(x, 600.0)
	add_child(waiter)

func _spawn_waiter_light(x: float) -> void:
	var waiter: Node = WAITER_LIGHT_SCENE.instantiate()
	(waiter as Node2D).position = Vector2(x, 600.0)
	add_child(waiter)

func _spawn_thug(x: float) -> void:
	var thug: Node = THUG_SCENE.instantiate()
	(thug as Node2D).position = Vector2(x, 190.0)
	add_child(thug)

# ── Plataforma elevada ──────────────────────────────────────────────────────
func _create_platform(x: float, y: float, w: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x, y)

	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 8)
	col.shape = rect
	body.add_child(col)

	var fill := ColorRect.new()
	fill.position = Vector2(-w / 2.0, -4.0)
	fill.size     = Vector2(w, 8.0)
	fill.color    = COL_PLATFORM
	body.add_child(fill)

	var edge := ColorRect.new()
	edge.position = Vector2(-w / 2.0, -4.0)
	edge.size     = Vector2(w, 2.0)
	edge.color    = COL_EDGE
	body.add_child(edge)

	add_child(body)

# ── Caja (obstacle: saltar) ─────────────────────────────────────────────────
func _create_box(x: float, size: float) -> void:
	var body := StaticBody2D.new()
	# El piso está en y=208; la caja se apoya sobre él
	body.position = Vector2(x, 208.0 - size / 2.0)

	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size, size)
	col.shape = rect
	body.add_child(col)

	var fill := ColorRect.new()
	fill.position = Vector2(-size / 2.0, -size / 2.0)
	fill.size     = Vector2(size, size)
	fill.color    = COL_BOX
	body.add_child(fill)

	add_child(body)

# ── Túnel (obstacle: agacharse) ──────────────────────────────────────────────
# x_centro: centro del túnel, ancho: ancho del pasaje, ceil_y: y del techo
func _create_tunnel(x_centro: float, ancho: float, ceil_y: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x_centro, ceil_y)

	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ancho, 8)
	col.shape = rect
	body.add_child(col)

	var fill := ColorRect.new()
	fill.position = Vector2(-ancho / 2.0, -4.0)
	fill.size     = Vector2(ancho, 8.0)
	fill.color    = COL_TUNNEL
	body.add_child(fill)

	add_child(body)

	# Pilares visuales en los costados del túnel
	_add_tunnel_pillar(x_centro - ancho / 2.0 - 4.0, ceil_y)
	_add_tunnel_pillar(x_centro + ancho / 2.0 + 4.0, ceil_y)

func _add_tunnel_pillar(x: float, ceil_y: float) -> void:
	var h    := 208.0 - ceil_y
	var rect := ColorRect.new()
	rect.position = Vector2(x, ceil_y)
	rect.size     = Vector2(8.0, h)
	rect.color    = COL_TUNNEL
	add_child(rect)

# ── Puerta (obstacle: golpear con Z) ────────────────────────────────────────
func _create_door(x: float) -> void:
	var door_h  := 56.0
	var door_w  := 12.0
	var door_cy := 208.0 - door_h / 2.0

	var body := StaticBody2D.new()
	body.position = Vector2(x, door_cy)
	body.add_to_group("door")
	body.set_script(load("res://scripts/door.gd"))

	var col  := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(door_w, door_h)
	col.shape = rect
	body.add_child(col)

	var visual := ColorRect.new()
	visual.name     = "Visual"
	visual.position = Vector2(-door_w / 2.0, -door_h / 2.0)
	visual.size     = Vector2(door_w, door_h)
	visual.color    = COL_DOOR
	body.add_child(visual)

	add_child(body)
