extends Node2D

const THUG_SCENE         := preload("res://scenes/enemies/Thug.tscn")
const COP_SCENE          := preload("res://scenes/enemies/Cop.tscn")
const WAITER_SCENE       := preload("res://scenes/enemies/Waiter.tscn")
const WAITER_DARK_SCENE  := preload("res://scenes/enemies/WaiterDark.tscn")
const WAITER_LIGHT_SCENE := preload("res://scenes/enemies/WaiterLight.tscn")
const HUD_SCENE          := preload("res://scenes/HUD.tscn")

const LEVEL_LENGTH := 32000.0

# ── Autos laterales (obstáculos plataforma) ──────────────────────────────────
# Scale calculado: ancho intermedio entre traseros (195px) y frontales (910px)
# → target 553px / sprite_w 1364px = 0.4056
const CAR_SIDE_SCALE   := 0.4056
const CAR_CANVAS_W     := 1396.0   # canvas normalizado del sprite
const CAR_CANVAS_H     := 496.0
const CAR_BODY_W       := 1364.0   # carrocería dentro del canvas
const CAR_BODY_H       := 464.0
const CAR_PAD          := 16.0     # padding del canvas
const CAR_FLOOR_Y      := 730.0    # 50px más abajo que el piso del PP
const CAR_SIDE_FRAMES  := 1        # cuántos frames tenemos por ahora (test)

const NIGHT_ENEMY := Color(0.52, 0.47, 0.60)

const WAVE_TRIGGER_DIST := 500.0
const WAVE_COUNT        := 3
const _WAITER_DEAD      := 4   # State.DEAD en waiter.gd

var _boss_node:      Node2D = null
var _cam_limit       := 0.0
var _wave_index      := 0
var _wave_triggered  := false
var _wave_enemies:   Array  = []
var _floor_right_x:  float  = 32000.0
var _left_wall:      AnimatableBody2D = null

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

	# Tinte nocturno en capas intermedias (el fondo lejano queda intacto)
	var night := Color(0.40, 0.35, 0.50)
	for path in ["MidScroll", "SidewalkScroll", "FloorScroll", "BuildingsLayer",
				 "TrafficRearLayer", "TrafficFrontLayer"]:
		var n := get_node_or_null(path)
		if n:
			n.modulate = night

	# Las luces (drone, faroles) no afectan el fondo ni el humo
	for path in ["BGScroll", "SmokeFar", "SmokeNear"]:
		var n := get_node_or_null(path)
		if n:
			_disable_lighting(n)

	# MidScroll: sin luces de faroles, solo luces del drone a mitad de intensidad
	# Usamos light_mask=2 para que los faroles (mask=1) no la afecten
	var mid := get_node_or_null("MidScroll")
	if mid:
		_disable_lighting(mid)
		for child in mid.get_children():
			if child is CanvasItem:
				(child as CanvasItem).light_mask = 2

	var night_char := Color(0.72, 0.68, 0.82)
	var player := get_node_or_null("Player")
	if player:
		player.modulate = night_char

	# Pared izquierda dinámica — empieza fuera de pantalla a la izquierda
	_create_left_wall(-9999)

	# Boss: desactivar completamente hasta que el drone escape
	var boss_node := get_node_or_null("Boss")
	if boss_node:
		boss_node.process_mode = Node.PROCESS_MODE_DISABLED
		if boss_node is CollisionObject2D:
			(boss_node as CollisionObject2D).collision_layer = 0
			(boss_node as CollisionObject2D).collision_mask  = 0

	# HUD
	var hud: Node = HUD_SCENE.instantiate()
	add_child(hud)

	#_boss_node = get_node_or_null("Boss")

	# Modo infinito: sin límite de cámara ni pared final

	# Capa de autos del medio (obstáculos/plataformas)
	var mid_layer := Node2D.new()
	mid_layer.set_script(load("res://scripts/car_mid_layer.gd"))
	mid_layer.name = "CarMidLayer"
	mid_layer.modulate = Color(0.55, 0.50, 0.65)
	add_child(mid_layer)

	# Colectivos y policías integrados en CarMidLayer
	get_tree().debug_collisions_hint = true

	# Mozos (tiran platos) repartidos a lo largo del nivel, antes del boss (~14600)
	#_spawn_waiter(3000)
	#_spawn_waiter_light(8000)
	#_spawn_waiter_dark(13000)

func _disable_lighting(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).light_mask = 0
	for child in node.get_children():
		_disable_lighting(child)

func _set_camera_limit() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player: return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if not cam: return
	var bl := get_node_or_null("BuildingsLayer")
	if bl:
		var piz_base: float = bl.get("pizzeria_base_x")
		const PIZ_W := 2172.0 * (266.0 / 724.0)   # ancho visual de la pizzeria ~798px
		var half_vp := get_viewport().get_visible_rect().size.x * 0.5 / cam.zoom.x
		# parallax 1.2: visual_pos = base - 0.2*cam  →  centrar: base + PIZ_W/2 = 1.2*cam
		var limit := int((piz_base + PIZ_W * 0.5) / 1.2 + half_vp)
		cam.limit_right = limit
		_cam_limit = float(limit)
		_create_right_wall(limit)
		if _boss_node:
			_boss_node.position = Vector2(_cam_limit - 550.0, 560.0)
			_boss_node.visible  = true
			(_boss_node as Node2D).modulate = NIGHT_ENEMY
			var drone := get_node_or_null("Drone")
			if drone:
				drone.set("retreat_trigger_x", _boss_node.position.x - 300.0)
		# Farol: oculta los que caen sobre la pizzeria, agrega uno sobre el edificio derecho
		var sl := get_node_or_null("StreetlampLayer")
		if sl:
			var right_building_x := piz_base + PIZ_W - 35.0
			sl.call("finalize_for_pizzeria", piz_base - 100.0, piz_base + PIZ_W + 100.0, right_building_x)
	else:
		cam.limit_right = int(LEVEL_LENGTH)
		_create_right_wall(int(LEVEL_LENGTH))

