extends CharacterBody2D

const GRAVITY       := 850.0
const MAX_HP        := 7
const MOVE_SPEED    := 95.0
const EDGE_CHASE_SPEED := 260.0  # más rápido que MOVE_SPEED: perseguir el borde de cámara en _do_alert
const DETECT_RANGE  := 99999.0
const THROW_RANGE   := 99999.0
const THROW_CDN     := 0.9
# Antes tiraba en ráfagas de 3-4 platos casi seguidos (0.40-0.65s entre uno y
# otro) con una pausa larga recién después de la ráfaga completa — un ritmo
# muy marcado y predecible (tenso-tenso-tenso-respiro, repetir). Ahora cada
# plato se decide solo, con un intervalo random amplio, así no se siente
# cíclico y hay más aire real entre plato y plato.
const THROW_MIN_INTERVAL := 2.5   # antes 1.6 — más espaciado entre platos
const THROW_MAX_INTERVAL := 4.0   # antes 2.6
const HURT_DUR      := 0.5
const KNOCKBACK_DEC := 480.0
# Cuánto se queda adentro del borde de la pantalla actual al retroceder — así
# no queda ni una franja del sprite cortada contra el borde (ver _screen_x_range).
const SCREEN_EDGE_INSET := 70.0
const PUDDLE_PARALLAX   := 1.2  # mismo valor que un charco/cop (ver level1.gd BOSS_PARALLAX) — usado en DEAD y THROW
# Offset del sprite respecto a la cápsula (ver _load_sprites) — el cálculo
# real da -58 (pies dibujados exactos sobre el piso de la cápsula), pero se
# pidió hundirlo 20px a propósito: la cápsula/hitbox no se mueve, solo el
# dibujo. SPRITE_SINK_SHIFT es ese mismo ajuste reutilizado en todo lo que
# sigue al sprite visualmente (plato, barra de vida) para que no se
# desincronicen — sin esto quedaría un hueco flotando entre la cabeza (que
# bajó) y la barra (que se quedó donde estaba).
const SPRITE_SINK_SHIFT := 15.0
const SPRITE_Y_OFFSET   := -58.0 + SPRITE_SINK_SHIFT  # -58 real + hundido pedido
const IDLE_FPS        := 24.0  # sin efecto real: "idle" hoy es 1 solo frame (ver _load_sprites)
const WALK_FPS            := 30.0
const WALK_FRAMES         := 40
const IDLE_TO_WALK_FPS    := 30.0
const IDLE_TO_WALK_FRAMES := 22
const WALK_TO_IDLE_FPS    := 30.0
const WALK_TO_IDLE_FRAMES := 11
const THROW_FPS    := 30.0
const THROW_FRAMES := 34  # incluye el frame 1 (congelado = idle), ver _load_sprites
const HURT_FPS     := 88.0
const HURT_FRAMES  := 44
const DEATH_FPS    := 30.0
const DEATH_FRAMES := 14

const PLATE_SCENE := preload("res://scenes/enemies/Plate.tscn")

enum State { ENTRANCE, PATROL, ALERT, THROW, HURT, DEAD }

var state         := State.PATROL
var facing_right  := false
var hp            := MAX_HP
var entrance_target_x := 0.0

var throw_timer        := 0.0
var hurt_timer    := 0.0
var _death_base_x := 0.0   # ancla de parallax una vez muerto (ver _die)
var _throw_base_x := 0.0   # ancla de parallax mientras tira el plato (ver _do_alert/_do_throw)
var knockback     := Vector2.ZERO
var patrol_origin  := Vector2.ZERO
var walk_frame     := 0.0

# Límites opcionales de movimiento en X (sin usar = -INF/INF, no restringe
# nada — comportamiento de siempre para el mundo abierto). level1.gd los usa
# en la arena del boss para que el mozo de la derecha no cruce al boss ni
# salga de pantalla por la derecha, y el de la izquierda lo mismo del otro
# lado (ver set_movement_bounds).
var _bound_min := -INF
var _bound_max := INF
var _guide_edge_right := true  # ver start_entrance

