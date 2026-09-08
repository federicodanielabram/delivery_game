extends CharacterBody2D

const GRAVITY        := 850.0
const MAX_HP         := 5
const MOVE_SPEED     := 45.0
# Velocidad de la caminata de entrada (ver State.INTRO_WALK) — propia y
# separada de MOVE_SPEED (que hoy no se usa para nada más) para poder
# ajustarla sin tocar otro comportamiento. En 45 tardaba ~8.5s en cruzar la
# distancia típica hasta _arena_center — sin diálogo puesto todavía, se sentía
# muerto. Al doble es ~4.3s; reajustar cuando el diálogo real esté puesto.
const INTRO_WALK_SPEED := 90.0
const DETECT_RANGE   := 380.0
const CLOSE_RANGE    := 230.0
const ATTACK_RANGE   := 260.0
const KICK_RANGE     := 85.0
const ATTACK_CDN     := 0.35   # antes 0.10 — con eso, encadenaba machetazo tras
	# machetazo con apenas 100ms de aire entre uno y otro (sumado a la animación,
	# ciclo de ~0.72s). Ahora hay un hueco real después de cada swing: ~1.1s de
	# ciclo total, tiempo real para que el jugador entre a pegar sin miedo.
# Hueco en idle específicamente entre un machetazo y el siguiente (cuando el PP
# no fue a combear en el hueco de arriba): 1.1s, más largo que ATTACK_CDN — así
# el ciclo "espera → machetazo → hueco corto real → ¿no viniste? esperá 1.1s
# más → machetazo de nuevo" se puede leer y aprender.
const ATTACK_REPEAT_DELAY := 1.1
const HURT_KNOCKBACK := 0.0   # el boss no se mueve al recibir un golpe, queda en el lugar
const KNOCKBACK_DEC  := 480.0

# Mientras el PP lo está combeando a buen ritmo (jab/hook/patada voladora
# seguidos), el boss se queda quieto en idle en vez de tirar su propio
# machetazo/patada por su cuenta — recién si el PP deja de pegar a ritmo de
# combo (este tiempo sin recibir ningún golpe), el boss retoma su propio
# ataque. NO alcanza con COMBO_WINDOW (0.50s, player.gd): jab→hook conecta
# casi al instante, pero hook→patada voladora tiene un hueco real más largo
# (la patada voladora recién pega en su frame de impacto, FLYING_KICK_IMPACT/
# FLYING_KICK_FPS = 0.33s después de arrancar, sumado a la espera del hook) —
# en el peor caso (mashing al límite de la ventana) da ~0.83s entre esos dos
# golpes. 1.0s cubre eso con margen sin dejarlo pasivo de más.
const HIT_RECENTLY_WINDOW := 1.0

# ── DEBUG: el boss no le saca vida al jugador ─────────────────────────────────
# Con esto en true se puede probar la pelea (timing, empuje, animaciones) sin
# morir. Volver a false para el flujo normal.
const DEBUG_NO_DAMAGE_TO_PLAYER := true

# Daño que el boss le hace al jugador
const ATTACK_DMG        := 1
const ATTACK_HIT_FRAME  := 20    # frame del machetazo donde impacta
const ATTACK_HIT_RANGE  := 280.0 # alcance del golpe (machetes largos)
const KICK_DMG          := 1
# El ciclo de kick jugado va de kick_021 a kick_052 (índice 0 de la animación
# = kick_021). KICK_HIT_FRAME sigue apuntando al mismo frame visual de antes
# (kick_031, pierna extendida) — reescalado al nuevo índice: 31 - 21 = 10.
const KICK_START_FRAME  := 21
const KICK_END_FRAME    := 52
const KICK_HIT_FRAME    := 10
const KICK_HIT_RANGE    := 120.0
const PLAYER_KNOCKBACK  := 0.0    # el machetazo no empuja
const KICK_KNOCKBACK    := 660.0  # 3x el valor base (220) — resetea la distancia tras el remate del combo

# Burst walk: camina UN ciclo completo de frames, pausa WALK_PAUSE segundos, repite
const WALK_PAUSE := 2.0

