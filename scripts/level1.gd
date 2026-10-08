extends Node2D

const THUG_SCENE         := preload("res://scenes/enemies/Thug.tscn")
const COP_SCENE          := preload("res://scenes/enemies/Cop.tscn")
const WAITER_SCENE       := preload("res://scenes/enemies/Waiter.tscn")
const WAITER_DARK_SCENE  := preload("res://scenes/enemies/WaiterDark.tscn")
const WAITER_LIGHT_SCENE := preload("res://scenes/enemies/WaiterLight.tscn")
const HUD_SCENE          := preload("res://scenes/HUD.tscn")


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
const NIGHT_PLAYER := Color(0.76, 0.70, 0.90)   # ver _ready() — mismo tinte que el PP (subido un poco)
const BOSS_TINT_EXTRA := Color(0.7, 0.7, 0.7, 1.0)   # extra oscurecido — arte del boss es blanco, compensa

const _BOSS_STATE_IDLE       := 0   # State.IDLE en boss.gd
const _BOSS_STATE_APPROACH   := 1   # State.APPROACH en boss.gd
const _BOSS_STATE_DEAD       := 5   # State.DEAD en boss.gd
const _BOSS_STATE_INTRO_WALK := 6   # State.INTRO_WALK en boss.gd

# Bordes del hitbox del boss relativos a su global_position.x — Boss.tscn:
# CollisionShape2D.position.x (12.5) ± CapsuleShape2D.radius (88.5).
const _BOSS_RIGHT_EDGE_OFFSET := 101.0
const _BOSS_LEFT_EDGE_OFFSET  := -76.0
const _WAITER_RADIUS          := 15.6   # Waiter*.tscn CapsuleShape2D.radius

const _WAITER_DEAD      := 5   # State.DEAD en waiter.gd (enum: ENTRANCE,PATROL,ALERT,THROW,HURT,DEAD — era 4, que es HURT)

# Capa de colisión exclusiva de las paredes invisibles de la arena (izq/der) —
# nadie más la usa hoy. Solo el PP la tiene en su collision_mask (ver
# _update_collision en player.gd), así que boss/mozos/cops la atraviesan.
const WALL_LAYER := 16

# ── DEBUG: saltar directo a la pizzeria ───────────────────────────────────────
# Con esto en true, el nivel arranca como si ya hubieras escapado del dron
# (mismo camino que el escape real — ver Drone.escaped en drone.gd y el chequeo
# en _process): te ahorrás la persecución y llegás en PIZZERIA_RUNWAY px nomás,
# para iterar rápido en la pelea del boss. Volver a false para el flujo normal.
const DEBUG_SKIP_DRONE_CHASE := false

# Con esto en true, el casillero de mozos no arranca nunca al llegar a la
# arena — queda 1v1 solo contra el boss, para poder sentir su timing sin
# interferencia. Volver a false para el flujo normal.
const DEBUG_DISABLE_WAITERS := false

# ── Mecánica: parar al boss/mozos con los pies apoyados en el piso ───────────
# Boss y Waiter son CharacterBody2D SIN offset: su Sprite2D/AnimatedSprite2D y
# su CollisionShape2D (una cápsula) están centrados en el origen del nodo. Eso
# quiere decir que "position.y" es el CENTRO vertical de la cápsula, no los
# pies — los pies (borde de ABAJO de su propia cápsula) están en
# `position.y + altura_capsula/2`.
#
# El piso real es el nodo "Floor" (StaticBody2D, ver Game.tscn):
#   position.y = 727.6 · shape (RectangleShape2D) height = 16
#   → borde de ARRIBA del hitbox del piso = 727.6 - 16/2 = 719.6  (acá se para todo)
#   → borde de abajo (enterrado)          = 727.6 + 16/2 = 735.6  (no se usa)
#
# Para que los pies (borde de abajo de SU cápsula) coincidan con el borde de
# arriba del piso, despejamos position.y:
#     pies == FLOOR_TOP_Y
#     position.y + capsula_h/2 == FLOOR_TOP_Y
#     position.y := FLOOR_TOP_Y - capsula_h/2
const FLOOR_TOP_Y := 719.6   # borde de arriba del hitbox de "Floor" — Game.tscn

const BOSS_CAPSULE_H   := 90.0   # NO es Boss.tscn → CapsuleShape2D.height (eso ahora es 240,
								   # agrandada a pedido varias veces: +50px de ancho por lado,
								   # +35px más hacia la derecha, +150px hacia arriba en total —
								   # ver Boss.tscn/CollisionShape2D). Este valor es el doble de
								   # la distancia real del centro del nodo al borde de ABAJO
								   # (45px), que nunca se movió — todo el agrandado se hizo
								   # asimétrico a propósito (corriendo el shape hacia arriba/
								   # derecha) para no tocar dónde pisa. No cambiar sin recalcular.
const WAITER_CAPSULE_H := 68.0   # Waiter/Dark/Light → CapsuleShape2D.height (las 3 comparten)

