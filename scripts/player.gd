extends CharacterBody2D

# ── Física ───────────────────────────────────────────────────────────────────
const MAX_SPEED    := 729.0
const ACCELERATION := 2400.0
const FRICTION     := 1200.0
const JUMP_FORCE          := -531.0
const RUN_JUMP_FORCE      := -531.0
const JUMP_SPRITE_Y_OFFSET := 55.0   # bajá el sprite en jump para alinear pies con la caja
const RUN_JUMP_SPEED      := 828.0   # velocidad horizontal del salto desde run (más envión que correr)
const IDLE_JUMP_AIR_SPEED := 228.0   # salto desde idle: 60% de MAX_SPEED, movimiento lateral leve
const AIR_BRAKE           := 1200.0  # en el aire, presionar la dirección inversa frena fuerte (en vez de darse vuelta)
const JUMP_SQUAT_DUR      := 0.133
const RUN_JUMP_SQUAT_DUR  := 2.0 / 24.0
const GRAVITY      := 850.0
const ROLL_SPEED   := 160.0
const ROLL_DIST    := 48.0
const ROLL_PAUSE   := 0.35

const NEAR_FLOOR_DIST  := 130.0  # px — caída tan corta que no vale mostrar animación de caída
const COYOTE_TIME      := 0.1    # margen para saltar aunque ya te caíste del borde

const NITRO_CHARGE_DUR := 7.0
const NITRO_ACTIVE_DUR := 2.0
const NITRO_SPEED_MULT := 1.9

# ── Combate ──────────────────────────────────────────────────────────────────
const COMBO_WINDOW    := 0.50
const COMBO_HIT_DUR   := 0.38
const COMBO_COOLDOWN  := 0.22

const JAB_FRAMES      := 17
const HOOK_FRAMES     := 12
const UPPERCUT_FRAMES := 47
const KICK_FRAMES     := 31
const JAB_FPS         := 44.74   # 17 frames / 0.38s
const HOOK_FPS        := 31.58   # 12 frames / 0.38s
const UPPERCUT_FPS    := 60.0    # velocidad natural, dura 47/60 ≈ 0.78s
const KICK_FPS        := 88.57   # 31 frames / 0.35s
const FLYING_KICK_FRAMES := 47
const FLYING_KICK_FPS    := 60.0   # 47 frames / ~0.78s (recortado, sin idle de relleno)
const FLYING_KICK_IMPACT := 20     # frame con la pierna extendida: ahi registra el golpe
const FLYING_KICK_KB     := 0.0    # 0 = enemigo plantado (no patina). Subir para empujarlo hacia atras
const FLYING_KICK_RANGE  := 150.0  # alcance del golpe (la pierna llega lejos)
const AIR_KICK_FRAMES     := 57
const AIR_KICK_FPS        := 60.0  # velocidad de la patada (0→freeze)
const AIR_KICK_RECOVER_FPS := 90.0 # tras el freeze (retracción/descenso/aterrizaje) más rápido
const AIR_KICK_IMPACT     := 16    # frame 17: pierna extendida (registra el golpe)
const AIR_KICK_HOLD       := 16    # frame 17: frena la patada en el aire hasta pegar o acercarse al piso
const AIR_KICK_NEAR_GROUND := 80.0 # distancia al piso para empezar a descender/aterrizar
const AIR_KICK_FORWARD    := 240.0 # px/s hacia adelante (dive): avanza en el aire hasta tocar piso
const AIR_KICK_KB         := 0.0   # 0 = enemigo plantado (consistente con el combo)
const HITSTOP_DUR        := 0.08   # freeze frame al conectar
const SHAKE_AMOUNT       := 9.0    # amplitud inicial del screen shake
const SHAKE_DECAY        := 45.0
const SLIDE_HITSTOP_DUR      := 0.05   # freeze más corto que un golpe: la barrida es rápida, no pesada
const SLIDE_SHAKE_AMOUNT     := 5.0
const SLIDE_AFTERIMAGE_INTERVAL := 0.045  # cada cuánto larga una copia fantasma mientras desliza
const SLIDE_AFTERIMAGE_DUR      := 0.16   # cuánto tarda cada copia en desvanecerse
const SLIDE_DUST_FEET_OFFSET    := 78.0   # altura del emisor de polvo respecto al origen del jugador
const MAX_HP        := 5
const IFRAME_DUR    := 1.0    # segundos de invulnerabilidad tras recibir golpe (antes 0.7)
const DEATH_FADE_DUR := 1.5
const HIT_RANGE_X   := 112.0  # alcance horizontal del golpe
const HIT_RANGE_Y   := 52.0   # tolerancia vertical
const ENEMY_TOUCH_DIST := 88.0  # distancia a la que se considera "chocando" a un enemigo

enum State      { IDLE, WALK, RUN, STOP, RUN_JUMP, JUMP_SQUAT, JUMP, FALL, LAND, JUMP_TO_CROUCH, CROUCH, CROUCH_WALK, STAND, ROLL, ATTACKING, AIR_ATTACKING, CROUCH_ATTACKING, AIR_KICKING, SLIDE, RUN_PUNCH, DEAD, DOUBLE_JUMP }
enum AttackType { JAB, HOOK, UPPERCUT, SWEEP, KICK, CROUCH_KICK, AIR_PUNCH, AIR_DOWN_KICK, THROW, FLYING_KICK }

var state          := State.IDLE
var facing_right   := true
var roll_remaining       := 0.0
var roll_dir             := 1.0
var crouch_roll_cooldown := 0.0

var current_attack := AttackType.JAB
var combo_step          := 0
var attack_timer        := 0.0
var combo_timer         := 0.0
var attack_queued       := false
var combo_cooldown_timer := 0.0

var hp             := MAX_HP
var iframe_timer   := 0.0
var death_timer    := 0.0
var knockback_vel  := 0.0     # velocidad horizontal de empuje al recibir daño
var hitstun_timer  := 0.0     # bloqueo de input mientras dura el empuje

# Lock externo para la pausa "llegada a la pizzeria" (ver level1.gd): el nivel
# frena al PP en seco y lo deja en IDLE hasta que termine la introducción del
# boss (talk/sonidos), sin tocar el resto de la máquina de estados.
var _cutscene_locked := false

var nitro_charge := 0.0
var nitro_active := false
var nitro_timer  := 0.0

var _under_car_t    := 0.0
var _last_on_aerial := false
var _aerial_drop              := false
var _aerial_z_hold            := 0
var _last_surface_ground_car  := false
var _fall_from_run            := false

@onready var sprite:    Sprite2D         = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var camera:    Camera2D         = $Camera2D

var shake_amount     := 0.0
var _cam_base_offset := Vector2.ZERO
var _hitstop_active  := false

var slide_hit_stopped      := false   # el hitstop/shake del slide dispara una sola vez por barrida
var slide_afterimage_timer := 0.0
var _slide_dust: GPUParticles2D = null

@export var has_bengala: bool = false
var _bengala: Node2D = null

var _shadow: Sprite2D = null
var _shadow_floor_y := 0.0
const SHADOW_FEET_OFFSET := 82.0
const SHADOW_MAX_HEIGHT  := 200.0

var tex_attack: Texture2D

var tex_jab_frames: Array[Texture2D] = []
var jab_frame_index := 0
var jab_frame_timer := 0.0

var tex_hook_frames: Array[Texture2D] = []
var hook_frame_index := 0
var hook_frame_timer := 0.0

var tex_uppercut_frames: Array[Texture2D] = []
var uppercut_frame_index := 0
var uppercut_frame_timer := 0.0

var tex_kick_frames: Array[Texture2D] = []
var kick_frame_index := 0
var kick_frame_timer := 0.0

var tex_flying_kick_frames: Array[Texture2D] = []
var flying_kick_frame_index := 0
var flying_kick_frame_timer := 0.0
var flying_kick_hit_done := false

var tex_air_kick_frames: Array[Texture2D] = []
var air_kick_frame_index := 0
var air_kick_frame_timer := 0.0
var air_kick_connected := false
var air_kick_speed := 0.0   # velocidad del dive: hereda el envión de entrada (mín. AIR_KICK_FORWARD)

const CAN_SCENE := preload("res://scenes/Can.tscn")
const THROW_FRAMES     := 50
const THROW_FPS        := 88.0
const THROW_SPAWN_FRAME := 19   # frame donde suelta la lata
var tex_throw_frames: Array[Texture2D] = []
var throw_frame_index := 0
var throw_frame_timer := 0.0
var throw_can_spawned := false

var tex_jump_to_crouch_frames: Array[Texture2D] = []
var jump_to_crouch_frame_index := 0
var jump_to_crouch_frame_timer := 0.0
const JUMP_TO_CROUCH_FPS := 30.0

var tex_crouch_frames: Array[Texture2D] = []
var crouch_frame_index := 0
var crouch_frame_timer := 0.0
var crouch_fast        := false
const CROUCH_FPS      := 30.0
const CROUCH_FAST_FPS := 90.0

var tex_stand_frames: Array[Texture2D] = []
var stand_frame_index := 0
var stand_frame_timer := 0.0
var stand_fast        := false
const STAND_FPS      := 30.0
const STAND_FAST_FPS := 60.0

var tex_crouch_walk_frames: Array[Texture2D] = []
var crouch_walk_frame_index := 0
var crouch_walk_frame_timer := 0.0
const CROUCH_WALK_FPS := 30.0

var tex_idle_frames: Array[Texture2D] = []
var idle_frame_index  := 0
var idle_frame_timer  := 0.0
const IDLE_FPS := 30.0

var tex_walk_frames: Array[Texture2D] = []
var walk_frame_index  := 0
var walk_frame_timer  := 0.0
const WALK_FPS := 50.0


var tex_run_frames: Array[Texture2D] = []
var run_frame_index  := 0
var run_frame_timer  := 0.0
const RUN_FPS := 60.0

var tex_stop_frames: Array[Texture2D] = []
var stop_frame_index := 0
var stop_frame_timer := 0.0
var stop_from_walk   := false
const STOP_FPS      := 30.0
const STOP_WALK_FPS := 17.0

var tex_run_jump_frames: Array[Texture2D] = []
var run_jump_frame_index := 0
var run_jump_frame_timer := 0.0
var run_jump_hold_timer  := 0.0
const RUN_JUMP_FPS        := 30.0
const RUN_JUMP_HOLD_DUR   := 0.20

var tex_jump_frames: Array[Texture2D] = []
var jump_frame_index  := 0
var jump_frame_timer  := 0.0
var jump_squat_timer := 0.0
var jump_from_run    := false
var jump_from_walk   := false
var jump_from_idle   := false
const JUMP_FPS := 24.0

var coyote_timer            := 0.0    # >0 mientras todavía se puede saltar tras dejar el piso
var _coyote_grounded_state: State = State.IDLE  # estado que tenía parado en el piso, para el salto de gracia