const IDLE_FPS            := 24.0
const IDLE_FRAMES         := 73
const IDLE2_FRAMES        := 73
const IDLE_TO_WALK_FPS    := 24.0
const IDLE_TO_WALK_FRAMES := 29
const WALK_FPS            := 24.0
const WALK_FRAMES         := 90
# El ciclo de walk en loop arranca en walk_003 (se descartan walk_001 y
# walk_002) y sigue hasta walk_090, volviendo a walk_003 — no al frame 0.
const WALK_SKIP_START     := 2
# Dentro de ese loop, walk_001→walk_010 (0-indexed 0..9, incluye los 2 frames
# ya descartados) es un "cambio de peso" que no corresponde a avanzar — recién
# desde walk_011 (índice 10, 0-indexed) el ciclo mueve al personaje de verdad.
# Ver _do_intro_walk: mientras walk_frame < WALK_MOVE_START, el hitbox se
# queda quieto aunque la animación siga corriendo.
const WALK_MOVE_START     := 10
# Frames que sí avanzan por ciclo (WALK_FRAMES - WALK_MOVE_START) y cuánto
# avanza el hitbox en ese tramo. INTRO_WALK_SPEED no entra en la cuenta porque
# se cancela con el escalado de fps de _update_anim (ver ese comentario) — da
# lo mismo a la velocidad de intro que a MOVE_SPEED. = 80 * 45 / 24 = 150px.
const WALK_MOVE_FRAMES        := WALK_FRAMES - WALK_MOVE_START
const WALK_ADVANCE_PER_CYCLE_PX := WALK_MOVE_FRAMES * MOVE_SPEED / WALK_FPS
const ATTACK_FPS          := 97.5  # PRUEBA: 30% más rápido (antes 75) — el swing
	# completo pasa de 0.75s a 0.57s, y el hit (frame 20) llega a los 0.21s en
	# vez de 0.27s. Volver a 75 si se siente demasiado repentino para leer.
const ATTACK_FRAMES       := 56
const KICK_FPS            := 60.0
const KICK_FRAMES         := 73
const HURT_FPS            := 80.0
const HURT_FRAMES         := 43
# El ciclo de hurt jugado va de hurt_002 a hurt_037 (se descartan el primero y
# los últimos 6 archivos de la carpeta) — arranca en 2 y termina en 37.
const HURT_START_FRAME    := 2
const HURT_END_FRAME      := 37
const DEATH_FPS           := 15.0
const DEATH_FRAMES        := 73

# INTRO_WALK: entrada escrita de la pelea (ver level1.gd _start_boss_intro) —
# el boss camina desde donde aparece hasta el centro de la arena en vez de
# aparecer ya parado ahí. No es parte de la IA de combate normal: level1.gd lo
# dispara con start_intro_walk() y lo suelta a IDLE recién con begin_combat().
enum State { IDLE, APPROACH, ATTACK, KICK, HURT, DEAD, INTRO_WALK }

var state        := State.IDLE
var facing_right := true
var hp           := MAX_HP

var _intro_walk_target_x := 0.0
var intro_walk_done      := false   # level1.gd hace polling de esto

var attack_timer    := 0.0
var _hit_recently_timer := 0.0
var walk_frame      := float(WALK_SKIP_START)   # arranca en walk_003
var knockback_x     := 0.0
var burst_timer     := 0.0
var burst_walking   := false
var walk_cycle_done := false
var _intro_walk_cycles_done := 0   # ciclos de walk completos durante la caminata de entrada
var hit_landed      := false
var player: CharacterBody2D = null

var hp_bar_node:   Node2D = null
var hp_bar_blocks: Array  = []
var _shadow: Sprite2D = null

@onready var sprite:    AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 4
	collision_mask  = 1
	# Por debajo del PP (z_index 3, hasta 5 sobre auto aéreo) a propósito: los
	# golpes del combo se tienen que ver adelante del boss, no detrás, y lo
	# mismo su animación de muerte.
	z_index = 2
	add_to_group("enemy")
	_load_sprites()
	_build_hp_bar()
	_create_shadow()
	call_deferred("_find_player")
	sprite.animation_finished.connect(_on_animation_finished)