const BOSS_LIFT_PX := 80.0    # ajuste manual pedido: el boss (hitbox) queda 80px más arriba que sus pies reales (100 - 20)

const BOSS_FLOOR_Y   := FLOOR_TOP_Y - BOSS_CAPSULE_H   / 2.0 - BOSS_LIFT_PX  # = 574.6 (pies "reales" en 719.6, subido 80px)
const WAITER_FLOOR_Y := FLOOR_TOP_Y - WAITER_CAPSULE_H / 2.0                 # = 685.6, pies en 719.6

var _boss_node:      Node2D = null
var _floor_right_x:  float  = 32000.0
var _left_wall:      AnimatableBody2D = null

# Fin de nivel: escapar del dron dispara la pizzeria (ver _process/_trigger_pizzeria_ending)
const PIZZERIA_RUNWAY := 5000.0   # px de "pista" corriendo después de escapar, antes de que aparezca
const BOSS_SCREEN_POS := 0.80     # posición del boss en la pantalla final (0=izq, 1=der) — 20% del borde derecho
var _escape_triggered  := false
var _arrived_pizzeria  := false
var _pizzeria_x        := 0.0     # borde izquierdo real del edificio de la pizzeria
var _arena_left         := 0.0    # límites de la pantalla fija final (una sola pantalla, sin scroll)
var _arena_right        := 0.0
var _arena_center       := 0.0    # centro real de la arena EN EL PISO — coincide con el centro
	# visual del edificio de la pizzeria (ver _trigger_pizzeria_ending, donde el
	# edificio se planta centrado en arena_center, no en _pizzeria_x — el boss
	# está al 80% de la pantalla, BOSS_SCREEN_POS, pero la pizzeria al 50%).
	# Es el punto al que camina el boss en la intro (ver start_intro_walk).
var _arena_seal_trigger_x := 0.0  # x de mundo donde hay que sellar sin salto (ver _trigger_pizzeria_ending)

# Pausa de llegada: la cámara se traba de una al llegar (_seal_pizzeria_arena),
# y el PP sigue corriendo con control normal hasta PLAYER_INTRO_SCREEN_POS de
# esa pantalla ya fija — ahí, y solo ahí, se frena en seco y queda en IDLE,
# congelado, sin poder moverse. Ahí arranca la entrada escrita: el boss (ver
# start_intro_walk en boss.gd) camina despacio desde donde aparece hasta
# _arena_center — más adelante, cuando haya diálogo, también hablaría acá. El
# freeze dura lo que tarde esa caminata (variable, no un tiempo fijo) más
# INTRO_POST_WALK_PAUSE de aire después de llegar, y recién ahí se libera al
# PP y arranca la pelea de verdad (ver _process, bloque de _intro_active).
const PLAYER_INTRO_SCREEN_POS := 0.20   # 20% del borde izquierdo, como pidió
const INTRO_POST_WALK_PAUSE   := 0.5    # beat después de que el boss llega, antes de soltar todo
var _intro_target_x  := 0.0
var _intro_pending   := false   # true entre "llegó a la arena" y "llegó al punto de frenada"
var _intro_active    := false   # true durante TODA la intro (caminata del boss + pausa)
var _intro_walk_done := false   # true una vez que el boss ya llegó a _arena_center
var _intro_timer     := 0.0     # solo cuenta durante la pausa final, después de _intro_walk_done

# ── Primera pareja de mozos: entrada escrita (derecha, después izquierda) ────
# No es el sistema de casilleros de siempre (ver más abajo, hoy dormido) —
# acá el orden es fijo y secuencial a propósito: entra SOLO uno a la vez,
# alternando lado (derecha, izquierda, derecha, izquierda...), y recién cuando
# muere entra el siguiente por el otro lado. Sigue así indefinidamente
# mientras el boss siga vivo — la idea es forzar al jugador a decidir:
# ¿esquivo/paso al boss para ir a callar al mozo molesto, o lo dejo tirando
# platos y peleo al boss primero? Se corta solo cuando el boss muere (ver
# _tick_first_duel).
var _duel_active       := false
var _duel_next_is_right := true   # qué lado le toca al próximo mozo
var _duel_current: Node = null
var _duel_respawn_timer: float = 0.0   # cuenta regresiva tras morir, antes de entrar el siguiente (ver _tick_first_duel)