const DOUBLE_JUMP_FPS        := 48.0
const DOUBLE_JUMP_FRAMES     := 73
const DOUBLE_JUMP_LAST_FRAME := 45   # índice 45 = frame 46; último frame de la vuelta
const DOUBLE_JUMP_FORCE      := -531.0
var tex_double_jump_frames: Array[Texture2D] = []
var double_jump_frame_index  := 0
var double_jump_frame_timer  := 0.0
var _double_jump_used        := false
var _dj_buffered_kick        := false   # kick presionado durante la vuelta: se dispara al terminar
var _dj_buffered_down_kick   := false

# ── Slide (pop-up slide de béisbol) ──────────────────────────────────────────
# Se dispara desde RUN + agacharse + dirección. El pj se tira, se desliza con
# los pies adelante barriendo enemigos (los atraviesa, hitbox baja) y se levanta
# de nuevo a RUN. Índices 0-based sobre los 97 frames de slide/:
#   0-16 corre · 17-20 se tira · 21-49 barrida feet-first · 50-63 se levanta · 64+ corre
const SLIDE_FPS         := 72.0  # rápido para entrar al frame de congelado
const SLIDE_EXIT_FPS    := 120.0 # salida del congelado a la levantada/run (ahora el FPS sí manda)
const SLIDE_START_FRAME := 17    # arranca el clavado
const SLIDE_HOLD_FRAME  := 29    # slide_030: se congela acá deslizándose por el piso
const SLIDE_HOLD_DUR    := 0.65  # cuánto se queda agachado deslizándose (subir = más largo)
const SLIDE_HIT_END     := 49    # último frame que barre (fin del deslizamiento)
const SLIDE_END_FRAME   := 73    # slide_074: último frame que se reproduce (75+ deshabilitados) → empalma con RUN
const SLIDE_CROUCHWALK_FRAME := 60 # slide_061: si encadenás a caminar agachado, corta acá sin terminar de pararse
const SLIDE_HIT_KB      := 0.0   # 0 = enemigo plantado (consistente con el combo)
const SLIDE_RANGE       := 96.0  # alcance de la barrida — igual para todos, cops incluidos:
								  # tiene que verse tocar de verdad, no matar desde lejos
var tex_slide_frames: Array[Texture2D] = []
var slide_frame_index := 0
var slide_frame_timer := 0.0
var slide_hold_timer  := 0.0
var slide_dir         := 1.0
var slide_from_run       := false
var slide_no_retrigger   := false   # bloquea re-disparo de slide hasta soltar ↓
var slide_hit_ids: Dictionary = {}

# ── Puñetazo corriendo (run punch) ───────────────────────────────────────────
# Se dispara desde RUN + atacar (Z). Lunge hacia adelante con un recto; el video
# tiene un hold natural largo (~frames 35-61) que NO cargamos: dejamos uno y lo
# congelamos por código con RUN_PUNCH_HOLD_DUR. Índices 0-based sobre run_punch/ (97):
#   0-17 corre · 18-33 windup+lanza · 34-40 puño extendido (impacto) · 41-80 retrae · 81+ corre
const RUN_PUNCH_FPS         := 90.0   # entrada al golpe (windup + lanzar brazo)
const RUN_PUNCH_EXIT_FPS    := 120.0  # salida (retrae) → run
const RUN_PUNCH_START_FRAME := 18     # frame19: arranca el windup
const RUN_PUNCH_HOLD_FRAME  := 39     # frame40: puño extendido, se congela acá
const RUN_PUNCH_HOLD_DUR    := 0.10   # cuánto dura el golpe congelado (subir = más pesado)
const RUN_PUNCH_END_FRAME   := 80     # frame81: retraído → vuelve a run/idle
const RUN_PUNCH_IMPACT      := 33     # frame donde conecta el golpe (registra daño)
const RUN_PUNCH_DMG         := 2
const RUN_PUNCH_KB          := 0.0    # 0 = enemigo plantado (consistente con el combo)
const RUN_PUNCH_RANGE       := 140.0  # alcance del recto (el brazo llega lejos)
const RUN_PUNCH_FRICTION    := 500.0  # el lunge hacia adelante desacelera
var tex_run_punch_frames: Array[Texture2D] = []
var run_punch_frame_index := 0
var run_punch_frame_timer := 0.0
var run_punch_hold_timer  := 0.0
var run_punch_dir         := 1.0
var run_punch_hit_done    := false
var run_punch_used        := false

func _ready() -> void:
	add_to_group("player")
	z_index = 3
	floor_max_angle  = deg_to_rad(35.0)  # acepta pendientes del contorno de autos como piso
	floor_snap_length = 24.0             # suaviza vértices del contorno en ambas direcciones
	floor_stop_on_slope = false          # sin esto, aterrizar con velocidad.y (salto) sobre una
										  # pendiente (rampa del camión, contorno de autos) frena
										  # de golpe la velocidad horizontal — no debe cortar el ritmo
	_cam_base_offset = camera.offset
	tex_attack = load("res://assets/sprites/player/player_punch.png")
	for i in range(1, JAB_FRAMES + 1):
		tex_jab_frames.append(load("res://assets/sprites/player/jab/jab____%03d.png" % i))
	for i in range(1, HOOK_FRAMES + 1):
		tex_hook_frames.append(load("res://assets/sprites/player/hook/hook____%03d.png" % i))
	for i in range(1, UPPERCUT_FRAMES + 1):
		tex_uppercut_frames.append(load("res://assets/sprites/player/uppercut/uppercut____%03d.png" % i))
	for i in range(1, KICK_FRAMES + 1):
		tex_kick_frames.append(load("res://assets/sprites/player/kick/kick____%03d.png" % i))
	for i in range(1, FLYING_KICK_FRAMES + 1):
		tex_flying_kick_frames.append(load("res://assets/sprites/player/flying_kick/flying_kick_%03d.png" % i))
	for i in range(1, AIR_KICK_FRAMES + 1):
		tex_air_kick_frames.append(load("res://assets/sprites/player/air_kick/air_kick_%03d.png" % i))
	for i in range(1, THROW_FRAMES + 1):
		tex_throw_frames.append(load("res://assets/sprites/player/throw_cans/throw_cans_%03d.png" % i))
	for i in range(1, 40):
		tex_idle_frames.append(load("res://assets/sprites/player/idle/idle__%03d.png" % i))
	for i in range(1, 51):
		tex_walk_frames.append(load("res://assets/sprites/player/walk/walk_%03d.png" % i))
	for i in range(1, 21):
		tex_run_frames.append(load("res://assets/sprites/player/run/run__%03d.png" % i))
	for i in range(1, 24):
		tex_stop_frames.append(load("res://assets/sprites/player/stop/stop__%03d.png" % i))
	for i in range(2, 26):
		tex_run_jump_frames.append(load("res://assets/sprites/player/run_jump/run_jump__%03d.png" % i))
	for i in range(1, 38):
		tex_jump_frames.append(load("res://assets/sprites/player/jump/jump__%03d.png" % i))
	for i in range(1, DOUBLE_JUMP_FRAMES + 1):
		tex_double_jump_frames.append(load("res://assets/sprites/player/double_jump_final/double_jump__%03d.png" % i))
	for i in range(1, 13):
		tex_jump_to_crouch_frames.append(load("res://assets/sprites/player/jump_to_crouch/jump_to_crouch___%03d.png" % i))
	for i in range(3, 10):
		tex_crouch_frames.append(load("res://assets/sprites/player/crouch/crouch___%03d.png" % i))
	for i in range(3, 9):
		tex_stand_frames.append(load("res://assets/sprites/player/stand/stand___%03d.png" % i))
	for i in range(1, 27):
		tex_crouch_walk_frames.append(load("res://assets/sprites/player/crouch_walk/crouch_walk___%03d.png" % i))
	for i in range(1, 98):
		tex_slide_frames.append(load("res://assets/sprites/player/slide/slide_%03d.png" % i))
	for i in range(1, 98):
		tex_run_punch_frames.append(load("res://assets/sprites/player/run_punch/run_punch_%03d.png" % i))
	sprite.texture = tex_idle_frames[0]
	if not InputMap.has_action("nitro"):
		InputMap.add_action("nitro")
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		InputMap.action_add_event("nitro", ev)
	_create_shadow()
	_create_slide_dust()
	if has_bengala:
		_create_bengala()

func _physics_process(delta: float) -> void:
	# Flag de caída silenciosa desde auto aéreo (sin animación de jump)
	if is_on_floor():
		_aerial_drop = false
		coyote_timer = COYOTE_TIME
	else:
		if _last_on_aerial:
			_aerial_drop = true
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	_apply_gravity(delta)
	_tick_timers(delta)
	_tick_nitro(delta)

	if state == State.DEAD:
		_handle_dead(delta)
		_update_sprite()
		return

	if _cutscene_locked:
		velocity.x = 0.0
		state      = State.IDLE
		_update_collision()
		_update_sprite()
		move_and_slide()
		return

	# Durante el empuje (hitstun) el input no responde: solo el knockback mueve al pj.
	# Recien cuando termina el alejamiento vuelve el control normal.
	if hitstun_timer > 0.0:
		hitstun_timer -= delta
		velocity.x    = knockback_vel
		knockback_vel = move_toward(knockback_vel, 0.0, 520.0 * delta)
		_update_collision()
		_update_sprite()
		move_and_slide()
		return

	# Coyote time: se cayó del borde hace instantes sin saltar — le damos el
	# mismo salto que hubiera tenido parado en el piso, en vez de procesar
	# el estado FALL como si nada este frame.
	var coyote_jumped := false
	if state == State.FALL and coyote_timer > 0.0 and Input.is_action_just_pressed("ui_up"):
		coyote_timer = 0.0
		_start_coyote_jump()
		coyote_jumped = true

	if not coyote_jumped:
		match state:
			State.IDLE, State.WALK, State.RUN:  _handle_ground(delta)
			State.STOP:              _handle_stop(delta)
			State.RUN_JUMP:          _handle_run_jump(delta)
			State.JUMP_SQUAT:        _handle_jump_squat(delta)
			State.CROUCH:            _handle_crouch(delta)
			State.CROUCH_WALK:       _handle_crouch_walk(delta)
			State.STAND:             _handle_stand(delta)
			State.ROLL:              _handle_roll(delta)
			State.JUMP, State.FALL:  _handle_air(delta)
			State.DOUBLE_JUMP:       _handle_double_jump(delta)
			State.JUMP_TO_CROUCH:    _handle_jump_to_crouch(delta)
			State.LAND:              _handle_land(delta)
			State.ATTACKING:         _handle_attacking(delta)
			State.AIR_ATTACKING:     _handle_air_attacking(delta)
			State.AIR_KICKING:       _handle_air_kicking(delta)
			State.SLIDE:             _handle_slide(delta)
			State.RUN_PUNCH:         _handle_run_punch(delta)
			State.CROUCH_ATTACKING:  _handle_crouch_attacking(delta)
	_update_collision()
	_update_sprite()
	_update_aerial_shadow(delta)
	_separate_from_enemies(delta)
	# Aplicar y decaer knockback del jugador
	velocity.x += knockback_vel
	knockback_vel = move_toward(knockback_vel, 0.0, 520.0 * delta)
	_update_shake(delta)
	_update_slide_fx(delta)
	move_and_slide()

	# Trackear superficie — después de move_and_slide() para tener colisiones actualizadas
	if is_on_floor():
		_last_surface_ground_car = false
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var collider := col.get_collider() as CollisionObject2D
			if collider and collider.is_in_group("car_obstacle") and not collider.is_in_group("car_obstacle_tall") \
					and (collider.collision_layer == 1 or collider.collision_layer == 8):
				_last_surface_ground_car = true
				break
	# Bloqueo global: si entró en FALL justo al salir de un auto del piso, cancelarlo
	if state == State.FALL and _last_surface_ground_car:
		state = State.RUN if abs(velocity.x) > 10.0 else State.IDLE

	_last_on_aerial = _is_on_aerial_car()
	if _last_on_aerial:
		_aerial_z_hold = 6
	elif _aerial_z_hold > 0:
		_aerial_z_hold -= 1
	z_index = 5 if (_last_on_aerial or _aerial_z_hold > 0) else 3

