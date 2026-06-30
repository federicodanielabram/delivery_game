extends CharacterBody2D

# ── Física ───────────────────────────────────────────────────────────────────
const MAX_SPEED    := 90.0
const ACCELERATION := 500.0
const FRICTION     := 600.0
const JUMP_FORCE   := -290.0
const GRAVITY      := 750.0
const ROLL_SPEED   := 160.0
const ROLL_DIST    := 48.0
const ROLL_PAUSE   := 0.35

# ── Combate ──────────────────────────────────────────────────────────────────
const COMBO_WINDOW  := 0.50
const MAX_HP        := 5
const IFRAME_DUR    := 1.0    # segundos de invulnerabilidad tras recibir golpe
const HIT_RANGE_X   := 44.0   # alcance horizontal del golpe
const HIT_RANGE_Y   := 52.0   # tolerancia vertical

enum State      { IDLE, WALK, JUMP, FALL, CROUCH, ROLL, ATTACKING, AIR_ATTACKING, CROUCH_ATTACKING }
enum AttackType { JAB, HOOK, UPPERCUT, SWEEP, KICK, CROUCH_KICK, AIR_PUNCH, AIR_DOWN_KICK }

var state          := State.IDLE
var facing_right   := true
var roll_remaining       := 0.0
var roll_dir             := 1.0
var crouch_roll_cooldown := 0.0

var current_attack := AttackType.JAB
var combo_step     := 0
var attack_timer   := 0.0
var combo_timer    := 0.0
var attack_queued  := false

var hp             := MAX_HP
var iframe_timer   := 0.0
var knockback_vel  := 0.0     # velocidad horizontal de empuje al recibir daño

@onready var sprite:    Sprite2D         = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var tex_idle:   Texture2D
var tex_walk:   Texture2D
var tex_jump:   Texture2D
var tex_crouch: Texture2D
var tex_attack: Texture2D