# ── Mozos: sistema de 2 casilleros (izquierda/derecha) ───────────────────────
# DORMIDO por ahora (ver _first_duel_* arriba, que lo reemplaza para esta
# primera pareja) — queda el código listo para cuando sigamos agregando flujo
# después de la primera pareja. Nada de "oleadas": cada costado mantiene como
# mucho un mozo vivo. Cuando se vacía (muere, o todavía no entró nadie),
# arranca una pausa de WAITER_RESPAWN_DELAY ("para respirar", pedido
# explícito) y recién ahí entra el reemplazo, siempre por EL MISMO costado.
# Tope global de WAITER_TOTAL_CAP — una vez alcanzado, los casilleros dejan de
# rellenarse (ahí es 1v1 con el boss). Números en la línea de un beat-em-up
# clásico (Streets of Rage/Final Fight): nunca más de 2 en pantalla, entran de
# a uno con respiro, total acotado antes del boss real.
const WAITER_TOTAL_CAP       := 6
const WAITER_RESPAWN_DELAY   := 3.6   # pausa para respirar antes del reemplazo
const WAITER_INITIAL_STAGGER := 1.0   # la izquierda arranca 1s después que la derecha
var _waiter_slots_active   := false
var _waiters_spawned_total := 0
var _waiter_right:        Node  = null
var _waiter_left:         Node  = null
var _waiter_right_timer:  float = 0.0
var _waiter_left_timer:   float = 0.0

# El boss, durante el acercamiento, tiene que moverse al mismo ritmo que un
# cop/auto de CarMidLayer (parallax=1.2, ver car_mid_layer.gd) — antes se
# dibujaba en su x real (parallax=1, como el jugador), y eso lo hacía ver
# "raro" respecto a los demás elementos de su mismo plano. _boss_base_x es su
# referencia sin parallax; cada frame (mientras se acerca) se reposiciona con
# la misma fórmula que usan cops/autos, compensada para que, en el instante
# en que la cámara se traba, caiga exacto en _pizzeria_x (ver
# _trigger_pizzeria_ending y el bloque en _process).
const BOSS_PARALLAX := 1.2   # mismo valor que car_mid_layer.gd — "como un cop"
var _boss_base_x := 0.0

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
	for path in ["MidScroll", "SidewalkScroll", "FloorScroll", "TrafficFrontLayer"]:
		var n := get_node_or_null(path)
		if n:
			n.modulate = night

	# Edificios frontales y línea de tráfico de fondo (autos/motos detrás): bastante
	# más oscuros que el resto (mismo matiz, la mitad de intensidad) para que
	# PP/dron/obstáculos resalten más por contraste.
	var buildings_night := Color(0.22, 0.20, 0.30)
	for path in ["BuildingsLayer", "TrafficRearLayer"]:
		var n2 := get_node_or_null(path)
		if n2:
			n2.modulate = buildings_night

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

	# Mismo tinte base que cop/autos/aéreos/buses/camiones (ver CarMidLayer más abajo
	# y COP_TINT en car_mid_layer.gd) — probando a encontrar el nivel justo para
	# todo el grupo "central" (PP + obstáculos), en tinte plano nada más (las luces
	# dinámicas del dron/faroles quedan aparte).
	var player := get_node_or_null("Player")
	if player:
		player.modulate = NIGHT_PLAYER

	# Pared izquierda dinámica — empieza fuera de pantalla a la izquierda
	_create_left_wall(-9999)

	# Boss: desactivar completamente hasta que el drone escape (ver _trigger_pizzeria_ending)
	_boss_node = get_node_or_null("Boss")
	if _boss_node:
		_boss_node.process_mode = Node.PROCESS_MODE_DISABLED
		if _boss_node is CollisionObject2D:
			(_boss_node as CollisionObject2D).collision_layer = 0
			(_boss_node as CollisionObject2D).collision_mask  = 0

	# HUD
	var hud: Node = HUD_SCENE.instantiate()
	add_child(hud)

	# Precalentar sprites de mozos — evita el microcorte al llegar a la arena
	# del boss. Ver _prewarm_waiter_sprites().
	_prewarm_waiter_sprites()

	# Modo infinito hasta escapar del dron — a partir de ahí, fin de nivel con
	# la pizzeria (ver _trigger_pizzeria_ending, disparado desde _process()).

	if DEBUG_SKIP_DRONE_CHASE:
		var drone := get_node_or_null("Drone")
		if drone:
			drone.set("escaped", true)   # _process lo detecta al toque y dispara el escape real

	# Capa de autos del medio (obstáculos/plataformas)
	var mid_layer := Node2D.new()
	mid_layer.set_script(load("res://scripts/car_mid_layer.gd"))
	mid_layer.name = "CarMidLayer"
	mid_layer.modulate = Color(0.66, 0.60, 0.78)
	add_child(mid_layer)

	# Colectivos y policías integrados en CarMidLayer

	# Mozos (tiran platos) repartidos a lo largo del nivel, antes del boss (~14600)
	#_spawn_waiter(3000)
	#_spawn_waiter_light(8000)
	#_spawn_waiter_dark(13000)

func _disable_lighting(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).light_mask = 0
	for child in node.get_children():
		_disable_lighting(child)