func _apply_gravity(delta: float) -> void:
	if state == State.DEAD: return
	if not is_on_floor():
		if velocity.y < 0.0 \
				and (state == State.JUMP or state == State.RUN_JUMP) \
				and not Input.is_action_pressed("ui_up"):
			velocity.y = 0.0   # soltó el botón → corta el ascenso, empieza a caer
		else:
			velocity.y += GRAVITY * delta

func _tick_timers(delta: float) -> void:
	if iframe_timer > 0.0:          iframe_timer          -= delta
	if combo_cooldown_timer > 0.0: combo_cooldown_timer -= delta
	if state == State.IDLE:
		idle_frame_timer += delta
		if idle_frame_timer >= 1.0 / IDLE_FPS:
			idle_frame_timer -= 1.0 / IDLE_FPS
			idle_frame_index = (idle_frame_index + 1) % tex_idle_frames.size()
	if state == State.WALK:
		walk_frame_timer += delta
		if walk_frame_timer >= 1.0 / WALK_FPS:
			walk_frame_timer -= 1.0 / WALK_FPS
			walk_frame_index = (walk_frame_index + 1) % tex_walk_frames.size()
	if state == State.RUN:
		run_frame_timer += delta
		while run_frame_timer >= 1.0 / RUN_FPS:
			run_frame_timer -= 1.0 / RUN_FPS
			run_frame_index = (run_frame_index + 1) % tex_run_frames.size()
	if state == State.STOP:
		var sfps := STOP_WALK_FPS if stop_from_walk else STOP_FPS
		stop_frame_timer += delta
		if stop_frame_timer >= 1.0 / sfps:
			stop_frame_timer -= 1.0 / sfps
			stop_frame_index = mini(stop_frame_index + 1, tex_stop_frames.size() - 1)
	if state == State.RUN_JUMP:
		run_jump_frame_timer += delta
		if run_jump_frame_timer >= 1.0 / RUN_JUMP_FPS:
			run_jump_frame_timer -= 1.0 / RUN_JUMP_FPS
			run_jump_frame_index = mini(run_jump_frame_index + 1, tex_run_jump_frames.size() - 1)
	if state == State.CROUCH:
		if crouch_frame_index < tex_crouch_frames.size() - 1:
			var cfps := CROUCH_FAST_FPS if crouch_fast else CROUCH_FPS
			crouch_frame_timer += delta
			if crouch_frame_timer >= 1.0 / cfps:
				crouch_frame_timer -= 1.0 / cfps
				crouch_frame_index = mini(crouch_frame_index + 1, tex_crouch_frames.size() - 1)
	if state == State.CROUCH_WALK:
		crouch_walk_frame_timer += delta
		if crouch_walk_frame_timer >= 1.0 / CROUCH_WALK_FPS:
			crouch_walk_frame_timer -= 1.0 / CROUCH_WALK_FPS
			crouch_walk_frame_index = (crouch_walk_frame_index + 1) % tex_crouch_walk_frames.size()
	if state == State.STAND:
		var fps := STAND_FAST_FPS if stand_fast else STAND_FPS
		stand_frame_timer += delta
		if stand_frame_timer >= 1.0 / fps:
			stand_frame_timer -= 1.0 / fps
			stand_frame_index = mini(stand_frame_index + 1, tex_stand_frames.size() - 1)

	if state in [State.JUMP_SQUAT, State.JUMP, State.FALL, State.LAND]:
		var ducking_in_air := Input.is_action_pressed("ui_down") and state in [State.JUMP, State.FALL]
		var freeze_at_peak := state in [State.JUMP, State.FALL] and (
			(not jump_from_run and not ducking_in_air and jump_frame_index >= 20) or
			(not jump_from_run and ducking_in_air and jump_frame_index >= 34) or
			(jump_from_run and jump_frame_index >= 22)
		)
		if not freeze_at_peak:
			jump_frame_timer += delta
			if jump_frame_timer >= 1.0 / JUMP_FPS:
				jump_frame_timer -= 1.0 / JUMP_FPS
				jump_frame_index = mini(jump_frame_index + 1, tex_jump_frames.size() - 1)
		if ducking_in_air and not jump_from_run and jump_frame_index >= 34:
			jump_to_crouch_frame_index = 0
			jump_to_crouch_frame_timer = 0.0
			state = State.JUMP_TO_CROUCH
	if state == State.JUMP_TO_CROUCH:
		jump_to_crouch_frame_timer += delta
		if jump_to_crouch_frame_timer >= 1.0 / JUMP_TO_CROUCH_FPS:
			jump_to_crouch_frame_timer -= 1.0 / JUMP_TO_CROUCH_FPS
			jump_to_crouch_frame_index = mini(jump_to_crouch_frame_index + 1, tex_jump_to_crouch_frames.size() - 1)
	if state == State.ATTACKING and current_attack == AttackType.JAB:
		jab_frame_timer += delta
		if jab_frame_timer >= 1.0 / JAB_FPS:
			jab_frame_timer -= 1.0 / JAB_FPS
			jab_frame_index = mini(jab_frame_index + 1, tex_jab_frames.size() - 1)
	if state == State.ATTACKING and current_attack == AttackType.HOOK:
		hook_frame_timer += delta
		if hook_frame_timer >= 1.0 / HOOK_FPS:
			hook_frame_timer -= 1.0 / HOOK_FPS
			hook_frame_index = mini(hook_frame_index + 1, tex_hook_frames.size() - 1)
	if state == State.ATTACKING and current_attack == AttackType.UPPERCUT:
		uppercut_frame_timer += delta
		if uppercut_frame_timer >= 1.0 / UPPERCUT_FPS:
			uppercut_frame_timer -= 1.0 / UPPERCUT_FPS
			uppercut_frame_index = mini(uppercut_frame_index + 1, tex_uppercut_frames.size() - 1)
	if state == State.ATTACKING and current_attack == AttackType.KICK:
		kick_frame_timer += delta
		if kick_frame_timer >= 1.0 / KICK_FPS:
			kick_frame_timer -= 1.0 / KICK_FPS
			kick_frame_index = mini(kick_frame_index + 1, tex_kick_frames.size() - 1)
	if state == State.ATTACKING and current_attack == AttackType.FLYING_KICK:
		flying_kick_frame_timer += delta
		if flying_kick_frame_timer >= 1.0 / FLYING_KICK_FPS:
			flying_kick_frame_timer -= 1.0 / FLYING_KICK_FPS
			flying_kick_frame_index = mini(flying_kick_frame_index + 1, tex_flying_kick_frames.size() - 1)
		if not flying_kick_hit_done and flying_kick_frame_index >= FLYING_KICK_IMPACT:
			flying_kick_hit_done = true
			_flying_kick_impact()
	if state == State.ATTACKING and current_attack == AttackType.THROW:
		throw_frame_timer += delta
		if throw_frame_timer >= 1.0 / THROW_FPS:
			throw_frame_timer -= 1.0 / THROW_FPS
			throw_frame_index = mini(throw_frame_index + 1, tex_throw_frames.size() - 1)
		# Soltar la lata cuando el brazo esta extendido
		if not throw_can_spawned and throw_frame_index >= THROW_SPAWN_FRAME:
			throw_can_spawned = true
			_spawn_can()

# ── Muerte ───────────────────────────────────────────────────────────────────

func _die() -> void:
	state         = State.DEAD
	velocity      = Vector2.ZERO
	death_timer   = DEATH_FADE_DUR
	collision.set_deferred("disabled", true)

func _handle_dead(delta: float) -> void:
	velocity    = Vector2.ZERO
	death_timer = max(death_timer - delta, 0.0)
	if death_timer <= 0.0:
		get_tree().reload_current_scene()

# ── Lock de cutscene (ver level1.gd — pausa de llegada a la pizzeria) ────────

func set_cutscene_lock(locked: bool) -> void:
	_cutscene_locked = locked
	if locked:
		velocity = Vector2.ZERO
		state    = State.IDLE

# ── Daño recibido ─────────────────────────────────────────────────────────────

func take_damage(amount: int, from_right: bool, knockback: float = 200.0) -> void:
	if state == State.DEAD: return
	if iframe_timer > 0.0: return
	hp            = hp - amount
	iframe_timer  = IFRAME_DUR
	velocity.x    = 0.0
	knockback_vel = knockback * (1.0 if from_right else -1.0)
	# Bloqueo de input mínimo = lo que dura el parpadeo, tenga o no empuje
	# físico (antes, con knockback=0 como el machetazo del boss, no se
	# bloqueaba nada). Un empuje grande igual puede extenderlo más allá.
	hitstun_timer = maxf(IFRAME_DUR, absf(knockback) / 520.0)
	state         = State.IDLE
	if hp <= 0:
		_die()

# ── Golpear enemigos ──────────────────────────────────────────────────────────

func _try_hit_enemies(damage: int) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var e := enemy as Node2D
		if not e: continue
		var dx: float = e.global_position.x - global_position.x
		var dy: float = abs(e.global_position.y - global_position.y)
		if abs(dx) < HIT_RANGE_X and dy < HIT_RANGE_Y and (dx > 0.0) == facing_right:
			if e.has_method("take_damage"):
				e.call("take_damage", damage, dx < 0.0)

# Variante con knockback fuerte y alcance propio; devuelve true si conectó con algún enemigo.
func _try_hit_enemies_kb(damage: int, knockback: float, range_x: float = HIT_RANGE_X) -> bool:
	var hit := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var e := enemy as Node2D
		if not e: continue
		var dx: float = e.global_position.x - global_position.x
		var dy: float = abs(e.global_position.y - global_position.y)
		if abs(dx) < range_x and dy < HIT_RANGE_Y and (dx > 0.0) == facing_right:
			if e.has_method("take_damage"):
				e.call("take_damage", damage, dx < 0.0, knockback)
				hit = true
	return hit