# Misma mancha plana que usan el cop, los autos aéreos y el PP (ver
# cop.gd _create_shadow) — reutilizamos la técnica y la textura tal cual,
# solo escalando las medidas por la diferencia de tamaño real entre los dos
# sprites: el del boss es un canvas 400px sin escalar, el del cop es 256px a
# escala 1.1 (=281.6px) → el boss es ~1.42x más grande visualmente (NO uses
# la cápsula de colisión para esta cuenta — se agrandó mucho más allá del
# sprite a propósito, ver comentario de BOSS_CAPSULE_H en level1.gd).
# Son valores de arranque escalados, no medidos a ojo sobre el boss como sí
# se hizo con el cop — van a necesitar el mismo ajuste fino en vivo
# (instrucción en px) una vez que se vea renderizado.
const SHADOW_TEX_PATH   := "res://assets/sprites/cars/side_test/car_side_06 - copia.png"
const SHADOW_TEX_W      := 1424.0
const SHADOW_TEX_H      := 642.0
const SHADOW_SCALE      := 0.142
# Ajustes pedidos, acumulados: +10px izq/+30px der, después +5px izq/+30px der
# más — cada vez, además de agrandar (TRIM, puede ir negativo si el ancho ya
# superó SHADOW_SCALE de base) el centro se corre a la derecha la mitad de la
# diferencia entre ambos lados.
const SHADOW_WIDTH_TRIM := -27.0
# Ajustes pedidos, acumulados: subir 40px, bajar 10px, bajar 8px más.
const SHADOW_TOP_Y      := -180.0
const SHADOW_BOTTOM_Y   := 60.0
const SHADOW_X_OFFSET   := 12.5
const SHADOW_ALPHA      := 0.68

func _create_shadow() -> void:
	_shadow = Sprite2D.new()
	_shadow.z_index  = -1
	_shadow.centered = false
	_shadow.texture  = load(SHADOW_TEX_PATH)
	var sx := SHADOW_SCALE - SHADOW_WIDTH_TRIM / SHADOW_TEX_W
	var sy := (SHADOW_BOTTOM_Y - SHADOW_TOP_Y) / SHADOW_TEX_H
	_shadow.scale      = Vector2(sx, sy)
	_shadow.position   = Vector2(-SHADOW_TEX_W * sx * 0.5 + SHADOW_X_OFFSET, SHADOW_TOP_Y)
	_shadow.modulate.a = SHADOW_ALPHA
	add_child(_shadow)
	move_child(_shadow, 0)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