func _extend_floor() -> void:
	const SEG_W := 32000.0
	# SEG_OVERLAP: el segmento nuevo arranca un poco ANTES de _floor_right_x en
	# vez de justo ahí, para solapar con el anterior (el del .tscn incluido).
	# Dos StaticBody2D tocándose borde a borde exacto generan un enganche
	# invisible en la costura (bug físico conocido de Godot) — el jugador se
	# frena ahí como si hubiera una pared, aunque no hay ninguna shape de más.
	const SEG_OVERLAP := 64.0
	var seg_left  := _floor_right_x - SEG_OVERLAP
	var seg_width := SEG_W + SEG_OVERLAP
	var body := StaticBody2D.new()
	body.position = Vector2(seg_left + seg_width * 0.5, 727.6)
	var col   := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(seg_width, 16.0)
	col.shape  = shape
	body.add_child(col)
	add_child(body)
	print("[floor] nuevo segmento %.0f → %.0f" % [seg_left, seg_left + seg_width])  # DEBUG temporal
	_floor_right_x += SEG_W

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	# Una vez encerrado en la pizzeria, esto se congela — _seal_pizzeria_arena ya
	# dejó cam.limit_left fijo, y este bloque (pensado para el modo infinito, sigue
	# al jugador hacia adelante) lo volvería a correr cada frame si no se lo frena.
	if cam and _left_wall and not _arrived_pizzeria:
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

	# Escapar del dron termina el modo infinito: la pizzeria aparece de forma
	# orgánica unos pasos más adelante (mismo mecanismo de generación anticipada
	# que usa todo lo demás — no es un corte ni un teletransporte).
	if not _escape_triggered and player:
		var drone := get_node_or_null("Drone")
		if drone and drone.get("escaped") == true:
			_escape_triggered = true
			_trigger_pizzeria_ending(player.global_position.x, player.global_position.x + PIZZERIA_RUNWAY)

	# El boss se reposiciona cada frame al mismo ritmo que un charco/cop
	# (parallax=1.2) — ver _boss_base_x. Esto corre TODO el tiempo, incluida
	# la pelea y DESPUÉS de muerto: aunque la arena esté "sellada", la cámara
	# igual sigue un poco al jugador dentro del margen (ver
	# _seal_pizzeria_arena) — si el boss (vivo o muerto) dejara de reaccionar
	# a eso, se ve desincronizado del fondo (edificios/tráfico/charcos), que sí
	# lo siguen haciendo. Solo se excluye durante INTRO_WALK (se mueve solo,
	# caminando al centro, con su propia lógica de posición).
	# _boss_base_x se recalcula en dos momentos para que esta fórmula caiga
	# exacta en el punto donde el boss REALMENTE debe estar en ese instante:
	# primero en _trigger_pizzeria_ending (ancla en _pizzeria_x, mientras se
	# acerca), y de nuevo apenas termina la caminata de entrada — intro_walk_done
	# — (ancla en _arena_center, ver el bloque de _intro_active más abajo) — si
	# no, al volver a aplicarse después de la caminata (incluido el hueco de la
	# pausa antes de begin_combat), teletransportaría al boss de vuelta al 80%
	# de pantalla, deshaciendo la entrada.
	if _escape_triggered and _boss_node and cam \
			and _boss_node.get("state") != _BOSS_STATE_INTRO_WALK:
		var boss_cam_x := cam.get_screen_center_position().x
		_boss_node.position.x = _boss_base_x + boss_cam_x * (1.0 - BOSS_PARALLAX)

	# "Llegar" = el momento en que lo que YA se ve en pantalla (cámara libre,
	# con su offset de adelanto) coincide con el centro de la arena — NO
	# cuando el PP cruza _arena_left en x de mundo crudo (ver
	# _arena_seal_trigger_x en _trigger_pizzeria_ending para el porqué).
	if _escape_triggered and not _arrived_pizzeria and player \
			and player.global_position.x >= _arena_seal_trigger_x:
		_arrived_pizzeria = true
		_seal_pizzeria_arena()

	# Sigue corriendo (ya en la pantalla fija) hasta el punto de frenada — ahí
	# lo clavamos en IDLE y arranca la pausa de intro.
	if _intro_pending and player and player.global_position.x >= _intro_target_x:
		_intro_pending = false
		_start_boss_intro(player)

	if _intro_active:
		if not _intro_walk_done:
			# Esperando a que el boss termine de caminar hasta _arena_center
			# (start_intro_walk). Cuando haya diálogo, acá también se esperaría
			# a que termine de hablar.
			if _boss_node and _boss_node.get("intro_walk_done") == true:
				_intro_walk_done = true
				_intro_timer     = INTRO_POST_WALK_PAUSE
				# Recalcular el ancla del parallax: de acá en más el boss vive
				# en _arena_center, no en _pizzeria_x (ver comentario en el
				# reposicionamiento más arriba en este mismo _process).
				_boss_base_x = _arena_center * BOSS_PARALLAX
		else:
			_intro_timer -= delta
			if _intro_timer <= 0.0:
				_intro_active = false
				if player:
					player.call("set_cutscene_lock", false)
				if _boss_node:
					_boss_node.call("begin_combat")
				if not DEBUG_DISABLE_WAITERS:
					_start_first_duel()

	# Duelo de mozos alternado (entrada escrita, ver comentario junto a
	# _duel_active) — arranca recién cuando termina toda la intro de arriba,
	# no durante el freeze.
	if _duel_active:
		_tick_first_duel(delta)

	# Casilleros de mozos — dormido por ahora (ver _duel_* arriba, que lo reemplaza).
	if _waiter_slots_active:
		_tick_waiter_slots(delta)


