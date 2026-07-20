extends CharacterBody2D

# ── Stats ──────────────────────────────────────────────────────────────────
const GRAVITY       := 750.0
const MAX_HP        := 3
const MOVE_SPEED    := 38.0
const DETECT_RANGE  := 130.0
const ATTACK_RANGE  := 36.0
const ATTACK_DMG    := 1
const ATTACK_DUR    := 0.40    # duración total del swing
const ATTACK_CDN    := 1.30    # cooldown entre ataques
const PATROL_RANGE  := 55.0    # distancia a cada lado del origen
const HURT_DUR      := 0.32
const KNOCKBACK_DEC := 480.0

# ── Estado ─────────────────────────────────────────────────────────────────
enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var state        := State.PATROL
var facing_right := false
var hp           := MAX_HP

var attack_timer     := 0.0
var atk_cdn_timer    := 0.0
var hurt_timer       := 0.0
var hit_landed       := false   # golpe único por swing
var knockback        := Vector2.ZERO
var patrol_origin    := Vector2.ZERO

var player: CharacterBody2D = null

var hp_bar_node:   Node2D = null
var hp_bar_blocks: Array  = []

@onready var sprite:    Sprite2D         = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemy")
	patrol_origin = global_position
	_build_placeholder_sprite()
	_build_hp_bar()
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

# ── Placeholder visual (reemplazar con sprite real luego) ──────────────────
func _build_placeholder_sprite() -> void:
	var w := 26; var h := 50
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var on_border := (x == 0 or x == w-1 or y == 0 or y == h-1)
			img.set_pixel(x, y, Color.BLACK if on_border else Color(0.85, 0.28, 0.0, 1.0))
	sprite.texture = ImageTexture.create_from_image(img)

# ── Barra de HP flotante ──────────────────────────────────────────────────
func _build_hp_bar() -> void:
	var bar := Node2D.new()
	bar.position = Vector2(0, -36)
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

# ── Loop principal ─────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	_tick_timers(delta)

	match state:
		State.PATROL: _do_patrol(delta)
		State.CHASE:  _do_chase(delta)
		State.ATTACK: _do_attack(delta)
		State.HURT:   _do_hurt(delta)
		State.DEAD:   velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

	# Aplicar y decaer knockback
	velocity.x += knockback.x * delta
	knockback   = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DEC * delta)

	sprite.flip_h = not facing_right
	move_and_slide()

func _tick_timers(delta: float) -> void:
	if attack_timer  > 0.0: attack_timer  -= delta
	if atk_cdn_timer > 0.0: atk_cdn_timer -= delta
	if hurt_timer    > 0.0: hurt_timer    -= delta

func _player_dist() -> float:
	if not player: return INF
	return global_position.distance_to(player.global_position)

# ── Patrulla ───────────────────────────────────────────────────────────────
func _do_patrol(delta: float) -> void:
	if player and _player_dist() <= DETECT_RANGE:
		state = State.CHASE
		return

	var target_x := patrol_origin.x + (PATROL_RANGE if facing_right else -PATROL_RANGE)
	var dir: float = signf(target_x - global_position.x)
	velocity.x    = move_toward(velocity.x, dir * MOVE_SPEED * 0.6, 250.0 * delta)

	if global_position.x >= patrol_origin.x + PATROL_RANGE:
		facing_right = false
	elif global_position.x <= patrol_origin.x - PATROL_RANGE:
		facing_right = true

# ── Persecución ────────────────────────────────────────────────────────────
func _do_chase(delta: float) -> void:
	if not player:
		state = State.PATROL
		return

	var dist := _player_dist()
	if dist > DETECT_RANGE * 1.6:
		state = State.PATROL
		return

	facing_right = player.global_position.x > global_position.x

	if dist <= ATTACK_RANGE and atk_cdn_timer <= 0.0:
		_begin_attack()
		return

	velocity.x = move_toward(velocity.x, sign(player.global_position.x - global_position.x) * MOVE_SPEED, 280.0 * delta)

# ── Ataque ─────────────────────────────────────────────────────────────────
func _begin_attack() -> void:
	state        = State.ATTACK
	attack_timer = ATTACK_DUR
	hit_landed   = false
	velocity.x   = 0.0

func _do_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 380.0 * delta)

	# Impacto a mitad del swing
	if not hit_landed and attack_timer < ATTACK_DUR * 0.5:
		hit_landed = true
		if player and _player_dist() < ATTACK_RANGE + 10.0:
			var from_right := global_position.x > player.global_position.x
			if player.has_method("take_damage"):
				player.call("take_damage", ATTACK_DMG, from_right)

	if attack_timer <= 0.0:
		atk_cdn_timer = ATTACK_CDN
		state = State.CHASE if (player and _player_dist() <= DETECT_RANGE * 1.6) else State.PATROL

# ── Daño recibido ──────────────────────────────────────────────────────────
func take_damage(amount: int, from_right: bool, kb: float = -1.0) -> void:
	if state == State.DEAD: return
	hp          -= amount
	var mag: float = 280.0 if kb < 0.0 else kb
	knockback.x  = mag * (-1.0 if from_right else 1.0)   # empuja lejos del jugador
	_refresh_hp_bar()
	if hp <= 0:
		_die()
	else:
		state      = State.HURT
		hurt_timer = HURT_DUR

func _do_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
	if hurt_timer <= 0.0:
		state = State.CHASE if (player and _player_dist() <= DETECT_RANGE * 1.6) else State.PATROL

func _die() -> void:
	state = State.DEAD
	collision.set_deferred("disabled", true)
	sprite.modulate = Color(0.4, 0.4, 0.4, 1.0)
	await get_tree().create_timer(0.6).timeout
	queue_free()