# Hitbox espejado según hacia dónde mira — ver _update_collision_facing. El
# valor base (.tscn) es el punto neutro; a cada lado se le aplica el mismo
# corrimiento en X (con signo invertido) y el mismo crecimiento hacia arriba.
const HITBOX_FACING_X_SHIFT := 30.0   # corre el hitbox 30px hacia el lado que mira
const HITBOX_FACING_GROW_UP := 30.0   # crece 30px hacia arriba (el borde de abajo no se mueve), igual en ambos lados
# Pedido: mirando a la izquierda, el hitbox queda corrido 10px más hacia la
# derecha que su posición espejada normal. Solo afecta ese lado.
const HITBOX_LEFT_EXTRA_SHIFT := 10.0
# Pedido: mirando a la derecha, el hitbox queda corrido 10px más hacia la
# izquierda que su posición espejada normal. Solo afecta ese lado.
const HITBOX_RIGHT_EXTRA_SHIFT := -10.0
var _base_collision_pos:    Vector2 = Vector2.ZERO
var _base_collision_height: float   = 0.0

func set_movement_bounds(min_x: float, max_x: float) -> void:
	_bound_min = min_x
	_bound_max = max_x
var player: CharacterBody2D = null

var hp_bar_node:   Node2D = null
var hp_bar_blocks: Array  = []
var _shadow: Sprite2D = null

@export var skin_variant: String = ""  # "" = original, "dark", "light"

@onready var sprite:    AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 4
	# Incluye la capa 2 (jugador, ver Player.tscn) además de 1 (piso): sin esto
	# el mozo nunca se frena contra el PP (solo el PP lo tiene a él en su propia
	# máscara) y sigue caminando adentro suyo — eso es lo que se sentía como que
	# el mozo "empujaba" al PP (en realidad era el PP separándose solo, cada
	# frame, de la superposición que el mozo seguía generando). Con esto el
	# mozo mismo queda bloqueado al tocarlo, como una pared: choca y se pega,
	# sin empuje de ningún lado.
	collision_mask  = 1 | 2
	# Por debajo del boss (z_index 2 en boss.gd) — el mozo (y sus platos, ver
	# plate.gd) se tienen que ver detrás de él, no adelante.
	z_index = 1
	add_to_group("enemy")
	patrol_origin = global_position
	# El CapsuleShape2D del .tscn es un sub-resource compartido entre TODAS las
	# instancias hasta que se duplica — sin esto, mover el hitbox de un mozo
	# (ver _update_collision_facing) movería el de todos los demás a la vez.
	collision.shape = collision.shape.duplicate()
	_base_collision_pos    = collision.position
	_base_collision_height = (collision.shape as CapsuleShape2D).height
	_load_sprites()
	_build_hp_bar()
	_create_shadow()
	call_deferred("_find_player")
	sprite.animation_finished.connect(_on_animation_finished)