# Se dispara una sola vez, apenas el dron marca escaped=true. El boss y el
# edificio de la pizzeria van en el MISMO punto (anchor_x) — ahí termina el
# mundo: nada se genera más allá (ni edificios comunes, ni tráfico). La
# pantalla fija final se arma hacia atrás desde ese punto, de manera que el
# boss quede a BOSS_SCREEN_POS del ancho de esa pantalla. La cámara todavía NO
# se traba acá — eso pasa recién al llegar (_seal_pizzeria_arena), para no
# cortar la pista de antemano.
#
# escape_x: dónde estaba el jugador justo al escapar del dron. A partir de ahí
# no se generan más obstáculos (autos/cops/aéreos) — la pista de PIZZERIA_RUNWAY
# px se corre limpia. Los edificios y el tráfico de fondo, en cambio, siguen
# generándose hasta anchor_x (ahí sí frenan) para que el fondo no se sienta vacío.
func _trigger_pizzeria_ending(escape_x: float, anchor_x: float) -> void:
	_pizzeria_x = anchor_x

	var half_vp := 600.0
	var cam := get_viewport().get_camera_2d()
	if cam:
		half_vp = get_viewport().get_visible_rect().size.x * 0.5 / cam.zoom.x
	var vp_w := half_vp * 2.0
	_arena_right = _pizzeria_x + (1.0 - BOSS_SCREEN_POS) * vp_w
	_arena_left  = _arena_right - vp_w

	# Punto real donde hay que sellar (NO _arena_left) — medido con logs reales:
	# la cámara sigue al jugador con offset.x=384 de "adelanto" (mira más
	# adelante que el PP), así que lo que se ve en pantalla ANTES de sellar es
	# player.x + offset.x, no player.x a secas. Si sellamos recién al cruzar
	# _arena_left (en x de mundo crudo), la pantalla todavía no está mostrando
	# el centro de la arena — y Godot, al fijar límites del ancho exacto del
	# viewport, fuerza la cámara a ese centro de golpe: salto de ~249px en un
	# frame (confirmado con print de cam.position/screen_center antes/después).
	# Sellando en este punto en cambio, lo que ya se ve YA es el centro de la
	# arena — sellar pasa a ser un no-op visual, cero salto.
	var arena_center := (_arena_left + _arena_right) * 0.5
	_arena_center    = arena_center
	var cam_offset_x := cam.offset.x if cam else 0.0
	_arena_seal_trigger_x = arena_center - cam_offset_x

	# El boss se mueve como un cop mientras se acerca (ver bloque en _process,
	# BOSS_PARALLAX=1.2). Acá se calcula su "base" sin parallax, compensada
	# para que en el instante en que la cámara se traba (cam_x == arena_center,
	# constante de ahí en más) el resultado caiga EXACTO en el punto donde
	# tiene que arrancar la caminata de entrada — NO en _pizzeria_x (eso sigue
	# siendo el ancla del edificio/pista, desacoplado del boss a propósito).
	# Así el boss ya está parado ahí durante todo el acercamiento, en vez de
	# aparecer en _pizzeria_x y recién saltar a este punto al congelarse el PP
	# (ver _start_boss_intro, que ya no necesita reposicionarlo).
	#   render_x = base_x + arena_center*(1-parallax)  →  despejando:
	#   base_x   = boss_rest_x - arena_center*(1-parallax)
	var boss_rest_x := _pizzeria_x
	if _boss_node:
		var advance_px: float = _boss_node.call("get_walk_advance_per_cycle_px")
		boss_rest_x = arena_center + 2.0 * advance_px
	_boss_base_x = boss_rest_x - arena_center * (1.0 - BOSS_PARALLAX)

	# El edificio de la pizzeria queda centrado en la PANTALLA (arena_center,
	# 50%), no en el boss (que está al 80%) — quedan desacoplados a propósito.
	# Para que el fondo no se sienta cortado, los edificios comunes generan
	# SIN hueco hasta llegar a la pizzeria, y siguen 3 edificios más después de
	# ella (hacia donde está el boss) antes de cortar la generación del todo.
	var piz_left    := _pizzeria_x
	var piz_right   := _pizzeria_x
	var after_first := _pizzeria_x   # borde derecho del primer edificio tras la pizzeria (ver más abajo)
	var after_right := _pizzeria_x   # borde derecho del último edificio tras la pizzeria (ver más abajo)
	const BUILDINGS_AFTER_PIZZERIA := 3
	var buildings := get_node_or_null("BuildingsLayer")
	if buildings:
		# La pizzeria queda dentro del sistema de parallax normal de la capa
		# (misma velocidad que cualquier edificio frontal, parallax=1.2) — no
		# es un caso especial. Se la compensa con la misma fórmula de siempre,
		# pero apuntando a arena_center (el centro de pantalla) en vez de a
		# _pizzeria_x: render_x = base_x + arena_center*(1-parallax), y
		# queremos render_x == arena_center → base_x = arena_center*parallax.
		var piz_parallax: float = buildings.get("parallax")
		var piz_spawn_x := arena_center * piz_parallax
		buildings.call("fill_to", piz_spawn_x)   # sin hueco antes de la pizzeria
		piz_right = buildings.call("spawn_pizzeria", piz_spawn_x)
		piz_left  = buildings.get("pizzeria_base_x")
		# Se spawnea el primer edificio después de la pizzeria por separado (en vez
		# de los 3 de una) para saber su borde derecho real (after_first) — hace
		# falta para ocultar ahí también los faroles automáticos de la grilla fija
		# de 500px, que caen en cualquier lado sin relación al ancho real de los
		# edificios (random e1..e8.png) y a veces quedan pegados a un borde/detalle
		# feo del primer edificio. Los edificios 2 y 3 no tienen este ajuste porque
		# no hubo caso reportado ahí.
		after_first = buildings.call("spawn_n_buildings", piz_right, 1)
		after_right = buildings.call("spawn_n_buildings", after_first, BUILDINGS_AFTER_PIZZERIA - 1)
		buildings.call("stop_at", after_right)

	# Obstáculos (autos/cops/aéreos): cortan YA, en escape_x — la pista final es
	# sin obstáculos, solo corrés. El tráfico de fondo (cosmético) sigue hasta
	# _pizzeria_x junto con los edificios, para que no se vea vacío atrás.
	var mid_layer := get_node_or_null("CarMidLayer")
	if mid_layer: mid_layer.call("stop_at", escape_x)
	var traffic_rear := get_node_or_null("TrafficRearLayer")
	if traffic_rear: traffic_rear.call("stop_at", _pizzeria_x)

	# Farol: oculta los que caen sobre la pizzeria (barrido único — ahí SÍ
	# tiene que sobrevivir un farol de la grilla cruda, además del que se
	# agrega a mano) y agrega uno sobre el borde derecho de la pizzeria.
	var sl := get_node_or_null("StreetlampLayer")
	if sl:
		sl.call("finalize_for_pizzeria", piz_left - 100.0, piz_right + 100.0, piz_right - 35.0)
		# El primer edificio post-pizzeria SÍ necesita exclusión PERMANENTE (no
		# barrido único) — ver comentario largo en exclude_zone(), el problema
		# real era de timing (PIZZERIA_RUNWAY=5000px vs lookahead de faroles de
		# solo 2000px). Arranca en piz_right+100 (donde termina la zona de la
		# pizzeria de arriba) para no pisarla ni dejar hueco entre las dos.
		sl.call("exclude_zone", piz_right + 100.0, after_first + 30.0)
		sl.call("stop_at", after_right)

	if _boss_node:
		_boss_node.position     = Vector2(boss_rest_x, BOSS_FLOOR_Y)
		_boss_node.visible      = true
		_boss_node.process_mode = Node.PROCESS_MODE_INHERIT
		if _boss_node is CollisionObject2D:
			(_boss_node as CollisionObject2D).collision_layer = 4
			(_boss_node as CollisionObject2D).collision_mask  = 1
		# El final boss tiene que verse como el PP en luz — mismo light_mask
		# por defecto (=1, sin tocar) para que reaccione a faroles y demás
		# luces dinámicas igual que el jugador. El tinte NO alcanza con ser
		# igual al del PP (NIGHT_PLAYER) nomás: el arte del boss es delantal
		# BLANCO con sangre — mucho blanco puro, que bajo el mismo multiplicador
		# queda mucho más luminoso que la capucha roja/oscura del PP. Hay que
		# exagerar el oscurecido específicamente para él para que el resultado
		# final se sienta parejo. BOSS_TINT_EXTRA es ese extra, multiplicado
		# encima de NIGHT_PLAYER.
		_boss_node.modulate = NIGHT_PLAYER * BOSS_TINT_EXTRA