# Golpe del finisher en el frame de impacto: daño + knockback, y si conecta,
# hitstop (freeze) + screen shake para que se sienta el karatazo.
func _flying_kick_impact() -> void:
	if _try_hit_enemies_kb(2, FLYING_KICK_KB, FLYING_KICK_RANGE):
		_do_hitstop(HITSTOP_DUR)
		shake_amount = SHAKE_AMOUNT
		_notify_finisher_hit(FLYING_KICK_RANGE)
	_try_open_door()

# El remate del combo (este golpe) es el único que hace reaccionar al boss
# (ver react_to_finisher en boss.gd) — jab/hook y cualquier otro golpe solo le
# restan vida por take_damage, sin interrumpirlo. Búsqueda separada de
# _try_hit_enemies_kb (que ya aplicó el daño) para no tener que tocar esa
# función compartida con el resto de los enemigos.
func _notify_finisher_hit(range_x: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var e := enemy as Node2D
		if not e: continue
		var dx: float = e.global_position.x - global_position.x
		var dy: float = abs(e.global_position.y - global_position.y)
		if abs(dx) < range_x and dy < HIT_RANGE_Y and (dx > 0.0) == facing_right:
			if e.has_method("react_to_finisher"):
				e.call("react_to_finisher")

func _do_hitstop(dur: float) -> void:
	if _hitstop_active: return
	_hitstop_active = true
	Engine.time_scale = 0.0
	# Timer en tiempo real (ignore_time_scale=true) para que corra con el juego congelado.
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false

func _update_shake(delta: float) -> void:
	if shake_amount > 0.4:
		camera.offset = _cam_base_offset + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount))
		shake_amount = move_toward(shake_amount, 0.0, SHAKE_DECAY * delta)
	elif camera.offset != _cam_base_offset:
		camera.offset = _cam_base_offset

func _spawn_can() -> void:
	var can := CAN_SCENE.instantiate() as Node2D
	get_parent().add_child(can)
	var dir := 1.0 if facing_right else -1.0
	# Sale desde la mano extendida (adelante y a la altura del pecho)
	can.global_position = global_position + Vector2(dir * 42.0, -34.0)
	if can.has_method("init"):
		can.call("init", dir)

func _start_throw() -> void:
	throw_frame_index = 0
	throw_frame_timer = 0.0
	throw_can_spawned = false
	combo_step        = 0
	current_attack    = AttackType.THROW
	attack_timer      = float(THROW_FRAMES) / THROW_FPS
	combo_timer       = 0.0
	attack_queued     = false
	state             = State.ATTACKING
	velocity.x        = 0.0

# ── Suelo ────────────────────────────────────────────────────────────────────

# Coyote time: el jugador dejó el piso hace instantes sin saltar — le damos
# el mismo salto que hubiera tenido parado en el piso, usando el estado que
# tenía justo antes de caerse (_coyote_grounded_state) para decidir animación
# y control aéreo, igual que el salto disparado desde _handle_ground.
func _start_coyote_jump() -> void:
	jump_frame_index         = 3
	jump_frame_timer         = 0.0
	_double_jump_used        = false
	_last_surface_ground_car = false
	jump_from_run            = true
	jump_from_walk           = _coyote_grounded_state != State.RUN
	jump_from_idle           = _coyote_grounded_state == State.IDLE
	velocity.y               = RUN_JUMP_FORCE
	state                    = State.JUMP

func _handle_ground(delta: float) -> void:
	# Si el piso desapareció (borde de auto aéreo) → caída libre, sin acciones hasta aterrizar.
	if not is_on_floor():
		if not _aerial_drop and not _floor_nearby(NEAR_FLOOR_DIST):
			if not _last_surface_ground_car:
				_fall_from_run          = (state == State.RUN)
				_coyote_grounded_state  = state
				jump_from_run  = false
				jump_from_walk = false
				jump_from_idle = false
				if _fall_from_run:
					velocity.y = abs(velocity.x)
				state = State.FALL
		return

	if nitro_active and state == State.RUN:
		_handle_nitro_run(delta)
		return

	if not Input.is_action_pressed("ui_down"):
		slide_no_retrigger = false

	if Input.is_action_pressed("ui_down"):
		if state != State.RUN and Input.is_action_just_pressed("attack"):
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			_start_attack(AttackType.SWEEP, 0.30, 0.0)
			_try_hit_enemies(1)
			return

		if not slide_no_retrigger:
			var dir := Input.get_axis("ui_left", "ui_right")
			if dir != 0.0 and state == State.RUN:
				_start_slide(dir)
			elif dir != 0.0:
				facing_right            = dir > 0.0
				sprite.flip_h           = not facing_right
				crouch_walk_frame_index = 0
				crouch_walk_frame_timer = 0.0
				state                   = State.CROUCH_WALK
			else:
				velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
				if state != State.CROUCH:
					crouch_frame_index = 0
					crouch_frame_timer = 0.0
					crouch_fast        = false
				state = State.CROUCH
		return

	if Input.is_action_just_pressed("throw"):
		_start_throw()
		return

	if Input.is_action_just_pressed("ui_up"):
		jump_frame_index         = 3
		jump_frame_timer         = 0.0
		_double_jump_used        = false
		_last_surface_ground_car = false
		jump_from_run            = true
		jump_from_walk           = state != State.RUN
		jump_from_idle           = state == State.IDLE
		var fwd := Input.get_axis("ui_left", "ui_right")
		var pressing_fwd := fwd != 0.0 and ((fwd > 0.0) == facing_right)
		# Bloqueado por pared: zerear velocidad horizontal para no salir disparado.
		if state == State.RUN and pressing_fwd and absf(velocity.x) < 80.0:
			velocity.x = 0.0
		velocity.y = RUN_JUMP_FORCE
		state      = State.JUMP
		return

	# "attack" es el mismo combo en cualquier estado de piso, incluso RUN: se
	# frena en el acto y pega, aunque se siga presionando hacia adelante.
	if combo_cooldown_timer <= 0.0 and Input.is_action_just_pressed("attack"):
		combo_step = 0
		_launch_combo()
		return

	if state != State.RUN and combo_cooldown_timer <= 0.0 and Input.is_action_just_pressed("kick"):
		kick_frame_index = 0
		kick_frame_timer = 0.0
		_start_attack(AttackType.KICK, 0.35, 0.0)
		_try_hit_enemies(1)
		return

	# PRUEBA: tecla D lanza la patada voladora (finisher candidato)
	if state != State.RUN and combo_cooldown_timer <= 0.0 and Input.is_action_just_pressed("fly_kick"):
		flying_kick_frame_index = 0
		flying_kick_frame_timer = 0.0
		flying_kick_hit_done = false
		_start_attack(AttackType.FLYING_KICK, float(FLYING_KICK_FRAMES) / FLYING_KICK_FPS, 0.0)
		return

	var dir := Input.get_axis("ui_left", "ui_right")
	var walking := Input.is_key_pressed(KEY_SHIFT) and dir != 0.0
	if dir != 0.0:
		if (dir > 0.0 and velocity.x < 0.0) or (dir < 0.0 and velocity.x > 0.0):
			velocity.x = 0.0
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		if walking:
			if state != State.WALK:
				walk_frame_index = 0
				walk_frame_timer = 0.0
			velocity.x = move_toward(velocity.x, dir * (MAX_SPEED * 0.3), ACCELERATION * delta)
			state = State.WALK
		else:
			if state == State.IDLE or state == State.WALK:
				run_frame_index = 0
				run_frame_timer = 0.0
			velocity.x = move_toward(velocity.x, dir * MAX_SPEED, ACCELERATION * delta)
			state = State.RUN
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
		if state == State.RUN:
			stop_frame_index = 0
			stop_frame_timer = 0.0
			stop_from_walk   = false
			run_punch_used   = false
			state = State.STOP
		elif state == State.WALK:
			stop_frame_index = 3
			stop_frame_timer = 0.0
			stop_from_walk   = true
			state = State.STOP
		elif state != State.STOP:
			if state != State.IDLE:
				idle_frame_index = 0
				idle_frame_timer = 0.0
			state = State.IDLE

# ── Agachado ─────────────────────────────────────────────────────────────────

func _handle_crouch(delta: float) -> void:
	if not Input.is_action_pressed("ui_down"):
		stand_frame_index = 0
		stand_frame_timer = 0.0
		crouch_roll_cooldown = 0.0
		state = State.STAND
		return

	if Input.is_action_just_pressed("kick"):
		_start_attack(AttackType.CROUCH_KICK, 0.30, 0.0)
		state = State.CROUCH_ATTACKING
		_try_hit_enemies(1)
		return

	var dir := Input.get_axis("ui_left", "ui_right")
	if crouch_fast and crouch_frame_index >= tex_crouch_frames.size() - 1 and dir != 0.0:
		crouch_fast             = false
		facing_right            = dir > 0.0
		sprite.flip_h           = not facing_right
		crouch_walk_frame_index = 0
		crouch_walk_frame_timer = 0.0
		state                   = State.CROUCH_WALK
	elif crouch_fast and dir != 0.0:
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		velocity.x    = dir * (MAX_SPEED * 0.5)
	elif dir != 0.0 and not crouch_fast:
		facing_right             = dir > 0.0
		sprite.flip_h            = not facing_right
		crouch_walk_frame_index  = 0
		crouch_walk_frame_timer  = 0.0
		state                    = State.CROUCH_WALK
	else:
		velocity.x = 0.0 if crouch_fast else move_toward(velocity.x, 0.0, FRICTION * delta)


func _handle_crouch_walk(delta: float) -> void:
	if not Input.is_action_pressed("ui_down"):
		stand_frame_index = 0
		stand_frame_timer = 0.0
		var dir := Input.get_axis("ui_left", "ui_right")
		stand_fast = dir != 0.0
		state = State.STAND
		return
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		velocity.x    = dir * (MAX_SPEED * 0.3)
	else:
		velocity.x         = 0.0
		crouch_frame_index = tex_crouch_frames.size() - 1
		state              = State.CROUCH