func _extend_floor() -> void:
	const SEG_W := 32000.0
	var body := StaticBody2D.new()
	body.position = Vector2(_floor_right_x + SEG_W * 0.5, 727.6)
	var col   := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SEG_W, 16.0)
	col.shape  = shape
	body.add_child(col)
	add_child(body)
	_floor_right_x += SEG_W

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and _left_wall:
		var half_vp  := get_viewport().get_visible_rect().size.x * 0.5 / cam.zoom.x
		# Usar posición del player (no de la cámara) para evitar feedback loop con limit_left.
		var player_node := get_tree().get_first_node_in_group("player") as Node2D
		if player_node:
			var target_x := player_node.global_position.x - half_vp
			_left_wall.global_position.x = maxf(_left_wall.global_position.x, target_x)
			cam.limit_left = int(_left_wall.global_position.x) - int(cam.offset.x)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.x > _floor_right_x - 5000.0:
		_extend_floor()
	if not player or not _boss_node:
		return
	if not _wave_triggered:
		if player.global_position.x >= _boss_node.global_position.x - WAVE_TRIGGER_DIST:
			_wave_triggered = true
			_spawn_wave()
		return
	if _wave_index >= WAVE_COUNT or _wave_enemies.is_empty():
		return
	var all_dead := true
	for e in _wave_enemies:
		if is_instance_valid(e) and e.get("state") != _WAITER_DEAD:
			all_dead = false
			break
	if all_dead:
		_spawn_wave()

func _spawn_wave() -> void:
	_wave_index += 1
	_wave_enemies.clear()
	_wave_enemies.append(_spawn_wave_waiter(_boss_node.global_position.x - 1400.0, 600.0))
	_wave_enemies.append(_spawn_wave_waiter(_cam_limit - 50.0, 600.0))

func _spawn_wave_waiter(x: float, y: float) -> Node:
	var scenes := [WAITER_SCENE, WAITER_DARK_SCENE, WAITER_LIGHT_SCENE]
	var waiter: Node = scenes[randi() % scenes.size()].instantiate()
	(waiter as Node2D).position = Vector2(x, y)
	(waiter as Node2D).modulate = NIGHT_ENEMY
	add_child(waiter)
	return waiter

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

func _spawn_cop(x: float) -> void:
	var cop: Node = COP_SCENE.instantiate()
	(cop as Node2D).position = Vector2(x, 600.0)
	(cop as Node2D).modulate = NIGHT_ENEMY
	add_child(cop)

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

# ── Auto lateral (obstáculo/plataforma) ─────────────────────────────────────
# frame_idx: número de sprite (0-9). El auto es sólido: bloquea lateralmente
# y tiene superficie superior donde el PP puede pararse (techo y capó).
func _spawn_side_car(x: float, frame_idx: int) -> void:
	var sc  := CAR_SIDE_SCALE
	var tex: Texture2D = load("res://assets/sprites/cars/side_test/car_side_%02d.png" % frame_idx)
	if not tex:
		push_warning("car_side_%02d.png no encontrado" % frame_idx)
		return

	var body := StaticBody2D.new()
	body.position = Vector2(x, CAR_FLOOR_Y)
	body.z_index  = 3   # entre trasera (z=2) y delantera (z=4)
	add_child(body)

	# Sprite: centered=false, bottom del canvas alineado al piso
	var sp := Sprite2D.new()
	sp.texture  = tex
	sp.centered = false
	sp.scale    = Vector2(sc, sc)
	# En espacio del body: top-left en (-canvas_w*sc/2, -canvas_h*sc)
	sp.position = Vector2(-CAR_CANVAS_W * sc * 0.5, -CAR_CANVAS_H * sc)
	body.add_child(sp)

	# Colisión rectangular: cubre toda la carrocería (ruedas → techo)
	# Centro en y = -(CAR_PAD + CAR_BODY_H/2) * sc  respecto al body (floor)
	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size    = Vector2(CAR_BODY_W * sc, CAR_BODY_H * sc)
	col.shape    = rect
	col.position = Vector2(0.0, -(CAR_PAD + CAR_BODY_H * 0.5) * sc)
	body.add_child(col)

# ── Pared invisible al inicio del nivel (impide retroceder) ─────────────────
func _create_left_wall(x: int) -> void:
	var wall := AnimatableBody2D.new()
	wall.sync_to_physics = false
	wall.position = Vector2(x, 400.0)
	var col   := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32.0, 1200.0)
	col.shape  = shape
	wall.add_child(col)
	add_child(wall)
	_left_wall = wall

# ── Pared invisible al final del nivel ──────────────────────────────────────
func _create_right_wall(x: int) -> void:
	var wall := StaticBody2D.new()
	wall.position = Vector2(x, 400.0)
	var col   := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32.0, 1200.0)
	col.shape  = shape
	wall.add_child(col)
	add_child(wall)

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