# Se dispara cuando el jugador llega físicamente al borde de la pantalla final
# (no al escapar, eso fue PIZZERIA_RUNWAY px antes) — recién ahí se traba la
# cámara y el PP sigue corriendo control normal hasta su punto de frenada (ver
# _intro_pending en _process).
#
# La caja de límites NO es exacta al ancho del viewport a propósito — le
# dejamos un margen de CAMERA_MARGIN_FRAC (1/4 de pantalla, repartido mitad a
# cada lado) de más. Godot solo fuerza el centrado automático cuando la caja
# mide EXACTO el ancho del viewport (o menos) — con esta caja más ancha, la
# cámara vuelve a tener grados de libertad reales y sigue al PP normal dentro
# de ese rango (nada de suavizado todavía, eso queda pendiente). Las paredes
# físicas se corren para que el PP pueda realmente llegar hasta ahí — si no,
# el margen de cámara quedaría inútil, sin nadie que lo alcance caminando.
const CAMERA_MARGIN_FRAC := 0.25

func _seal_pizzeria_arena() -> void:
	var vp_w   := _arena_right - _arena_left
	var margin := vp_w * CAMERA_MARGIN_FRAC * 0.5   # mitad para cada lado

	if _left_wall:
		_left_wall.global_position.x = maxf(_left_wall.global_position.x, _arena_left - margin)
	var cam := get_viewport().get_camera_2d()
	if cam:
		# Mismo ajuste de offset que ya usa la pared izquierda de siempre más arriba.
		cam.limit_left  = int(_arena_left  - margin) - int(cam.offset.x)
		cam.limit_right = int(_arena_right + margin) - int(cam.offset.x)
	_create_right_wall(int(_arena_right + margin) + 20)

	_intro_target_x = _arena_left + (_arena_right - _arena_left) * PLAYER_INTRO_SCREEN_POS
	_intro_pending  = true