# Misma mancha plana que usa el PP (ver player.gd _create_shadow): recorta
# con AtlasTexture la franja real de sombra dentro de la imagen (el resto del
# archivo es el auto entero, transparente/inútil acá) en vez de escalar la
# imagen completa como hacen cop/boss — copiar sus píxeles tal cual no sirve,
# están calibrados para SU propio sprite (canvas/escala distintos al mozo) y
# terminaban poniendo la franja visible bien lejos de los pies (confirmado
# con una captura real: no se veía nada). El mozo no cambia de altura (no
# salta), así que alcanza con anclarla una vez, sin el fade dinámico del PP.
const SHADOW_TEX_PATH := "res://assets/sprites/cars/side_test/car_side_06 - copia.png"
const SHADOW_CONTENT  := Rect2(196, 588, 1071, 38)  # misma franja que recorta player.gd
const SHADOW_WIDTH    := 85.0   # ancho final en px, parado (75 + 10 pedido)
const SHADOW_HEIGHT   := 16.0   # alto final en px (14 + 6 - 4: 2 arriba y 2 abajo, el centro no se mueve)
const SHADOW_X_OFFSET := 0.0
# Crece hacia la izquierda desde SHADOW_WIDTH — el borde derecho no se mueve,
# solo se agranda el ancho real hacia ese lado (ver _create_shadow/_update_shadow_facing).
const SHADOW_GROW_LEFT := 10.0
# Pies reales de la cápsula (borde de abajo, y local +34) + SPRITE_SINK_SHIFT
# (el sprite ya se dibuja 20px más abajo — la sombra tiene que acompañarlo).
const SHADOW_FOOT_Y   := 34.0 + SPRITE_SINK_SHIFT
const SHADOW_Y_OFFSET := -5.0  # sube la sombra 10px, después bajada 5px (pedido)
const SHADOW_ALPHA    := 0.68

func _create_shadow() -> void:
	_shadow = Sprite2D.new()
	_shadow.z_index  = -1
	_shadow.centered = false
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(SHADOW_TEX_PATH)
	atlas.region = SHADOW_CONTENT
	_shadow.texture = atlas
	_shadow.scale      = Vector2((SHADOW_WIDTH + SHADOW_GROW_LEFT) / SHADOW_CONTENT.size.x, SHADOW_HEIGHT / SHADOW_CONTENT.size.y)
	_shadow.position   = Vector2(-SHADOW_WIDTH * 0.5 + SHADOW_X_OFFSET - SHADOW_GROW_LEFT, SHADOW_FOOT_Y - SHADOW_HEIGHT * 0.5 + SHADOW_Y_OFFSET)
	_shadow.modulate.a = SHADOW_ALPHA
	add_child(_shadow)
	move_child(_shadow, 0)

# SHADOW_X_OFFSET es un corrimiento asimétrico (calibrado mirando para la
# derecha) — al dar vuelta hay que invertirlo, si no la sombra se queda
# corrida siempre para el mismo lado sin importar hacia dónde mira ahora.
# Hoy el offset es 0 (sin efecto visible), pero queda preparado por si se
# ajusta más adelante. SHADOW_GROW_LEFT no se invierte con el lado: crece
# siempre hacia la izquierda del mundo, sin importar hacia dónde mira.
func _update_shadow_facing() -> void:
	if not _shadow: return
	var x_off := SHADOW_X_OFFSET if facing_right else -SHADOW_X_OFFSET
	_shadow.position.x = -SHADOW_WIDTH * 0.5 + x_off - SHADOW_GROW_LEFT

# Espejado real: el offset base del .tscn (calibrado con el sprite sin
# flipear, facing_right = false) se invierte de signo al mirar para la
# derecha — no solo el shift de alcance — y encima el mismo desplazamiento en
# X (invertido según el lado) y el mismo crecimiento hacia arriba de los dos
# lados, tomando el valor base como punto neutro (el borde de abajo del
# hitbox nunca se mueve).
func _update_collision_facing() -> void:
	var cap := collision.shape as CapsuleShape2D
	var base_x  := _base_collision_pos.x if not facing_right else -_base_collision_pos.x
	var x_shift := HITBOX_FACING_X_SHIFT if facing_right else -HITBOX_FACING_X_SHIFT
	collision.position.x = base_x + x_shift
	collision.position.x += HITBOX_LEFT_EXTRA_SHIFT if not facing_right else HITBOX_RIGHT_EXTRA_SHIFT
	cap.height            = _base_collision_height + HITBOX_FACING_GROW_UP
	collision.position.y  = _base_collision_pos.y - HITBOX_FACING_GROW_UP * 0.5

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