func _ready() -> void:
	add_to_group("player")
	tex_idle   = load("res://assets/sprites/player/player_idle.png")
	tex_walk   = load("res://assets/sprites/player/player_walk.png")
	tex_jump   = load("res://assets/sprites/player/player_jump.png")
	tex_crouch = load("res://assets/sprites/player/player_crouch.png")
	tex_attack = load("res://assets/sprites/player/player_punch.png")
	sprite.texture = tex_idle

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_tick_timers(delta)
	match state:
		State.IDLE, State.WALK:  _handle_ground(delta)
		State.CROUCH:            _handle_crouch(delta)
		State.ROLL:              _handle_roll(delta)
		State.JUMP, State.FALL:  _handle_air(delta)
		State.ATTACKING:         _handle_attacking(delta)
		State.AIR_ATTACKING:     _handle_air_attacking(delta)
		State.CROUCH_ATTACKING:  _handle_crouch_attacking(delta)
	_update_collision()
	_update_sprite()
	# Aplicar y decaer knockback del jugador
	velocity.x += knockback_vel
	knockback_vel = move_toward(knockback_vel, 0.0, 520.0 * delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _tick_timers(delta: float) -> void:
	if iframe_timer > 0.0: iframe_timer -= delta

# ── Daño recibido ─────────────────────────────────────────────────────────────

func take_damage(amount: int, from_right: bool) -> void:
	if iframe_timer > 0.0: return
	hp           -= amount
	iframe_timer  = IFRAME_DUR
	knockback_vel = 200.0 * (1.0 if from_right else -1.0)
	if hp <= 0:
		hp = 0
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_game_over"):
			hud.call("show_game_over")

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

# ── Suelo ────────────────────────────────────────────────────────────────────

func _handle_ground(delta: float) -> void:
	if Input.is_action_pressed("ui_down"):
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

		if Input.is_action_just_pressed("attack"):
			_start_attack(AttackType.SWEEP, 0.30, 0.0)
			_try_hit_enemies(1)
			return

		if Input.is_action_just_pressed("ui_down"):
			var dir := Input.get_axis("ui_left", "ui_right")
			if dir != 0.0:
				_start_roll(dir)
				return

		state = State.CROUCH
		return

	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_FORCE
		state = State.JUMP
		return

	if Input.is_action_just_pressed("attack"):
		combo_step = 0
		_launch_combo()
		return

	if Input.is_action_just_pressed("kick"):
		_start_attack(AttackType.KICK, 0.35, 0.0)
		_try_hit_enemies(1)
		return

	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		facing_right = dir > 0.0
		sprite.flip_h = not facing_right
		velocity.x = move_toward(velocity.x, dir * MAX_SPEED, ACCELERATION * delta)
		state = State.WALK
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		state = State.IDLE

# ── Agachado ─────────────────────────────────────────────────────────────────

func _handle_crouch(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	if not Input.is_action_pressed("ui_down"):
		state = State.IDLE
		crouch_roll_cooldown = 0.0
		return

	if Input.is_action_just_pressed("kick"):
		_start_attack(AttackType.CROUCH_KICK, 0.30, 0.0)
		state = State.CROUCH_ATTACKING
		_try_hit_enemies(1)
		return

	if crouch_roll_cooldown > 0.0:
		crouch_roll_cooldown -= delta
		return

	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		_start_roll(dir)

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
		state                = State.CROUCH

# ── Aire ─────────────────────────────────────────────────────────────────────

func _handle_air(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		facing_right  = dir > 0.0
		sprite.flip_h = not facing_right
		velocity.x = move_toward(velocity.x, dir * MAX_SPEED, ACCELERATION * delta * 0.6)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta * 0.3)

	if Input.is_action_just_pressed("attack"):
		current_attack = AttackType.AIR_PUNCH
		attack_timer   = 0.28
		state          = State.AIR_ATTACKING
		_try_hit_enemies(1)
		return

	if Input.is_action_just_pressed("kick") and Input.is_action_pressed("ui_down"):
		current_attack = AttackType.AIR_DOWN_KICK
		attack_timer   = 0.30
		velocity.y     = 220.0
		state          = State.AIR_ATTACKING
		_try_hit_enemies(2)
		return

	if is_on_floor():
		state = State.IDLE
	elif velocity.y > 0.0:
		state = State.FALL

# ── Sistema de combos ─────────────────────────────────────────────────────────

func _launch_combo() -> void:
	var dmg := 1
	match combo_step:
		0: _start_attack(AttackType.JAB,      0.18, COMBO_WINDOW)
		1: _start_attack(AttackType.HOOK,     0.22, COMBO_WINDOW)
		2:
			_start_attack(AttackType.UPPERCUT, 0.38, 0.0)
			dmg = 2
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
		if attack_queued and combo_timer > 0.0:
			combo_step   += 1
			attack_queued = false
			_launch_combo()
		elif combo_timer <= 0.0:
			combo_step = 0
			state = State.IDLE if is_on_floor() else State.FALL

func _handle_air_attacking(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * MAX_SPEED, ACCELERATION * delta * 0.4)

	attack_timer -= delta
	if attack_timer <= 0.0:
		state = State.IDLE if is_on_floor() else (State.FALL if velocity.y > 0.0 else State.JUMP)

func _handle_crouch_attacking(delta: float) -> void:
	velocity.x   = move_toward(velocity.x, 0.0, FRICTION * delta)
	attack_timer -= delta
	if attack_timer <= 0.0:
		state = State.CROUCH

# ── Colisión y sprite ─────────────────────────────────────────────────────────

func _update_collision() -> void:
	var cap := collision.shape as CapsuleShape2D
	if state in [State.CROUCH, State.ROLL, State.CROUCH_ATTACKING]:
		cap.height           = 38.0
		collision.position.y = 15.0
	else:
		cap.height           = 68.0
		collision.position.y = 0.0

func _update_sprite() -> void:
	match state:
		State.IDLE:
			sprite.texture = tex_idle
		State.WALK:
			sprite.texture = tex_walk
		State.JUMP, State.FALL:
			sprite.texture = tex_jump
		State.CROUCH, State.ROLL:
			sprite.texture = tex_crouch
		State.ATTACKING, State.AIR_ATTACKING:
			sprite.texture = tex_attack
		State.CROUCH_ATTACKING:
			sprite.texture = tex_crouch

	# Parpadeo durante invulnerabilidad
	sprite.modulate.a = 0.35 if (iframe_timer > 0.0 and int(iframe_timer * 10) % 2 == 0) else 1.0

# ── Detección de puertas ──────────────────────────────────────────────────────

func _try_open_door() -> void:
	for door in get_tree().get_nodes_in_group("door"):
		var d := door as Node2D
		if not d: continue
		var dx: float = d.global_position.x - global_position.x
		var dy: float = abs(d.global_position.y - global_position.y)
		if abs(dx) < 52.0 and dy < 60.0 and (dx > 0.0) == facing_right:
			d.call("open_door")
			break