# Frena al PP en seco al llegar a _intro_target_x y lo deja en IDLE, congelado
# — y ahí arranca la entrada escrita del boss (camina hasta _arena_center, ver
# start_intro_walk en boss.gd). Todo lo demás (soltar al PP, empezar la
# primera pareja de mozos) espera a que esa caminata termine — ver el bloque
# de _intro_active en _process.
#
# OJO: no reposicionar al PP en _intro_target_x acá. Este chequeo corre en
# _process, después de que la física ya lo movió ese frame — para cuando
# llega, el PP ya está unos px pasado del punto exacto (más con nitro). Forzar
# la posición lo teletransportaba hacia atrás esos px en el mismo instante en
# que se congela, y se veía como un pequeño salto/rebote justo antes del
# freeze. La cámara ya quedó fijada por _seal_pizzeria_arena() con sus propios
# límites, así que unos px de diferencia acá no afectan el encuadre — lo
# dejamos frenar donde ya está.
func _start_boss_intro(player: Node2D) -> void:
	player.call("set_cutscene_lock", true)
	_intro_active    = true
	_intro_walk_done = false
	_play_boss_intro_sfx()

	if _boss_node:
		# El boss ya está parado exactamente 2 ciclos de walk atrás del centro
		# desde que se activó (ver boss_rest_x en _trigger_pizzeria_ending) — acá
		# no hace falta reposicionarlo, solo arrancarlo a caminar desde donde ya
		# está.
		_boss_node.call("start_intro_walk", _arena_center)

# TODO: no hay assets de audio todavía (assets/audio/ está vacío) — acá va el
# "talk" del boss / grito del PP cuando los tengamos. Placeholder a propósito.
func _play_boss_intro_sfx() -> void:
	pass

# Arranca el duelo alternado de mozos (ver comentario junto a _duel_active
# más arriba) — se llama una sola vez, cuando termina toda la intro. Entra
# SOLO el de la derecha primero; el resto lo maneja _tick_first_duel.
func _start_first_duel() -> void:
	_duel_active        = true
	_duel_next_is_right = true
	_duel_current        = _spawn_side_waiter(true)

# Apenas muere el mozo actual, arranca una pausa (WAITER_RESPAWN_DELAY, "para
# respirar") y recién al vencer entra el siguiente por el lado contrario — y
# así indefinidamente. Se corta solo (sin más spawns) cuando el boss muere.
func _tick_first_duel(delta: float) -> void:
	if _boss_node and _boss_node.get("state") == _BOSS_STATE_DEAD:
		_duel_active = false
		return
	if _duel_current and (not is_instance_valid(_duel_current) or _duel_current.get("state") == _WAITER_DEAD):
		_duel_current        = null
		_duel_next_is_right  = not _duel_next_is_right
		_duel_respawn_timer  = WAITER_RESPAWN_DELAY
	if _duel_current == null and _duel_respawn_timer > 0.0:
		_duel_respawn_timer -= delta
		if _duel_respawn_timer <= 0.0:
			_duel_current = _spawn_side_waiter(_duel_next_is_right)

# Un tick de los dos casilleros — ver comentario junto a las variables
# _waiter_*. Sin abstraer en un loop a propósito: son solo dos, y así queda
# clarísimo qué hace cada lado con solo mirarlo.
func _tick_waiter_slots(delta: float) -> void:
	if _waiter_right and (not is_instance_valid(_waiter_right) or _waiter_right.get("state") == _WAITER_DEAD):
		_waiter_right       = null
		_waiter_right_timer = WAITER_RESPAWN_DELAY
	if _waiter_right == null and _waiters_spawned_total < WAITER_TOTAL_CAP:
		_waiter_right_timer -= delta
		if _waiter_right_timer <= 0.0:
			_waiter_right = _spawn_side_waiter(true)
			_waiters_spawned_total += 1

	if _waiter_left and (not is_instance_valid(_waiter_left) or _waiter_left.get("state") == _WAITER_DEAD):
		_waiter_left       = null
		_waiter_left_timer = WAITER_RESPAWN_DELAY
	if _waiter_left == null and _waiters_spawned_total < WAITER_TOTAL_CAP:
		_waiter_left_timer -= delta
		if _waiter_left_timer <= 0.0:
			_waiter_left = _spawn_side_waiter(false)
			_waiters_spawned_total += 1