# Entra caminando desde fuera de pantalla hacia target_x — usado en la arena
# de la pizzeria, para que no aparezcan de golpe sino que se los vea llegar.
# guide_right: a qué borde de cámara se pega una vez en ALERT (ver _do_alert) —
# true = borde derecho (mozo que entró por la derecha), false = izquierdo.
func start_entrance(target_x: float, guide_right: bool = true) -> void:
	entrance_target_x = target_x
	facing_right      = target_x > global_position.x
	_guide_edge_right = guide_right
	state             = State.ENTRANCE

func _do_entrance(_delta: float) -> void:
	var dir := signf(entrance_target_x - global_position.x)
	facing_right = dir > 0.0
	velocity.x   = dir * MOVE_SPEED * 1.3
	if absf(entrance_target_x - global_position.x) < 10.0:
		velocity.x     = 0.0
		patrol_origin  = global_position
		state          = State.PATROL

func _skin_path() -> String:
	return "res://assets/sprites/enemies/waiter" + ("_" + skin_variant if skin_variant != "" else "")

# Cache compartido entre TODAS las instancias, por variante de skin. SpriteFrames
# es solo metadata + referencias a texturas (nada de estado de reproducción, eso
# vive en el AnimatedSprite2D), así que es seguro compartir el mismo resource.
# Sin esto, cada mozo nuevo reconstruía el SpriteFrames entero desde cero en su
# _ready() — ~210 frames repartidos en 8 animaciones, con add_frame() uno por
# uno — aunque las texturas ya estuvieran en cache de load(). Eso era el costo
# real (~145ms medidos) detrás del microcorte justo al entrar el primer mozo de
# la arena del boss, pegado al freeze de la intro.
static var _frames_cache: Dictionary = {}  # skin_variant (String) -> SpriteFrames