func _load_sprites() -> void:
	var base   := "res://assets/sprites/enemies/boss"
	var frames := SpriteFrames.new()

	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", IDLE_FPS)
	for _rep in 2:
		for i in range(1, IDLE_FRAMES + 1):
			var tex := load("%s/idle/idle_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
			if tex: frames.add_frame("idle", tex)
	for i in range(1, IDLE2_FRAMES + 1):
		var tex := load("%s/idle2/idle2_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("idle", tex)

	frames.add_animation("idle_to_walk")
	frames.set_animation_loop("idle_to_walk", false)
	frames.set_animation_speed("idle_to_walk", IDLE_TO_WALK_FPS)
	for i in range(1, IDLE_TO_WALK_FRAMES + 1):
		var tex := load("%s/idle_to_walk/idle_to_walk_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("idle_to_walk", tex)

	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", WALK_FPS)
	for i in range(1, WALK_FRAMES + 1):
		var tex := load("%s/walk/walk_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("walk", tex)

	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", ATTACK_FPS)
	for i in range(1, ATTACK_FRAMES + 1):
		var tex := load("%s/attack/attack_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("attack", tex)

	frames.add_animation("kick")
	frames.set_animation_loop("kick", false)
	frames.set_animation_speed("kick", KICK_FPS)
	for i in range(KICK_START_FRAME, KICK_END_FRAME + 1):
		var tex := load("%s/kick/kick_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("kick", tex)

	frames.add_animation("hurt")
	frames.set_animation_loop("hurt", false)
	frames.set_animation_speed("hurt", HURT_FPS)
	for i in range(HURT_START_FRAME, HURT_END_FRAME + 1):
		var tex := load("%s/hurt/hurt_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("hurt", tex)

	frames.add_animation("death")
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", DEATH_FPS)
	for i in range(1, DEATH_FRAMES + 1):
		var tex := load("%s/death/death_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("death", tex)

	sprite.sprite_frames = frames
	# El pie dibujado (píxel opaco más bajo del PNG) NO coincide con el borde de
	# abajo de la propia cápsula de colisión del boss — el arte trae relleno
	# transparente asimétrico. Medido sobre los PNG reales (idle/walk/kick/
	# attack/hurt, todos consistentes): canvas 400x400, AnimatedSprite2D
	# centrado en el origen del nodo (ocupa de -200 a +200 en y local), pie
	# real (fila opaca más baja) ≈ fila 391 → y local +192.
	# La cápsula (CapsuleShape2D.height=90) tiene su borde de abajo en y local
	# +45. Para que el pie dibujado quede EXACTO ahí:
	#   offset = borde_abajo_capsula - pie_real = 45 - 192 = -147
	# Ajuste manual pedido después: bajar la IMAGEN (y todo lo que va pegado a
	# ella — sprite + barra de vida) 10px respecto al hitbox, que no se toca.
	# -147 + 10 = -137.
	sprite.position = Vector2(0, -137)
	sprite.play("idle")

func _build_hp_bar() -> void:
	var bar  := Node2D.new()
	# Va pegada a la cabeza del sprite, así que baja los mismos 10px que él:
	# -285 + 10 = -275.
	bar.position = Vector2(0, -275)
	bar.visible  = false
	var bw    := 6.0
	var gap   := 2.0
	var total := MAX_HP * bw + (MAX_HP - 1) * gap
	for i in MAX_HP:
		var b := ColorRect.new()
		b.size     = Vector2(bw, 4.0)
		b.position = Vector2(-total / 2.0 + i * (bw + gap), 0.0)
		b.color    = Color(1.0, 0.15, 0.15)
		bar.add_child(b)
		hp_bar_blocks.append(b)
	hp_bar_node = bar
	add_child(bar)

func _refresh_hp_bar() -> void:
	if not hp_bar_node: return
	hp_bar_node.visible = true
	for i in hp_bar_blocks.size():
		(hp_bar_blocks[i] as ColorRect).color = \
			Color(1.0, 0.15, 0.15) if i < hp else Color(0.06, 0.06, 0.14)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if attack_timer > 0.0: attack_timer -= delta
	if _hit_recently_timer > 0.0: _hit_recently_timer -= delta

	# El boss siempre mira al jugador
	if player and state != State.DEAD:
		facing_right = player.global_position.x > global_position.x

	match state:
		State.IDLE:       _do_idle(delta)
		State.APPROACH:   _do_approach(delta)
		State.ATTACK:     _do_attack_state(delta)
		State.KICK:       _do_kick_state(delta)
		State.HURT:       _do_hurt(delta)
		State.INTRO_WALK: _do_intro_walk(delta)

	sprite.flip_h = facing_right
	_update_anim(delta)
	move_and_slide()

func _update_anim(delta: float) -> void:
	if state == State.ATTACK or state == State.KICK or state == State.HURT or state == State.DEAD:
		return

	# La animacion de walk se dispara por burst_walking, no por velocidad.
	# Asi el movimiento fisico y la animacion arrancan y paran exactamente juntos.
	# "and not intro_walk_done": sin esto, la animación seguía de largo (y
	# arrancaba a mostrar un tercer ciclo) durante la pausa entre terminar de
	# caminar y begin_combat(), aunque el hitbox ya estuviera clavado quieto.
	var walking: bool = (state == State.APPROACH and burst_walking) \
			or (state == State.INTRO_WALK and not intro_walk_done)

	if walking:
		if sprite.animation != "walk":
			sprite.animation = "walk"
			sprite.speed_scale = 0.0
		# WALK_FPS está calibrado para MOVE_SPEED (45px/s) — la intro camina más
		# rápido (INTRO_WALK_SPEED), así que el ciclo de animación escala en la
		# misma proporción para que los pies no patinen contra el piso.
		var fps: float = (WALK_FPS * INTRO_WALK_SPEED / MOVE_SPEED) if state == State.INTRO_WALK else WALK_FPS
		var prev := walk_frame
		walk_frame = WALK_SKIP_START + fposmod(walk_frame - WALK_SKIP_START + fps * delta, float(WALK_FRAMES - WALK_SKIP_START))
		if walk_frame < prev:
			walk_cycle_done = true
			if state == State.INTRO_WALK:
				_intro_walk_cycles_done += 1
		sprite.set_frame_and_progress(floori(walk_frame), 0.0)
	else:
		if sprite.animation != "idle":
			sprite.play("idle")

func _player_dist() -> float:
	if not player: return INF
	return abs(player.global_position.x - global_position.x)

# Usado por level1.gd para calcular desde dónde arrancar la caminata de
# entrada (ver _start_boss_intro) en términos del propio ciclo de animación
# en vez de un % de pantalla arbitrario.
func get_walk_advance_per_cycle_px() -> float:
	return WALK_ADVANCE_PER_CYCLE_PX

# Ver comentario junto al enum State. target_x es el centro de la arena (lo
# calcula level1.gd) — MOVE_SPEED (45px/s, la mitad que un mozo) le da el
# "caminando despacio" pedido. Al llegar se frena y avisa con intro_walk_done;
# se queda plantado ahí (sin pasar a IDLE solo) hasta que level1.gd llame a
# begin_combat() — así no le agarra ganas de acercarse o atacar mientras el
# jugador todavía está en cutscene_lock.
func start_intro_walk(target_x: float) -> void:
	_intro_walk_target_x    = target_x
	intro_walk_done         = false
	_intro_walk_cycles_done = 0
	state                   = State.INTRO_WALK

# La llegada se decide por CICLOS DE WALK completos (2, ver level1.gd —
# _start_boss_intro posiciona al boss a exactamente 2 ciclos de distancia del
# centro), no por distancia restante: medir por distancia dejaba un resto
# mínimo de error de física sin cubrir al terminar el ciclo 2, y eso obligaba
# a arrancar unos pocos frames de un tercer ciclo para cerrarlo. Contando
# ciclos, al llegar a 2 se frena y se clava exacto en el target sin arrastrar
# ese error.
func _do_intro_walk(_delta: float) -> void:
	if _intro_walk_cycles_done >= 2:
		velocity.x = 0.0
		if not intro_walk_done:
			global_position.x = _intro_walk_target_x
			intro_walk_done    = true
		return
	# walk_001→walk_010 es cambio de peso, no zancada: el hitbox se queda
	# quieto en ese tramo de cada ciclo aunque la animación siga avanzando.
	# Recién de walk_011 en adelante (WALK_MOVE_START) avanza de verdad.
	if walk_frame < WALK_MOVE_START:
		velocity.x = 0.0
		return
	velocity.x = signf(_intro_walk_target_x - global_position.x) * INTRO_WALK_SPEED

func begin_combat() -> void:
	state = State.IDLE

func _do_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	if player and _player_dist() <= DETECT_RANGE:
		state = State.APPROACH

func _do_approach(_delta: float) -> void:
	if not player:
		state = State.IDLE
		return

	# El boss se queda fijo en su lugar
	velocity.x = 0.0

	var dist := _player_dist()

	if dist > DETECT_RANGE:
		state = State.IDLE
		return

	# El PP lo está combeando a ritmo (jab/hook/patada voladora seguidos): se
	# queda quieto en vez de tirar su propio golpe, hasta que deje de pegarle.
	if _hit_recently_timer > 0.0:
		return

	if dist <= KICK_RANGE and attack_timer <= 0.0:
		state = State.KICK
		attack_timer = ATTACK_CDN
		hit_landed = false
		sprite.speed_scale = 1.0
		sprite.play("kick")
		return

	if dist <= ATTACK_RANGE and attack_timer <= 0.0:
		state = State.ATTACK
		attack_timer = ATTACK_CDN
		hit_landed = false
		sprite.speed_scale = 1.0
		sprite.play("attack")
		return

# Si el PP está saltando lo bastante alto por encima del piso del boss, el
# golpe cuerpo a cuerpo (machete o patada, ambos pasan por acá) no lo
# alcanza — "saltarlo por arriba" esquiva de verdad, no es solo un atajo
# visual. Y crece hacia ABAJO en Godot, así que el PP saltando tiene un
# global_position.y MENOR que el del boss (parado, siempre al mismo nivel de
# piso) — la resta da la altura real por encima del piso.
const AIRBORNE_DODGE_HEIGHT := 50.0

func _hit_player(hit_range: float, dmg: int, knockback: float) -> void:
	if not player: return
	if _player_dist() > hit_range: return
	if global_position.y - player.global_position.y > AIRBORNE_DODGE_HEIGHT: return
	if not player.has_method("take_damage"): return
	var from_right := player.global_position.x > global_position.x
	var real_dmg := 0 if DEBUG_NO_DAMAGE_TO_PLAYER else dmg
	player.call("take_damage", real_dmg, from_right, knockback)

func _do_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	if not hit_landed and sprite.frame >= ATTACK_HIT_FRAME:
		hit_landed = true
		_hit_player(ATTACK_HIT_RANGE, ATTACK_DMG, PLAYER_KNOCKBACK)

func _do_kick_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	if not hit_landed and sprite.frame >= KICK_HIT_FRAME:
		hit_landed = true
		_hit_player(KICK_HIT_RANGE, KICK_DMG, KICK_KNOCKBACK)

func _do_hurt(delta: float) -> void:
	knockback_x = move_toward(knockback_x, 0.0, KNOCKBACK_DEC * delta)
	velocity.x = knockback_x

func _on_animation_finished() -> void:
	match state:
		State.ATTACK:
			attack_timer = ATTACK_REPEAT_DELAY
			state = State.APPROACH
		State.KICK:
			# Vuelve a idle (APPROACH) en vez de ir directo a pegar — el
			# machetazo recién se dispara de nuevo cuando el PP se acerca lo
			# suficiente (dist <= ATTACK_RANGE, ver _do_approach). El empuje
			# de la patada (KICK_KNOCKBACK) ya genera esa distancia real.
			attack_timer = ATTACK_CDN
			state = State.APPROACH
		State.HURT:
			# HURT solo se entra vía react_to_finisher (remate del combo del
			# PP) — así que siempre corresponde el castigo real: contraataca
			# directo con la patada, sin pasar por idle ni por la recuperación
			# que había antes.
			hit_landed    = false
			sprite.speed_scale = 1.0
			attack_timer  = ATTACK_CDN
			state         = State.KICK
			sprite.play("kick")

# Golpe genérico (jab/hook, run punch, slide, air kick): NO resta vida ni
# interrumpe al boss ni lo hace reaccionar — la vida es "una barrita por
# combo", así que solo react_to_finisher (el remate) la baja. Sí sirve para
# marcar que lo están combeando (_hit_recently_timer) y respeta la
# invulnerabilidad durante machetazo/patada.
func take_damage(_amount: int, from_right: bool, _kb: float = -1.0) -> void:
	if state == State.DEAD or state == State.KICK or state == State.ATTACK: return
	_hit_recently_timer = HIT_RECENTLY_WINDOW

# Reacción específica al remate del combo de piso del PP (jab→hook→patada
# voladora, el tercer golpe) — la ÚNICA fuente de daño real: resta 1 barrita
# de vida siempre (sin importar cuánto "amount" haya pasado la patada
# voladora en take_damage), e interrumpe al boss con la animación de dolor y,
# apenas termina, el contragolpe de patada instantáneo (ver
# _on_animation_finished, caso HURT). Se llama además de (no en vez de)
# take_damage — ver _notify_finisher_hit en player.gd.
func react_to_finisher() -> void:
	if state == State.DEAD or state == State.KICK or state == State.ATTACK: return
	hp -= 1
	_refresh_hp_bar()
	if hp <= 0:
		_die()
		return
	state = State.HURT
	knockback_x = 0.0   # HURT_KNOCKBACK ya está en 0
	sprite.speed_scale = 1.0
	sprite.play("hurt")

func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	if _shadow: _shadow.visible = false
	# El cuerpo muerto no bloquea nada: sin hitbox, el jugador lo atraviesa
	# como si no estuviera (antes quedaba como obstáculo sólido que había que
	# saltar).
	remove_from_group("enemy")
	collision.disabled = true
	sprite.speed_scale = 1.0
	sprite.play("death")
