extends CharacterBody2D

const GRAVITY        := 850.0
const MAX_HP         := 5
const MOVE_SPEED     := 45.0
const DETECT_RANGE   := 380.0
const CLOSE_RANGE    := 230.0
const ATTACK_RANGE   := 260.0
const KICK_RANGE     := 85.0
const ATTACK_CDN     := 0.10
const HURT_KNOCKBACK := 220.0
const KNOCKBACK_DEC  := 480.0

# Daño que el boss le hace al jugador
const ATTACK_DMG        := 1
const ATTACK_HIT_FRAME  := 20    # frame del machetazo donde impacta
const ATTACK_HIT_RANGE  := 280.0 # alcance del golpe (machetes largos)
const KICK_DMG          := 1
const KICK_HIT_FRAME    := 30
const KICK_HIT_RANGE    := 120.0
const PLAYER_KNOCKBACK  := 0.0    # el machetazo no empuja
const KICK_KNOCKBACK    := 220.0  # la patada empuja (~46px de distancia)

# Cuantos golpes seguidos de cerca aguanta antes de responder con patada
const CLOSE_HITS_FOR_KICK := 1

# Burst walk: camina UN ciclo completo de frames, pausa WALK_PAUSE segundos, repite
const WALK_PAUSE := 2.0

const IDLE_FPS            := 24.0
const IDLE_FRAMES         := 73
const IDLE2_FRAMES        := 73
const IDLE_TO_WALK_FPS    := 24.0
const IDLE_TO_WALK_FRAMES := 29
const WALK_FPS            := 24.0
const WALK_FRAMES         := 90
const ATTACK_FPS          := 90.0
const ATTACK_FRAMES       := 56
const KICK_FPS            := 60.0
const KICK_FRAMES         := 73
const HURT_FPS            := 80.0
const HURT_FRAMES         := 43
const DEATH_FPS           := 15.0
const DEATH_FRAMES        := 73

enum State { IDLE, APPROACH, ATTACK, KICK, HURT, DEAD }

var state        := State.IDLE
var facing_right := true
var hp           := MAX_HP

var attack_timer    := 0.0
var walk_frame      := 0.0
var knockback_x     := 0.0
var burst_timer     := 0.0
var burst_walking   := false
var walk_cycle_done := false
var hit_landed      := false
var close_hits      := 0
var player: CharacterBody2D = null

var hp_bar_node:   Node2D = null
var hp_bar_blocks: Array  = []