func _handle_jump_to_crouch(_delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		velocity.x    = dir * (MAX_SPEED * 0.5)
	else:
		velocity.x = 0.0
	if is_on_floor() or jump_to_crouch_frame_index >= tex_jump_to_crouch_frames.size() - 1:
		crouch_fast = false
		if dir != 0.0 and is_on_floor():
			# Tocó el piso con dirección → slide (o crouch-walk si el salto salió de walk).
			_land_down_with_dir(dir)
		elif dir != 0.0:
			crouch_walk_frame_index = 0
			crouch_walk_frame_timer = 0.0
			state                   = State.CROUCH_WALK
		else:
			velocity.x         = 0.0
			crouch_frame_index = tex_crouch_frames.size() - 1
			crouch_frame_timer = 0.0
			state              = State.CROUCH

func _handle_stand(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		combo_step = 0
		_launch_combo()
		return
	if Input.is_action_just_pressed("kick"):
		kick_frame_index = 0
		kick_frame_timer = 0.0
		_start_attack(AttackType.KICK, 0.35, 0.0)
		_try_hit_enemies(1)
		return
	var dir := Input.get_axis("ui_left", "ui_right")
	if stand_fast and dir != 0.0:
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		velocity.x    = dir * MAX_SPEED
	else:
		velocity.x = 0.0
	if stand_frame_index >= tex_stand_frames.size() - 1:
		if stand_fast and dir != 0.0:
			stand_fast      = false
			run_frame_index = 0
			run_frame_timer = 0.0
			state           = State.RUN
		else:
			stand_fast       = false
			idle_frame_index = 0
			idle_frame_timer = 0.0
			state            = State.IDLE

func _handle_run_jump(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	if run_jump_frame_index >= tex_run_jump_frames.size() - 1:
		run_jump_hold_timer += delta
		if run_jump_hold_timer >= RUN_JUMP_HOLD_DUR:
			jump_frame_index    = 0
			jump_frame_timer    = 0.0
			run_jump_hold_timer = 0.0
			velocity.y          = JUMP_FORCE
			state               = State.JUMP

func _handle_stop(delta: float) -> void:
	if Input.is_action_just_pressed("throw"):
		_start_throw()
		return
	if Input.is_action_just_pressed("attack"):
		combo_step = 0
		_launch_combo()
		return
	if Input.is_action_just_pressed("kick"):
		kick_frame_index = 0
		kick_frame_timer = 0.0
		_start_attack(AttackType.KICK, 0.35, 0.0)
		_try_hit_enemies(1)
		return
	if Input.is_action_pressed("ui_down"):
		crouch_frame_index = 0
		crouch_frame_timer = 0.0
		crouch_fast        = false
		velocity.x         = 0.0
		state              = State.CROUCH
		return
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		if stop_from_walk and Input.is_key_pressed(KEY_SHIFT):
			stop_from_walk   = false
			walk_frame_index = 0
			walk_frame_timer = 0.0
			state = State.WALK
		else:
			stop_from_walk  = false
			run_frame_index = 0
			run_frame_timer = 0.0
			state = State.RUN
		return
	if Input.is_action_just_pressed("ui_up"):
		# STOP salta corto como walk/idle (poca distancia horizontal)
		jump_frame_index = 3
		jump_frame_timer = 0.0
		jump_from_run    = true
		jump_from_walk   = true
		jump_from_idle   = false
		velocity.y       = RUN_JUMP_FORCE
		state            = State.JUMP
		return
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * 6.0 * delta)
	if stop_frame_index >= tex_stop_frames.size() - 1:
		idle_frame_index = 0
		idle_frame_timer = 0.0
		state = State.IDLE


func _handle_jump_squat(delta: float) -> void:
	if not jump_from_run:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	jump_squat_timer -= delta
	if jump_squat_timer <= 0.0:
		velocity.y = JUMP_FORCE
		state      = State.JUMP

func _handle_land(delta: float) -> void:
	if Input.is_action_pressed("ui_down"):
		var land_dir := Input.get_axis("ui_left", "ui_right")
		if land_dir != 0.0:
			# ↓ + dirección al aterrizar → slide (o crouch-walk si el salto salió de walk).
			_land_down_with_dir(land_dir)
		else:
			velocity.x         = 0.0
			crouch_frame_index = 4
			crouch_frame_timer = 0.0
			crouch_fast        = true
			state              = State.CROUCH
		return
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		facing_right    = dir > 0.0
		sprite.flip_h   = not facing_right
		velocity.x      = dir * MAX_SPEED
		run_frame_index = 0
		run_frame_timer = 0.0
		jump_frame_index = 0
		state = State.RUN
		return
	velocity.x = 0.0
	if Input.is_action_just_pressed("ui_up"):
		# Salto parado tras aterrizar: corto como walk/idle
		jump_frame_index = 0
		jump_frame_timer = 0.0
		jump_from_run    = false
		jump_from_walk   = true
		jump_from_idle   = true
		jump_squat_timer = JUMP_SQUAT_DUR
		velocity.x       = 0.0
		state            = State.JUMP_SQUAT
		return
	var land_max := tex_run_jump_frames.size() - 1 if jump_from_run else tex_jump_frames.size() - 1
	if jump_frame_index >= land_max:
		jump_frame_index = 0
		var land_dir := Input.get_axis("ui_left", "ui_right")
		if land_dir != 0.0:
			facing_right    = land_dir > 0.0
			sprite.flip_h   = not facing_right
			velocity.x      = land_dir * MAX_SPEED
			run_frame_index = 0
			run_frame_timer = 0.0
			state           = State.RUN
		else:
			velocity.x       = 0.0
			idle_frame_index = 0
			idle_frame_timer = 0.0
			state = State.IDLE

func _start_roll(dir: float) -> void:
	roll_dir       = dir
	facing_right   = dir > 0.0
	sprite.flip_h  = not facing_right
	roll_remaining = ROLL_DIST
	state          = State.ROLL

func _handle_roll(delta: float) -> void:
	velocity.x     = roll_dir * ROLL_SPEED
	roll_remaining -= ROLL_SPEED * delta
	if roll_remaining <= 0.0:
		velocity.x           = 0.0
		roll_remaining       = 0.0
		crouch_roll_cooldown = ROLL_PAUSE
		crouch_frame_index   = tex_crouch_frames.size() - 1
		state                = State.CROUCH

# ── Aire ─────────────────────────────────────────────────────────────────────

func _handle_air(delta: float) -> void:
	# Guarda solo para el arranque de un salto de verdad (frames de despegue).
	# Si la caída viene de bajarse de un borde alto (_fall_from_run, sin saltar),
	# el contador de frame puede haber quedado <8 por casualidad de un salto
	# anterior — no debe frenar la inercia horizontal en ese caso.
	if jump_frame_index < 8 and not jump_from_run and not jump_from_idle and not _fall_from_run:
		velocity.x = 0.0
		return
	var dir := Input.get_axis("ui_left", "ui_right")
	var air_max: float
	if jump_from_idle:
		air_max = IDLE_JUMP_AIR_SPEED
	elif jump_from_walk:
		air_max = MAX_SPEED * 0.5
	else:
		air_max = MAX_SPEED * NITRO_SPEED_MULT if nitro_active else MAX_SPEED
	if dir != 0.0:
		# Se puede girar en el aire las veces que quiera. Si invierte la
		# dirección, la inercia se invierte con él: misma fuerza, otro sentido,
		# en vez de frenar y volver a acelerar desde cero.
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		if sign(dir) != sign(velocity.x) and absf(velocity.x) > 1.0:
			velocity.x = -velocity.x
		if is_on_wall():
			velocity.x = move_toward(velocity.x, 0.0, AIR_BRAKE * delta)
		else:
			velocity.x = move_toward(velocity.x, dir * air_max, AIR_BRAKE * delta)
	else:
		if not _fall_from_run:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta * 0.3)

	if Input.is_action_just_pressed("ui_up") and not _double_jump_used:
		_double_jump_used        = true
		double_jump_frame_index  = 22
		double_jump_frame_timer  = 0.0
		velocity.y               = DOUBLE_JUMP_FORCE
		state                    = State.DOUBLE_JUMP
		_dj_buffered_kick        = false
		_dj_buffered_down_kick   = false
		return

	if Input.is_action_just_pressed("attack"):
		air_kick_frame_index = 0
		air_kick_frame_timer = 0.0
		air_kick_connected   = false
		air_kick_speed       = 0.0   # sin impulso horizontal: cae vertical sobre el enemigo
		state                = State.AIR_KICKING
		return

	if Input.is_action_just_pressed("kick") and Input.is_action_pressed("ui_down"):
		current_attack = AttackType.AIR_DOWN_KICK
		attack_timer   = 0.30
		velocity.y     = 220.0
		state          = State.AIR_ATTACKING
		_try_hit_enemies(2)
		return

	if is_on_floor():
		if Input.is_action_pressed("ui_down"):
			var land_dir := Input.get_axis("ui_left", "ui_right")
			if land_dir != 0.0:
				# Venías del aire con ↓ + dirección → al caer, slide (o crouch-walk si el salto salió de walk).
				_land_down_with_dir(land_dir)
			else:
				velocity.x         = 0.0
				crouch_frame_index = 4
				crouch_frame_timer = 0.0
				crouch_fast        = true
				state              = State.CROUCH
		elif jump_from_run:
			_fall_from_run   = false
			jump_frame_index = 23
			jump_frame_timer = 0.0
			state            = State.LAND
		else:
			var land_dir := Input.get_axis("ui_left", "ui_right")
			if land_dir != 0.0:
				facing_right    = land_dir > 0.0
				sprite.flip_h   = not facing_right
				if not _fall_from_run:
					velocity.x  = land_dir * MAX_SPEED
				_fall_from_run  = false
				run_frame_index = 0
				run_frame_timer = 0.0
				state           = State.RUN
			else:
				_fall_from_run   = false
				jump_frame_index = 33
				jump_frame_timer = 0.0
				state = State.LAND
	elif velocity.y > 0.0:
		state = State.FALL

func _handle_double_jump(delta: float) -> void:
	# La vuelta del doble salto NUNCA se corta — pero si el jugador ya
	# presionó kick (o kick+↓) mientras giraba, queda bufferizado y se
	# dispara al instante de terminar la animación, sin tener que soltar
	# y volver a presionar.
	if Input.is_action_just_pressed("attack"):
		_dj_buffered_kick = true
	if Input.is_action_just_pressed("kick") and Input.is_action_pressed("ui_down"):
		_dj_buffered_down_kick = true

	# Avanzar frames hasta el último de la vuelta
	if tex_double_jump_frames.size() > 0:
		double_jump_frame_timer += delta
		if double_jump_frame_timer >= 1.0 / DOUBLE_JUMP_FPS:
			double_jump_frame_timer -= 1.0 / DOUBLE_JUMP_FPS
			double_jump_frame_index = mini(double_jump_frame_index + 1, DOUBLE_JUMP_LAST_FRAME)

	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		if sign(dir) != sign(velocity.x) and absf(velocity.x) > 1.0:
			velocity.x = -velocity.x
		velocity.x = move_toward(velocity.x, dir * MAX_SPEED, 800.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta * 0.3)

	# Al terminar la vuelta: si había un kick bufferizado, se dispara ya mismo;
	# si no, pasa al frame congelado del jump normal → caída idéntica.
	if double_jump_frame_index >= DOUBLE_JUMP_LAST_FRAME:
		if _dj_buffered_kick:
			_dj_buffered_kick      = false
			_dj_buffered_down_kick = false
			air_kick_frame_index = 0
			air_kick_frame_timer = 0.0
			air_kick_connected   = false
			air_kick_speed       = 0.0   # sin impulso horizontal: cae vertical sobre el enemigo
			state                = State.AIR_KICKING
			return
		if _dj_buffered_down_kick:
			_dj_buffered_kick      = false
			_dj_buffered_down_kick = false
			current_attack = AttackType.AIR_DOWN_KICK
			attack_timer   = 0.30
			velocity.y     = 220.0
			state          = State.AIR_ATTACKING
			_try_hit_enemies(2)
			return
		jump_from_run    = false
		jump_frame_index = 20
		jump_frame_timer = 0.0
		state            = State.FALL

# ── Sistema de combos ─────────────────────────────────────────────────────────

func _launch_combo() -> void:
	var dmg := 1
	match combo_step:
		0:
			jab_frame_index = 0
			jab_frame_timer = 0.0
			_start_attack(AttackType.JAB,      COMBO_HIT_DUR, COMBO_WINDOW)
		1:
			hook_frame_index = 0
			hook_frame_timer = 0.0
			_start_attack(AttackType.HOOK,     COMBO_HIT_DUR, COMBO_WINDOW)
		2:
			flying_kick_frame_index = 0
			flying_kick_frame_timer = 0.0
			flying_kick_hit_done = false
			_start_attack(AttackType.FLYING_KICK, float(FLYING_KICK_FRAMES) / FLYING_KICK_FPS, 0.0)
			_try_open_door()
			return  # el golpe se registra en el frame de impacto (con hitstop + shake)
	_try_hit_enemies(dmg)
	_try_open_door()

func _start_attack(type: AttackType, duration: float, window: float) -> void:
	current_attack = type
	attack_timer   = duration
	combo_timer    = window
	attack_queued  = false
	state          = State.ATTACKING
	velocity.x     = 0.0

func _handle_attacking(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	if Input.is_action_just_pressed("attack") and combo_step < 2 and combo_timer > 0.0:
		attack_queued = true

	attack_timer -= delta
	combo_timer   = max(combo_timer - delta, 0.0)

	if attack_timer <= 0.0:
		if attack_queued:
			combo_step   += 1
			attack_queued = false
			_launch_combo()
		elif combo_timer <= 0.0:
			if combo_step == 2:
				combo_cooldown_timer = COMBO_COOLDOWN
			combo_step = 0
			# Va a IDLE aunque se siga sosteniendo la dirección — así, si el
			# siguiente attack llega con un pequeño gap, te encuentra parado y
			# arranca un combo nuevo en el lugar en vez de tener que frenar un
			# RUN a toda velocidad primero. Si no llega, _handle_ground vuelve
			# a correr solo por el input sostenido, como cualquier otro caso.
			idle_frame_index = 0
			idle_frame_timer = 0.0
			state = State.IDLE if is_on_floor() else State.FALL

func _handle_air_attacking(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		if sign(dir) != sign(velocity.x) and absf(velocity.x) > 1.0:
			velocity.x = -velocity.x
		velocity.x = move_toward(velocity.x, dir * MAX_SPEED, ACCELERATION * delta * 0.4)

	attack_timer -= delta
	if attack_timer <= 0.0:
		idle_frame_index = 0
		idle_frame_timer = 0.0
		state = State.IDLE if is_on_floor() else (State.FALL if velocity.y > 0.0 else State.JUMP)

# Patada aérea: se dispara en el aire y la gravedad la baja al piso; mientras
# esté en el aire la animación se congela en AIR_KICK_HOLD hasta pegar o
# acercarse al piso. Al tocar el piso corta al instante a crouch/run/idle
# según el input, sin esperar a que termine la animación de recovery.
func _handle_air_kicking(delta: float) -> void:
	var grounded := is_on_floor()
	if grounded:
		# Al tocar el piso corta la animación al instante, sin esperar a que
		# termine el recovery: el input puede arrancar crouch/run, y sin input
		# va directo a idle — igual que un aterrizaje normal de salto.
		if Input.is_action_pressed("ui_down"):
			crouch_frame_index = 0
			crouch_frame_timer = 0.0
			crouch_fast        = false
			state = State.CROUCH
			return
		var idir := Input.get_axis("ui_left", "ui_right")
		if idir != 0.0:
			facing_right    = idir > 0.0
			sprite.flip_h   = not facing_right
			run_frame_index = 0
			run_frame_timer = 0.0
			velocity.x      = idir * MAX_SPEED
			state = State.RUN
			return
		velocity.x        = 0.0
		idle_frame_index  = 0
		idle_frame_timer  = 0.0
		state             = State.IDLE
		return
	# Se puede girar en el aire durante la patada, igual que en un salto normal.
	var air_dir := Input.get_axis("ui_left", "ui_right")
	if air_dir != 0.0:
		facing_right  = air_dir > 0.0
		sprite.flip_h = not facing_right
		if sign(air_dir) != sign(velocity.x) and absf(velocity.x) > 1.0:
			velocity.x = -velocity.x
		velocity.x = move_toward(velocity.x, air_dir * (MAX_SPEED * 0.5), AIR_BRAKE * delta)
	# Golpe: al llegar a la pierna extendida sigue chequeando enemigos hasta conectar.
	if not air_kick_connected and air_kick_frame_index >= AIR_KICK_IMPACT:
		var hit := false
		var hit_cop := false
		for _ae in get_tree().get_nodes_in_group("enemy"):
			var e := _ae as Node2D
			if not e: continue
			var dx: float = e.global_position.x - global_position.x
			var dy: float = abs(e.global_position.y - global_position.y)
			if abs(dx) < FLYING_KICK_RANGE and dy < HIT_RANGE_Y and (dx > 0.0) == facing_right:
				if e.has_method("take_weakness_damage"):
					e.call("take_weakness_damage", dx < 0.0)
				elif e.has_method("take_damage"):
					e.call("take_damage", 2, dx < 0.0, AIR_KICK_KB)
				hit = true
				if e.get("obstacle_mode"):
					hit_cop = true
		if hit:
			air_kick_connected = true
			# Cop-obstáculo: sin hitstop, no puede haber corte de velocidad en tráfico.
			if not hit_cop:
				_do_hitstop(HITSTOP_DUR)
				shake_amount = SHAKE_AMOUNT

	# Avanzar frames: velocidad normal hasta el freeze, más rápido en el recovery.
	var fps: float = AIR_KICK_FPS if air_kick_frame_index < AIR_KICK_HOLD else AIR_KICK_RECOVER_FPS
	air_kick_frame_timer += delta
	var step := air_kick_frame_timer >= 1.0 / fps
	if step:
		air_kick_frame_timer -= 1.0 / fps

	var last := tex_air_kick_frames.size() - 1
	# grounded siempre es false acá abajo: si tocó el piso, la rama de arriba
	# ya hizo return con el estado resuelto (crouch/run/idle) este mismo frame.
	var near_ground := test_move(global_transform, Vector2(0.0, AIR_KICK_NEAR_GROUND))

	# Freno en la patada extendida hasta pegar o acercarse al piso.
	var cap := last
	if not (air_kick_connected or near_ground):
		cap = AIR_KICK_HOLD
	if step:
		air_kick_frame_index = mini(air_kick_frame_index + 1, cap)

func _handle_crouch_attacking(delta: float) -> void:
	velocity.x   = move_toward(velocity.x, 0.0, FRICTION * delta)
	attack_timer -= delta
	if attack_timer <= 0.0:
		state = State.CROUCH

# ── Slide (pop-up slide de béisbol) ──────────────────────────────────────────

# Aterrizar con ↓ + dirección: solo el salto de RUN cae en slide. Cualquier salto
# suave (walk, idle/parado, stop → todos con jump_from_walk=true) cae en caminar agachado.
func _land_down_with_dir(land_dir: float) -> void:
	if jump_from_walk:
		facing_right            = land_dir > 0.0
		sprite.flip_h           = not facing_right
		crouch_walk_frame_index = 0
		crouch_walk_frame_timer = 0.0
		state                   = State.CROUCH_WALK
	else:
		_start_slide(land_dir)

func _start_slide(dir: float) -> void:
	slide_from_run    = (state == State.RUN)
	facing_right      = dir > 0.0
	sprite.flip_h     = not facing_right
	slide_dir         = 1.0 if facing_right else -1.0
	slide_frame_index = SLIDE_START_FRAME
	slide_frame_timer = 0.0
	slide_hold_timer  = 0.0
	slide_hit_ids.clear()
	slide_hit_stopped = false
	velocity.x        = slide_dir * maxf(MAX_SPEED, absf(velocity.x))  # hereda el envión
	state             = State.SLIDE
	if _slide_dust:
		var mat := _slide_dust.process_material as ParticleProcessMaterial
		if mat:
			mat.direction = Vector3(-slide_dir, -0.35, 0.0)  # el polvo sale para atrás, contra el avance

func _handle_slide(delta: float) -> void:
	# Soltó ↓ → vuelve a run, SALVO que esté bajo un auto aéreo (debe cruzarlo completo).
	if not Input.is_action_pressed("ui_down") and not _is_under_aerial_car():
		run_frame_index = 0
		run_frame_timer = 0.0
		velocity.x      = slide_dir * (MAX_SPEED * NITRO_SPEED_MULT if nitro_active else MAX_SPEED)
		state           = State.RUN
		return

	# Se desplaza a la MISMA velocidad que el run, constante, durante todo el slide.
	velocity.x = slide_dir * (MAX_SPEED * NITRO_SPEED_MULT if nitro_active else MAX_SPEED)

	# Avance de frames rápido, pero se congela en SLIDE_HOLD_FRAME (slide_030)
	# durante SLIDE_HOLD_DUR mientras sigue deslizándose por el piso.
	if slide_frame_index == SLIDE_HOLD_FRAME and slide_hold_timer < SLIDE_HOLD_DUR:
		slide_hold_timer += delta
	else:
		# Al salir del congelado (frame 30 en adelante) va mucho más rápido a run.
		# while (no if): permite avanzar varios frames por tick de física, así FPS > 60
		# realmente acelera la animación en vez de quedar capado a la tasa de física.
		var sfps := SLIDE_EXIT_FPS if slide_frame_index >= SLIDE_HOLD_FRAME else SLIDE_FPS
		slide_frame_timer += delta
		while slide_frame_timer >= 1.0 / sfps and slide_frame_index < SLIDE_END_FRAME:
			slide_frame_timer -= 1.0 / sfps
			slide_frame_index += 1

	# Barrida activa mientras el jugador se desliza por el piso (frames START→HIT_END)
	if slide_frame_index >= SLIDE_START_FRAME and slide_frame_index <= SLIDE_HIT_END:
		_slide_sweep()

	# Encadena directo a caminar agachado: si venís apretando ↓ + dirección no hace falta
	# terminar de pararse, cortá en SLIDE_CROUCHWALK_FRAME (slide_062) y pasá a crouch-walk.
	# Excepción: si el slide vino de RUN, soltar ↓ encadena directo a RUN.
	if slide_frame_index >= SLIDE_CROUCHWALK_FRAME and Input.is_action_pressed("ui_down"):
		var cw_dir := Input.get_axis("ui_left", "ui_right")
		if cw_dir != 0.0:
			facing_right       = cw_dir > 0.0
			sprite.flip_h      = not facing_right
			slide_no_retrigger = true
			state              = State.RUN
		else:
			velocity.x         = 0.0
			crouch_fast        = false
			crouch_frame_index = tex_crouch_frames.size() - 1
			crouch_frame_timer = 0.0
			state              = State.CROUCH
		return

	# Si la animación terminó pero sigue bajo un auto aéreo, congela en el hold frame.
	if slide_frame_index >= SLIDE_END_FRAME and _is_under_aerial_car():
		slide_frame_index = SLIDE_HOLD_FRAME
		slide_hold_timer  = 0.0
		return

	# Terminó de levantarse → según el input que mantengas.
	if slide_frame_index >= SLIDE_END_FRAME:
		var dir := Input.get_axis("ui_left", "ui_right")
		if slide_from_run:
			if dir != 0.0:
				facing_right       = dir > 0.0
				sprite.flip_h      = not facing_right
				slide_no_retrigger = true
				state              = State.RUN
			else:
				# Soltó la dirección a mitad del slide → queda agachado
				velocity.x         = 0.0
				crouch_fast        = false
				crouch_frame_index = tex_crouch_frames.size() - 1
				crouch_frame_timer = 0.0
				state              = State.CROUCH
		elif dir != 0.0:
			facing_right       = dir > 0.0
			sprite.flip_h      = not facing_right
			slide_no_retrigger = true
			run_frame_index    = 0
			run_frame_timer    = 0.0
			velocity.x         = dir * MAX_SPEED
			state              = State.RUN
		else:
			slide_no_retrigger = true
			stop_frame_index   = 0
			stop_frame_timer   = 0.0
			stop_from_walk     = false
			state              = State.STOP

# Barre enemigos a su paso: cada enemigo recibe el golpe una sola vez.
func _slide_sweep() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var e := enemy as Node2D
		if not e: continue
		var id := e.get_instance_id()
		if slide_hit_ids.has(id): continue
		var dx: float = e.global_position.x - global_position.x
		var dy: float = abs(e.global_position.y - global_position.y)
		var is_cop_obstacle: bool = e.get("obstacle_mode") == true
		if abs(dx) < SLIDE_RANGE and dy < HIT_RANGE_Y and (dx > 0.0) == facing_right:
			if e.has_method("take_weakness_damage"):
				e.call("take_weakness_damage", dx < 0.0)
			elif e.has_method("take_damage"):
				e.call("take_damage", 1, dx < 0.0, SLIDE_HIT_KB)
			slide_hit_ids[id] = true
			# Freeze + shake livianos, una sola vez por barrida (no uno por enemigo tocado).
			# Se salta con cops-obstáculo: en tráfico no puede haber ninguna
			# interrupción de velocidad, el dron no perdona ni un frame parado.
			if not slide_hit_stopped and not is_cop_obstacle:
				slide_hit_stopped = true
				_do_hitstop(SLIDE_HITSTOP_DUR)
				shake_amount = SLIDE_SHAKE_AMOUNT

# ── Efectos visuales del slide (polvo + afterimages) ─────────────────────────

func _create_slide_dust() -> void:
	_slide_dust = GPUParticles2D.new()
	_slide_dust.z_index      = -1
	_slide_dust.position     = Vector2(0.0, SLIDE_DUST_FEET_OFFSET)
	_slide_dust.local_coords = false   # una vez emitida, la partícula queda en el mundo (no viaja con el jugador)
	_slide_dust.emitting     = false
	_slide_dust.amount       = 16
	_slide_dust.lifetime     = 0.35
	_slide_dust.texture      = _radial_texture(24, Color(0.78, 0.74, 0.68))
	var mat := ParticleProcessMaterial.new()
	mat.direction             = Vector3(-1.0, -0.35, 0.0)  # se corrige por lado en _start_slide()
	mat.spread                = 18.0
	mat.initial_velocity_min  = 60.0
	mat.initial_velocity_max  = 140.0
	mat.gravity               = Vector3(0.0, 260.0, 0.0)
	mat.scale_min             = 0.5
	mat.scale_max             = 1.1
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.78, 0.72, 0.55))
	fade.set_color(1, Color(0.8, 0.78, 0.72, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient    = fade
	mat.color_ramp   = ramp
	_slide_dust.process_material = mat
	add_child(_slide_dust)

# Prende/apaga polvo y afterimages según el estado, centralizado acá para no
# tener que tocar cada punto de salida de _handle_slide().
func _update_slide_fx(delta: float) -> void:
	if _slide_dust:
		_slide_dust.emitting = (state == State.SLIDE)
	if state == State.SLIDE:
		slide_afterimage_timer += delta
		if slide_afterimage_timer >= SLIDE_AFTERIMAGE_INTERVAL:
			slide_afterimage_timer = 0.0
			_spawn_slide_afterimage()
	else:
		slide_afterimage_timer = 0.0

func _spawn_slide_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture         = sprite.texture
	ghost.flip_h          = sprite.flip_h
	ghost.global_position = sprite.global_position
	ghost.z_index         = z_index - 1
	ghost.modulate        = Color(0.55, 0.85, 1.0, 0.35)  # tinte cyan, consistente con el look cyberpunk
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, SLIDE_AFTERIMAGE_DUR)
	tw.tween_callback(ghost.queue_free)

# ── Puñetazo corriendo (run punch) ───────────────────────────────────────────

func _start_run_punch() -> void:
	run_punch_dir         = 1.0 if facing_right else -1.0
	run_punch_frame_index = RUN_PUNCH_START_FRAME
	run_punch_frame_timer = 0.0
	run_punch_hold_timer  = 0.0
	run_punch_hit_done    = false
	run_punch_used        = true
	velocity.x            = run_punch_dir * maxf(MAX_SPEED, absf(velocity.x))  # hereda el envión del run
	state                 = State.RUN_PUNCH

func _handle_run_punch(delta: float) -> void:
	# Lunge hacia adelante que desacelera durante el golpe.
	velocity.x = move_toward(velocity.x, 0.0, RUN_PUNCH_FRICTION * delta)

	# Golpe: registra una sola vez al llegar al frame de impacto, con hitstop + shake.
	if not run_punch_hit_done and run_punch_frame_index >= RUN_PUNCH_IMPACT:
		run_punch_hit_done = true
		if _try_hit_enemies_kb(RUN_PUNCH_DMG, RUN_PUNCH_KB, RUN_PUNCH_RANGE):
			_do_hitstop(HITSTOP_DUR)
			shake_amount = SHAKE_AMOUNT
		_try_open_door()

	# Avance: entra rápido al golpe, se congela en HOLD_FRAME, sale rápido a run.
	if run_punch_frame_index == RUN_PUNCH_HOLD_FRAME and run_punch_hold_timer < RUN_PUNCH_HOLD_DUR:
		run_punch_hold_timer += delta
	else:
		var pfps := RUN_PUNCH_EXIT_FPS if run_punch_frame_index >= RUN_PUNCH_HOLD_FRAME else RUN_PUNCH_FPS
		run_punch_frame_timer += delta
		while run_punch_frame_timer >= 1.0 / pfps and run_punch_frame_index < RUN_PUNCH_END_FRAME:
			run_punch_frame_timer -= 1.0 / pfps
			run_punch_frame_index += 1

	# Terminó → run si mantenés dirección, si no idle.
	if run_punch_frame_index >= RUN_PUNCH_END_FRAME:
		var dir := Input.get_axis("ui_left", "ui_right")
		if dir != 0.0:
			facing_right    = dir > 0.0
			sprite.flip_h   = not facing_right
			run_frame_index = 0
			run_frame_timer = 0.0
			velocity.x      = dir * MAX_SPEED
			state           = State.RUN
		else:
			velocity.x       = 0.0
			idle_frame_index = 0
			idle_frame_timer = 0.0
			state            = State.IDLE

# ── Nitro ────────────────────────────────────────────────────────────────────

func _tick_nitro(delta: float) -> void:
	if nitro_active:
		nitro_timer -= delta
		if nitro_timer <= 0.0:
			nitro_active = false
			nitro_charge = 0.0
		return
	var is_charging := state == State.RUN or state == State.SLIDE \
		or ((state == State.JUMP or state == State.FALL) and jump_from_run)
	if is_charging:
		nitro_charge = minf(nitro_charge + delta, NITRO_CHARGE_DUR)
	elif state == State.IDLE or state == State.WALK:
		nitro_charge = 0.0
	# LAND, STOP, ATTACKING, CROUCH, etc.: mantiene el valor actual
	if nitro_charge >= NITRO_CHARGE_DUR and state == State.RUN:
		if Input.is_action_just_pressed("nitro"):
			nitro_active = true
			nitro_timer  = NITRO_ACTIVE_DUR

func _handle_nitro_run(_delta: float) -> void:
	if Input.is_action_pressed("ui_down"):
		var dir := Input.get_axis("ui_left", "ui_right")
		if dir != 0.0:
			_start_slide(dir)
			return
	if Input.is_action_just_pressed("ui_up"):
		jump_frame_index = 3
		jump_frame_timer = 0.0
		jump_from_run    = true
		jump_from_walk   = false
		jump_from_idle   = false
		velocity.y       = RUN_JUMP_FORCE
		state            = State.JUMP
		return
	velocity.x = (1.0 if facing_right else -1.0) * MAX_SPEED * NITRO_SPEED_MULT

# ── Colisión y sprite ─────────────────────────────────────────────────────────

func _update_collision() -> void:
	var cap := collision.shape as CapsuleShape2D
	if state == State.SLIDE:
		cap.height           = 79.8
		cap.radius           = 30.0
		collision.position.y = 41.7
		collision.position.x = 28.0 if facing_right else -28.0
	elif state in [State.CROUCH, State.CROUCH_WALK, State.ROLL, State.CROUCH_ATTACKING]:
		cap.height           = 79.8
		cap.radius           = 12.0
		collision.position.y = 41.7
		collision.position.x = 10.0 if facing_right else -10.0
	elif state in [State.JUMP_SQUAT, State.JUMP, State.FALL, State.DOUBLE_JUMP]:
		cap.height           = 115.6
		cap.radius           = 12.0
		collision.position.y = 23.8
		collision.position.x = 10.0 if facing_right else -10.0
	else:
		cap.height           = 115.6
		cap.radius           = 12.0
		collision.position.y = 23.8
		collision.position.x = 10.0 if facing_right else -10.0
	# Agachado/slide: ignora autos aéreos y cops (layer 3 = bit 4) para poder
	# pasar por debajo/atravesarlos con la barrida.
	# +16 (WALL_LAYER, ver level1.gd) en los tres casos: las paredes invisibles
	# de la arena del boss tienen que frenar al PP siempre, sin importar el
	# estado — a diferencia de cops/autos, nunca hay que poder atravesarlas.
	if state == State.SLIDE or state == State.CROUCH or state == State.CROUCH_WALK \
			or state == State.ROLL or state == State.CROUCH_ATTACKING:
		collision_mask = 1 | 16
	elif is_on_floor():
		# En el piso, un cop vivo bloquea como un colectivo — no hay forma de
		# atravesarlo corriendo, hay que matarlo (slide/salto+patada) o rodearlo.
		collision_mask = 13 | 16   # 1 (piso/autos) + 4 (cops) + 8 (autos aéreos) + 16 (paredes arena)
	else:
		collision_mask = 9 | 16   # en el aire: sin cops, para poder saltarlos por encima

func _update_sprite() -> void:
	match state:
		State.IDLE:
			if tex_idle_frames.size() > 0:
				sprite.texture = tex_idle_frames[idle_frame_index]
		State.WALK:
			if tex_walk_frames.size() > 0:
				sprite.texture = tex_walk_frames[walk_frame_index]
		State.RUN:
			if tex_run_frames.size() > 0:
				sprite.texture = tex_run_frames[run_frame_index]
		State.STOP:
			if tex_stop_frames.size() > 0:
				sprite.texture = tex_stop_frames[stop_frame_index]
		State.RUN_JUMP:
			if tex_run_jump_frames.size() > 0:
				sprite.texture = tex_run_jump_frames[run_jump_frame_index]
		State.JUMP_TO_CROUCH:
			if tex_jump_to_crouch_frames.size() > 0:
				sprite.texture = tex_jump_to_crouch_frames[jump_to_crouch_frame_index]
		State.DOUBLE_JUMP:
			if tex_double_jump_frames.size() > 0:
				sprite.texture = tex_double_jump_frames[double_jump_frame_index]
		State.JUMP_SQUAT, State.JUMP, State.FALL, State.LAND:
			if jump_from_run and tex_run_jump_frames.size() > 0:
				sprite.texture = tex_run_jump_frames[mini(jump_frame_index, tex_run_jump_frames.size() - 1)]
			elif tex_jump_frames.size() > 0:
				sprite.texture = tex_jump_frames[jump_frame_index]
		State.CROUCH:
			if tex_crouch_frames.size() > 0:
				sprite.texture = tex_crouch_frames[crouch_frame_index]
		State.CROUCH_WALK:
			if tex_crouch_walk_frames.size() > 0:
				sprite.texture = tex_crouch_walk_frames[crouch_walk_frame_index]
		State.STAND:
			if tex_stand_frames.size() > 0:
				sprite.texture = tex_stand_frames[stand_frame_index]
		State.ROLL, State.CROUCH_ATTACKING:
			if tex_crouch_frames.size() > 0:
				sprite.texture = tex_crouch_frames[tex_crouch_frames.size() - 1]
		State.AIR_KICKING:
			if tex_air_kick_frames.size() > 0:
				sprite.texture = tex_air_kick_frames[air_kick_frame_index]
		State.SLIDE:
			if tex_slide_frames.size() > 0:
				sprite.texture = tex_slide_frames[slide_frame_index]
		State.RUN_PUNCH:
			if tex_run_punch_frames.size() > 0:
				sprite.texture = tex_run_punch_frames[run_punch_frame_index]
		State.ATTACKING, State.AIR_ATTACKING:
			match current_attack:
				AttackType.JAB:
					if tex_jab_frames.size() > 0:
						sprite.texture = tex_jab_frames[jab_frame_index]
				AttackType.HOOK:
					if tex_hook_frames.size() > 0:
						sprite.texture = tex_hook_frames[hook_frame_index]
				AttackType.UPPERCUT:
					if tex_uppercut_frames.size() > 0:
						sprite.texture = tex_uppercut_frames[uppercut_frame_index]
				AttackType.KICK:
					if tex_kick_frames.size() > 0:
						sprite.texture = tex_kick_frames[kick_frame_index]
				AttackType.FLYING_KICK:
					if tex_flying_kick_frames.size() > 0:
						sprite.texture = tex_flying_kick_frames[flying_kick_frame_index]
				AttackType.THROW:
					if tex_throw_frames.size() > 0:
						sprite.texture = tex_throw_frames[throw_frame_index]
				_:
					sprite.texture = tex_attack

	if state == State.DEAD:
		sprite.modulate.a = death_timer / DEATH_FADE_DUR
	else:
		sprite.modulate.a = 0.35 if (iframe_timer > 0.0 and int(iframe_timer * 10) % 2 == 0) else 1.0

	if state in [State.JUMP_SQUAT, State.JUMP, State.FALL, State.RUN_JUMP, State.DOUBLE_JUMP, State.JUMP_TO_CROUCH, State.AIR_KICKING]:
		sprite.position.y = -4.0 + JUMP_SPRITE_Y_OFFSET
	else:
		sprite.position.y = -4.0

# ── Sombra ───────────────────────────────────────────────────────────────────
# Misma textura de mancha plana que usan los autos aéreos para su sombra en el
# piso (car_mid_layer.gd, _shadow_tex) — no el blob circular con degradé de antes.
# La imagen tiene mucho relleno transparente alrededor; la mancha real es una
# franja de 1071×38 dentro del lienzo de 1424×642 (recortada con AtlasTexture:
# escalar el lienzo completo hacía que la franja se corriera en vez de crecer
# al pedirle más alto de los dos lados). Con el recorte, ancho/alto de acá en
# más son los de la franja de verdad — crecer o mover ya no se pisan entre sí.
const SHADOW_TEX_PATH    := "res://assets/sprites/cars/side_test/car_side_06 - copia.png"
const SHADOW_CONTENT     := Rect2(196, 588, 1071, 38)
const SHADOW_LEFT_OFFSET  := 31.5  # distancia del centro al borde izquierdo (antes del achique por altura)
const SHADOW_RIGHT_OFFSET := 41.5  # distancia del centro al borde derecho
const SHADOW_Y_NUDGE      := -2.0  # centro de la franja respecto al piso detectado
const SHADOW_TOP_OFFSET   := 0.0   # cuánto sube el borde de arriba desde ese centro
const SHADOW_BOT_OFFSET   := 10.0  # cuánto baja el borde de abajo desde ese centro

func _process(_delta: float) -> void:
	_update_shadow()

func _create_shadow() -> void:
	_shadow = Sprite2D.new()
	_shadow.z_index  = -1
	_shadow.centered = false
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(SHADOW_TEX_PATH)
	atlas.region = SHADOW_CONTENT
	_shadow.texture = atlas
	add_child(_shadow)
	move_child(_shadow, 0)

# Altura real del piso/obstáculo pisable debajo del jugador — igual que un
# auto aéreo siempre sabe dónde está su sombra, esto tira un rayo hacia abajo
# en vez de memorizar la última vez que tocó el suelo (eso quedaba mal ubicado
# durante toda una caída larga desde un bus/camión, corrigiéndose recién al aterrizar).
func _shadow_ground_y() -> float:
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0.0, 3000.0))
	params.collision_mask = 13   # piso/autos (1) + cops (4) + autos aéreos (8): todo lo pisable
	params.exclude        = [get_rid()]
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return global_position.y + SHADOW_FEET_OFFSET
	return hit.position.y