# is_right=true entra desde afuera del borde derecho (atrás del boss);
# Instancia y libera una copia de cada variante de mozo apenas arranca el
# nivel, lejos de todo (x=-5000, fuera de la pantalla inicial). El único
# propósito es forzar la carga de sus ~210 texturas cada una (waiter.gd
# _load_sprites, vía load() en _ready) ahora, en un momento sin nada crítico
# pasando, en vez de que la primera vez sea recién al llegar a la arena del
# boss — ahí coincidía con el freeze de la intro (_start_boss_intro arranca el
# casillero de mozos con timer=0.0, "entra casi al toque") y se sentía como un
# microcorte pegado al freeze.
func _prewarm_waiter_sprites() -> void:
	for scene in [WAITER_SCENE, WAITER_DARK_SCENE, WAITER_LIGHT_SCENE]:
		var w: Node = scene.instantiate()
		(w as Node2D).position = Vector2(-5000.0, WAITER_FLOOR_Y)
		add_child(w)
		w.queue_free()

# is_right=false desde afuera del borde izquierdo.
func _spawn_side_waiter(is_right: bool) -> Node:
	var arena_w := _arena_right - _arena_left
	# La cámara puede panear hasta CAMERA_MARGIN_FRAC más allá del borde de la
	# arena (ver _seal_pizzeria_arena) — si el jugador corre hasta ese límite,
	# el punto de entrada tiene que quedar más lejos todavía que eso, sumando
	# margen extra para el ANCHO VISUAL del sprite (su hitbox es angosta,
	# _WAITER_RADIUS=15.6, pero el dibujo del mozo es bastante más ancho). Antes
	# esto era un fijo de 220px, que quedaba corto contra el margen de cámara
	# (160px) + sprite: se lo veía aparecer si te anticipabas corriendo al borde.
	var cam_margin   := arena_w * CAMERA_MARGIN_FRAC * 0.5
	var entry_offset := cam_margin + 150.0
	var enter_x  := _arena_right + entry_offset if is_right else _arena_left - entry_offset
	var target_x := _arena_left + arena_w * (0.90 if is_right else 0.30)
	var scenes := [WAITER_SCENE, WAITER_DARK_SCENE, WAITER_LIGHT_SCENE]
	var waiter: Node = scenes[randi() % scenes.size()].instantiate()
	(waiter as Node2D).position = Vector2(enter_x, WAITER_FLOOR_Y)
	(waiter as Node2D).modulate = NIGHT_ENEMY
	add_child(waiter)
	waiter.call("start_entrance", target_x, is_right)
	# El de la derecha se mueve entre el boss y el borde derecho; el de la
	# izquierda entre el borde izquierdo y el boss — ninguno cruza al otro
	# lado del boss ni sale de la pantalla de la arena. El límite se calcula
	# borde-a-borde (no centro-a-centro) para que se frene tocando al boss,
	# no superpuesto adentro suyo.
	var boss_x := _boss_node.global_position.x if _boss_node else (_arena_left + arena_w * 0.5)
	if is_right:
		waiter.call("set_movement_bounds", boss_x + _BOSS_RIGHT_EDGE_OFFSET + _WAITER_RADIUS, _arena_right)
	else:
		waiter.call("set_movement_bounds", _arena_left, boss_x + _BOSS_LEFT_EDGE_OFFSET - _WAITER_RADIUS)
	return waiter

func _spawn_waiter(x: float) -> void:
	var waiter: Node = WAITER_SCENE.instantiate()
	(waiter as Node2D).position = Vector2(x, WAITER_FLOOR_Y)
	add_child(waiter)

func _spawn_waiter_dark(x: float) -> void:
	var waiter: Node = WAITER_DARK_SCENE.instantiate()
	(waiter as Node2D).position = Vector2(x, WAITER_FLOOR_Y)
	add_child(waiter)

func _spawn_waiter_light(x: float) -> void:
	var waiter: Node = WAITER_LIGHT_SCENE.instantiate()
	(waiter as Node2D).position = Vector2(x, WAITER_FLOOR_Y)
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
	# Capa exclusiva (ver WALL_LAYER) — para que solo el PP choque contra esto.
	# Mozos/boss/cops nunca la incluyen en su collision_mask, así que la
	# atraviesan libremente.
	wall.collision_layer = WALL_LAYER
	wall.collision_mask  = 0
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
	wall.collision_layer = WALL_LAYER
	wall.collision_mask  = 0
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