@onready var sprite:    AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 4
	collision_mask  = 1
	add_to_group("enemy")
	_load_sprites()
	_build_hp_bar()
	call_deferred("_find_player")
	sprite.animation_finished.connect(_on_animation_finished)

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
	for i in range(1, KICK_FRAMES + 1):
		var tex := load("%s/kick/kick_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("kick", tex)

	frames.add_animation("hurt")
	frames.set_animation_loop("hurt", false)
	frames.set_animation_speed("hurt", HURT_FPS)
	for i in range(1, HURT_FRAMES + 1):
		var tex := load("%s/hurt/hurt_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("hurt", tex)

	frames.add_animation("death")
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", DEATH_FPS)
	for i in range(1, DEATH_FRAMES + 1):
		var tex := load("%s/death/death_%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: frames.add_frame("death", tex)

	sprite.sprite_frames = frames
	sprite.position = Vector2(0, -72)
	sprite.play("idle")

func _build_hp_bar() -> void:
	var bar  := Node2D.new()
	bar.position = Vector2(0, -210)
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
		_shove_off_corpse(delta)
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if attack_timer > 0.0: attack_timer -= delta

	# El boss siempre mira al jugador
	if player and state != State.DEAD:
		facing_right = player.global_position.x > global_position.x

	match state:
		State.IDLE:     _do_idle(delta)
		State.APPROACH: _do_approach(delta)
		State.ATTACK:   _do_attack_state(delta)
		State.KICK:     _do_kick_state(delta)
		State.HURT:     _do_hurt(delta)

	sprite.flip_h = facing_right
	_update_anim(delta)
	move_and_slide()

func _update_anim(delta: float) -> void:
	if state == State.ATTACK or state == State.KICK or state == State.HURT or state == State.DEAD:
		return

	# La animacion de walk se dispara por burst_walking, no por velocidad.
	# Asi el movimiento fisico y la animacion arrancan y paran exactamente juntos.
	var walking: bool = state == State.APPROACH and burst_walking

	if walking:
		if sprite.animation != "walk":
			sprite.animation = "walk"
			sprite.speed_scale = 0.0
		var prev := walk_frame
		walk_frame = fposmod(walk_frame + WALK_FPS * delta, float(WALK_FRAMES))
		if walk_frame < prev:
			walk_cycle_done = true
		sprite.set_frame_and_progress(floori(walk_frame), 0.0)
	else:
		if sprite.animation != "idle":
			sprite.play("idle")

func _player_dist() -> float:
	if not player: return INF
	return abs(player.global_position.x - global_position.x)

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

func _hit_player(hit_range: float, dmg: int, knockback: float) -> void:
	if not player: return
	if _player_dist() > hit_range: return
	if not player.has_method("take_damage"): return
	var from_right := player.global_position.x > global_position.x
	player.call("take_damage", dmg, from_right, knockback)

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
			attack_timer = ATTACK_CDN
			state = State.APPROACH
		State.KICK:
			# Despues de la patada va directo a pegar, sin pasar por idle
			attack_timer = ATTACK_CDN
			hit_landed = false
			sprite.speed_scale = 1.0
			state = State.ATTACK
			sprite.play("attack")
		State.HURT:
			# Despues del hurt siempre contraataca directo, sin pasar por idle.
			# Si lo estan golpeando seguido de cerca, tira patada para alejar.
			attack_timer = ATTACK_CDN
			hit_landed = false
			sprite.speed_scale = 1.0
			if close_hits >= CLOSE_HITS_FOR_KICK:
				close_hits = 0
				state = State.KICK
				sprite.play("kick")
			else:
				state = State.ATTACK
				sprite.play("attack")

func take_damage(amount: int, from_right: bool, _kb: float = -1.0) -> void:
	if state == State.DEAD: return
	# Durante la patada el boss es invulnerable: no pierde vida ni va a hurt
	if state == State.KICK:
		return
	hp -= amount
	_refresh_hp_bar()
	if hp <= 0:
		_die()
		return
	# Contar golpes recibidos de cerca para responder con patada
	if _player_dist() <= KICK_HIT_RANGE:
		close_hits += 1
	else:
		close_hits = 0
	state = State.HURT
	knockback_x = HURT_KNOCKBACK * (-1.0 if from_right else 1.0)
	sprite.speed_scale = 1.0
	sprite.play("hurt")

func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	# El cuerpo muerto queda como obstaculo solido: el jugador tiene que saltarlo.
	# Se saca del grupo enemy (para que no aplique el empuje suave) y se pasa a la
	# capa 1 para que el jugador (mask 1) choque con el.
	remove_from_group("enemy")
	collision_layer = 1
	# Reemplazar la capsula alta por un obstaculo bajo apoyado en el piso
	var corpse := RectangleShape2D.new()
	corpse.size = Vector2(170.0, 44.0)
	collision.shape    = corpse
	# Corrido a la izquierda: borde der en +75 (igual), borde izq en -95 (mas a la izq)
	collision.position = Vector2(-10.0, 45.0 - 22.0)  # base alineada con los pies
	sprite.speed_scale = 1.0
	sprite.play("death")

# Si el jugador queda parado encima del cadaver, lo desliza hacia el costado
# mas cercano para que se caiga (no se puede quedar arriba).
func _shove_off_corpse(delta: float) -> void:
	if not player: return
	var half_w := 85.0
	var cx     := global_position.x + collision.position.x
	var box_top := global_position.y + collision.position.y - 22.0
	var px      := player.global_position.x
	var feet_y  := player.global_position.y + 34.0
	# ¿esta apoyado encima del cadaver?
	if absf(px - cx) < half_w and feet_y <= box_top + 8.0 and feet_y >= box_top - 12.0:
		var dir := 1.0 if px >= cx else -1.0
		player.global_position.x += dir * 300.0 * delta