func _update_shadow() -> void:
	if _shadow == null: return
	if state == State.DEAD:
		_shadow.visible = false
		return
	_shadow.visible = true
	_shadow_floor_y = _shadow_ground_y()
	var air_h := maxf(0.0, _shadow_floor_y - (global_position.y + SHADOW_FEET_OFFSET))
	var t := clampf(air_h / SHADOW_MAX_HEIGHT, 0.0, 1.0)
	var fade  := lerpf(1.0, 0.3, t)
	var left  := SHADOW_LEFT_OFFSET * fade
	var right := SHADOW_RIGHT_OFFSET * fade
	var sx    := (left + right) / SHADOW_CONTENT.size.x
	var sy    := (SHADOW_TOP_OFFSET + SHADOW_BOT_OFFSET) / SHADOW_CONTENT.size.y
	_shadow.scale = Vector2(sx, sy)
	var floor_local_y := _shadow_floor_y - global_position.y + SHADOW_Y_NUDGE
	_shadow.position = Vector2(-left, floor_local_y - SHADOW_TOP_OFFSET)
	_shadow.modulate.a = lerpf(0.68, 0.05, t)

# ── Bengala de luz ───────────────────────────────────────────────────────────

func _create_bengala() -> void:
	_bengala = Node2D.new()
	_bengala.position = Vector2(0, -40)
	_bengala.z_index = -1
	add_child(_bengala)

	var light := PointLight2D.new()
	light.color = Color(0.1, 1.0, 0.2)
	light.energy = 1.5
	light.texture = _radial_texture(256, Color(1.0, 1.0, 1.0))
	light.texture_scale = 5.0
	_bengala.add_child(light)