func _load_sprites() -> void:
	var base := _skin_path()
	if _frames_cache.has(skin_variant):
		sprite.sprite_frames = _frames_cache[skin_variant]
		sprite.position = Vector2(0, SPRITE_Y_OFFSET)
		sprite.play("idle")
		return

	var frames := SpriteFrames.new()

	# Ya no se usa la carpeta idle/ (ni idle2/) — el idle ahora es el frame 1
	# de throw/ (la pose de tirar el plato, congelada, ver _load_sprites más
	# abajo), en vez de una animación propia con sus 44 frames.
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", IDLE_FPS)
	var idle_tex := load("%s/throw/throw____001.png" % base) as Texture2D
	if idle_tex: frames.add_frame("idle", idle_tex)

	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", WALK_FPS)
	for i in range(1, WALK_FRAMES + 1):
		var tex := load("%s/walk/walk___%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("walk", tex)

	frames.add_animation("idle_to_walk")
	frames.set_animation_loop("idle_to_walk", false)
	frames.set_animation_speed("idle_to_walk", IDLE_TO_WALK_FPS)
	for i in range(1, IDLE_TO_WALK_FRAMES + 1):
		var tex := load("%s/idle_to_walk/idle_to_walk___%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("idle_to_walk", tex)

	frames.add_animation("walk_to_idle")
	frames.set_animation_loop("walk_to_idle", false)
	frames.set_animation_speed("walk_to_idle", WALK_TO_IDLE_FPS)
	for i in range(1, WALK_TO_IDLE_FRAMES + 1):
		var tex := load("%s/walk_to_idle/walk_to_idle___%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("walk_to_idle", tex)

	frames.add_animation("throw")
	frames.set_animation_loop("throw", false)
	frames.set_animation_speed("throw", THROW_FPS)
	# Arranca en el frame 2: el 1 es el mismo que "idle" (congelado), así que
	# el movimiento de tiro en sí empieza recién ahí.
	for i in range(2, THROW_FRAMES + 1):
		var tex := load("%s/throw/throw____%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("throw", tex)

	frames.add_animation("hurt")
	frames.set_animation_loop("hurt", false)
	frames.set_animation_speed("hurt", HURT_FPS)
	for i in range(1, HURT_FRAMES + 1):
		var tex := load("%s/hurt/hurt____%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("hurt", tex)

	frames.add_animation("death")
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", DEATH_FPS)
	for i in range(1, DEATH_FRAMES + 1):
		var tex := load("%s/death/death____%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("death", tex)

	_frames_cache[skin_variant] = frames
	sprite.sprite_frames = frames
	# Mismo problema que el boss (ver boss.gd _load_sprites): el pie dibujado no
	# coincide con el borde de abajo de la propia cápsula. Medido sobre los PNG
	# reales (idle/walk, las 3 skins Waiter/Dark/Light comparten arte):
	# canvas 200x200 (sprite centrado → -100 a +100 en y local), pie real
	# (fila opaca más baja) ≈ fila 191 → y local +92.
	# Cápsula (CapsuleShape2D.height=68) → borde de abajo en y local +34.
	#   offset = borde_abajo_capsula - pie_real = 34 - 92 = -58
	# (ver SPRITE_Y_OFFSET: ese -58 real + 20 de hundido pedido a mano)
	sprite.position = Vector2(0, SPRITE_Y_OFFSET)
	sprite.play("idle")

func _build_hp_bar() -> void:
	var bar := Node2D.new()
	# -56 estaba calibrado para el offset de sprite viejo (-4); al subir el
	# sprite a -58 (ver _load_sprites) la cabeza subió con él, así que la barra
	# sube lo mismo para mantener la misma distancia: -56 + (-58 - (-4)) = -110.
	# Ahora que el sprite se hundió SPRITE_SINK_SHIFT px de nuevo, la barra baja
	# lo mismo para no dejarle un hueco flotando arriba de la cabeza.
	bar.position = Vector2(0, -110 + SPRITE_SINK_SHIFT)
	bar.visible  = false
	var bw   := 6.0
	var gap  := 2.0
	var total := MAX_HP * bw + (MAX_HP - 1) * gap
	for i in MAX_HP:
		var b := ColorRect.new()
		b.size     = Vector2(bw, 3.0)
		b.position = Vector2(-total / 2.0 + i * (bw + gap), 0.0)
		b.color    = Color(0.0, 1.0, 0.85)
		bar.add_child(b)
		hp_bar_blocks.append(b)
	hp_bar_node = bar
	add_child(bar)

func _refresh_hp_bar() -> void:
	if not hp_bar_node: return
	hp_bar_node.visible = true
	for i in hp_bar_blocks.size():
		(hp_bar_blocks[i] as ColorRect).color = \
			Color(0.0, 1.0, 0.85) if i < hp else Color(0.06, 0.06, 0.14)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		# Sigue el mismo parallax que un charco (ver _die) en vez de quedar
		# clavado en coordenadas de mundo crudo — la cámara puede seguir
		# moviéndose un poco dentro de su margen real aunque el boss ya haya
		# muerto y el jugador siga caminando por la arena sellada.
		var cam := get_viewport().get_camera_2d()
		if cam:
			global_position.x = _death_base_x + cam.get_screen_center_position().x * (1.0 - PUDDLE_PARALLAX)
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if throw_timer > 0.0: throw_timer -= delta
	if hurt_timer  > 0.0: hurt_timer  -= delta

	match state:
		State.ENTRANCE: _do_entrance(delta)
		State.PATROL:   _do_patrol(delta)
		State.ALERT:    _do_alert(delta)
		State.THROW:    _do_throw(delta)
		State.HURT:     _do_hurt(delta)
		State.DEAD:     velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

	sprite.flip_h = facing_right
	_update_anim(delta)
	_update_shadow_facing()
	_update_collision_facing()
	move_and_slide()

	# Límite de la arena (lado del boss) — pared física real, no ligada a la
	# cámara. Mantenerse dentro de lo que se ve en pantalla ahora es trabajo
	# de _do_alert (camina de vuelta solo, ver _screen_x_range ahí), no de un
	# clamp acá — un clamp de posición se sentía como que la pantalla lo
	# arrastraba pegado al borde en vez de que caminara de vuelta.
	global_position.x = clampf(global_position.x, _bound_min, _bound_max)

func _update_anim(delta: float) -> void:
	if state == State.THROW or state == State.HURT or state == State.DEAD: return

	var moving: bool = abs(velocity.x) > 1.0 and (state == State.PATROL or state == State.ALERT or state == State.ENTRANCE)

	# Transiciones idle_to_walk y walk_to_idle disponibles pero desactivadas
	if moving:
		if sprite.animation != "walk":
			sprite.animation = "walk"
			sprite.speed_scale = 0.0
		var moving_forward: bool = (velocity.x < 0.0 and not facing_right) or (velocity.x > 0.0 and facing_right)
		walk_frame = fposmod(walk_frame + WALK_FPS * delta * (1.0 if moving_forward else -1.0), float(WALK_FRAMES))
		sprite.set_frame_and_progress(floori(walk_frame), 0.0)
	else:
		# Antes se congelaba en el último frame de "walk" (quedaba parado en
		# pose de caminar) — ahora pasa a la animación real de idle.
		walk_frame = 0.0
		if sprite.animation != "idle":
			sprite.speed_scale = 1.0
			sprite.play("idle")

func _player_dist() -> float:
	if not player: return INF
	return abs(player.global_position.x - global_position.x)

func _do_patrol(delta: float) -> void:
	if player and _player_dist() <= DETECT_RANGE:
		state = State.ALERT
		return
	var target_x := patrol_origin.x + (280.0 if facing_right else -280.0)
	var dir := signf(target_x - global_position.x)
	velocity.x = move_toward(velocity.x, dir * MOVE_SPEED * 0.8, 200.0 * delta)
	if global_position.x >= patrol_origin.x + 280.0:   facing_right = false
	elif global_position.x <= patrol_origin.x - 280.0: facing_right = true

func _do_alert(delta: float) -> void:
	if not player:
		state = State.PATROL
		return
	var dist := _player_dist()
	if dist > DETECT_RANGE * 1.5:
		state = State.PATROL
		return

	facing_right = player.global_position.x > global_position.x

	# El borde de la pantalla es su guía: camina para quedar siempre pegado al
	# borde de cámara de su lado (_guide_edge_right, ver start_entrance), no en
	# base a la distancia al jugador. Si la cámara se mueve, lo sigue; si se
	# frena, él también. _bound_min/_bound_max (set_movement_bounds, ver
	# level1.gd) siguen limitando para que no cruce al lado del boss.
	var screen := _screen_x_range()
	var edge_x := (screen.y - SCREEN_EDGE_INSET) if _guide_edge_right else (screen.x + SCREEN_EDGE_INSET)
	edge_x = clampf(edge_x, _bound_min, _bound_max)

	var gap := edge_x - global_position.x
	var dir := signf(gap)
	# Ya está pegado al borde (a menos de 2px) → se frena, no sigue "queriendo"
	# caminar sin moverse (evita jitter/pose de caminata parado en el lugar).
	var target_speed := 0.0 if absf(gap) < 2.0 else EDGE_CHASE_SPEED
	velocity.x = move_toward(velocity.x, dir * target_speed, 400.0 * delta)

	if dist <= THROW_RANGE and throw_timer <= 0.0 and _is_on_screen():
		throw_timer         = randf_range(THROW_MIN_INTERVAL, THROW_MAX_INTERVAL)
		sprite.speed_scale  = 1.0
		velocity.x          = 0.0   # corta en seco: no puede quedar deslizando durante la animación de tiro
		# Ancla el parallax de charco (ver _do_throw) en la posición real de
		# este instante, para que no salte al entrar al estado.
		var cam := get_viewport().get_camera_2d()
		if cam:
			_throw_base_x = global_position.x - cam.get_screen_center_position().x * (1.0 - PUDDLE_PARALLAX)
		else:
			_throw_base_x = global_position.x
		state = State.THROW
		sprite.play("throw")

func _is_on_screen() -> bool:
	var screen_pos := get_viewport().get_canvas_transform() * global_position
	return get_viewport_rect().has_point(screen_pos)

# Rango en X (mundo) que la cámara está mostrando en este momento — no el
# rectángulo fijo de la arena, que puede quedar corrido si la cámara usa su
# margen real (CAMERA_MARGIN_FRAC en level1.gd) para seguir un poco al PP.
func _screen_x_range() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if not cam: return Vector2(-INF, INF)
	var center_x := cam.get_screen_center_position().x
	var half_vp  := get_viewport().get_visible_rect().size.x * 0.5 / cam.zoom.x
	return Vector2(center_x - half_vp, center_x + half_vp)

func _do_throw(_delta: float) -> void:
	velocity.x = 0.0   # quieto en el lugar durante toda la animación de tiro
	# Mismo parallax que un charco (ver PUDDLE_PARALLAX/_die) mientras está
	# parado tirando — sin esto quedaba clavado en coordenadas de mundo crudo,
	# desincronizado del resto del fondo si la cámara se mueve dentro de su
	# margen real (CAMERA_MARGIN_FRAC en level1.gd).
	var cam := get_viewport().get_camera_2d()
	if cam:
		global_position.x = _throw_base_x + cam.get_screen_center_position().x * (1.0 - PUDDLE_PARALLAX)

func _spawn_plate() -> void:
	var plate := PLATE_SCENE.instantiate() as Node2D
	get_parent().add_child(plate)
	var dir := 1.0 if facing_right else -1.0
	plate.global_position = global_position + Vector2(dir * 85.0, -85.0 + SPRITE_SINK_SHIFT)  # -45 antes, + hundido pedido, +20px más arriba
	if plate.has_method("init"):
		plate.call("init", dir)

func _on_animation_finished() -> void:
	if state == State.THROW:
		_spawn_plate()
		state = State.ALERT if (player and _player_dist() <= DETECT_RANGE * 1.5) else State.PATROL
	elif state == State.HURT:
		state = State.ALERT if (player and _player_dist() <= DETECT_RANGE * 1.5) else State.PATROL

func take_damage(amount: int, from_right: bool, kb: float = 0.0) -> void:
	if state == State.DEAD: return
	hp -= amount
	knockback.x = kb * (-1.0 if from_right else 1.0)   # empuja lejos del jugador
	_refresh_hp_bar()
	if hp <= 0:
		_die()
	else:
		state      = State.HURT
		hurt_timer = HURT_DUR
		sprite.speed_scale = 1.0
		sprite.play("hurt")

func _do_hurt(delta: float) -> void:
	velocity.x  = knockback.x
	knockback.x = move_toward(knockback.x, 0.0, KNOCKBACK_DEC * delta)
	if hurt_timer <= 0.0:
		state = State.ALERT if (player and _player_dist() <= DETECT_RANGE * 1.5) else State.PATROL

func _die() -> void:
	state = State.DEAD
	collision.set_deferred("disabled", true)
	if _shadow: _shadow.visible = false
	sprite.speed_scale = 1.0
	sprite.play("death")
	# Mismo parallax que un charco (1.2, ver level1.gd BOSS_PARALLAX) una vez
	# muerto — antes el cadáver quedaba clavado en coordenadas de mundo crudo,
	# desincronizado del resto del fondo (charcos/tráfico) si la cámara se
	# corre dentro de su margen real (CAMERA_MARGIN_FRAC en level1.gd). Se
	# ancla en la posición real de este instante para que no salte al morir:
	# despejando de la fórmula de abajo, base = pos_actual - cam*(1-parallax).
	var cam := get_viewport().get_camera_2d()
	if cam:
		_death_base_x = global_position.x - cam.get_screen_center_position().x * (1.0 - PUDDLE_PARALLAX)
	else:
		_death_base_x = global_position.x