func _radial_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for x in range(size):
		for y in range(size):
			var d := Vector2(x, y).distance_to(Vector2(c, c)) / c
			img.set_pixel(x, y, Color(color.r, color.g, color.b, maxf(0.0, 1.0 - d)))
	return ImageTexture.create_from_image(img)

# ── Detección de puertas ──────────────────────────────────────────────────────

func _separate_from_enemies(_delta: float) -> void:
	if not is_on_floor(): return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var e := enemy as Node2D
		if not e: continue
		# Cops-obstáculo de la línea del medio: se resuelven con slide/air-kick
		# o bloquean como un colectivo (ver collision_mask en _update_collision),
		# nunca con este empuje — si no, esto frena/rebota al jugador contra un
		# enemigo parado sin usar ningún collider (la "pared invisible").
		if e.get("obstacle_mode") == true: continue
		var col := e.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col and col.disabled: continue
		var dx: float = global_position.x - e.global_position.x
		var overlap: float = ENEMY_TOUCH_DIST - abs(dx)
		if overlap > 0.0:
			var push: float = sign(dx) if abs(dx) > 0.5 else 1.0
			global_position.x += push * overlap * 0.75
			if state == State.SLIDE:
				velocity.x        = 0.0
				slide_hold_timer  = SLIDE_HOLD_DUR
				slide_frame_index = SLIDE_END_FRAME
			else:
				velocity.x = push * absf(velocity.x + 20.0)

func _floor_nearby(dist: float) -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0.0, dist))
	params.collision_mask = collision_mask
	params.exclude        = [get_rid()]
	return not space.intersect_ray(params).is_empty()

func _is_on_aerial_car() -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider: CollisionObject2D = col.get_collider() as CollisionObject2D
		if collider and collider.collision_layer == 8:
			return true
	return false

func _is_under_aerial_car() -> bool:
	for node in get_tree().get_nodes_in_group("car_obstacle"):
		var body: CollisionObject2D = node as CollisionObject2D
		if not body or body.collision_layer != 8:
			continue
		var dx: float = abs((body as Node2D).global_position.x - global_position.x)
		if dx < 200.0:
			return true
	return false

func _update_aerial_shadow(delta: float) -> void:
	var under := _is_under_aerial_car()
	_under_car_t = move_toward(_under_car_t, 1.0 if under else 0.0, delta * 5.0)
	self_modulate = Color.WHITE.lerp(Color(0.38, 0.34, 0.42), _under_car_t)

func _try_open_door() -> void:
	for door in get_tree().get_nodes_in_group("door"):
		var d := door as Node2D
		if not d: continue
		var dx: float = d.global_position.x - global_position.x
		var dy: float = abs(d.global_position.y - global_position.y)
		if abs(dx) < 52.0 and dy < 60.0 and (dx > 0.0) == facing_right:
			d.call("open_door")
			break
