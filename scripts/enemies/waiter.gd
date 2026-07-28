extends CharacterBody2D

const GRAVITY       := 850.0
const MAX_HP        := 7
const MOVE_SPEED    := 95.0
const DETECT_RANGE  := 99999.0
const RETREAT_DIST  := 330.0
const THROW_RANGE   := 99999.0
const THROW_CDN     := 0.9
const HURT_DUR      := 0.5
const KNOCKBACK_DEC := 480.0
const IDLE_FPS        := 24.0
const IDLE_FRAMES     := 28
const IDLE2_FRAMES    := 16
const WALK_FPS            := 30.0
const WALK_FRAMES         := 40
const IDLE_TO_WALK_FPS    := 30.0
const IDLE_TO_WALK_FRAMES := 22
const WALK_TO_IDLE_FPS    := 30.0
const WALK_TO_IDLE_FRAMES := 11
const THROW_FPS    := 30.0
const THROW_FRAMES := 35
const HURT_FPS     := 88.0
const HURT_FRAMES  := 44
const DEATH_FPS    := 30.0
const DEATH_FRAMES := 14

const PLATE_SCENE := preload("res://scenes/enemies/Plate.tscn")

enum State { PATROL, ALERT, THROW, HURT, DEAD }

var state         := State.PATROL
var facing_right  := false
var hp            := MAX_HP

var throw_timer        := 0.0
var throw_burst_left   := 4
var hurt_timer    := 0.0
var pace_timer    := 0.0
var pace_dir      := -1.0
var knockback     := Vector2.ZERO
var patrol_origin  := Vector2.ZERO
var walk_frame     := 0.0
var player: CharacterBody2D = null

var hp_bar_node:   Node2D = null
var hp_bar_blocks: Array  = []

@export var skin_variant: String = ""  # "" = original, "dark", "light"

@onready var sprite:    AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 4
	collision_mask  = 1
	add_to_group("enemy")
	patrol_origin = global_position
	_load_sprites()
	_build_hp_bar()
	call_deferred("_find_player")
	sprite.animation_finished.connect(_on_animation_finished)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

func _skin_path() -> String:
	return "res://assets/sprites/enemies/waiter" + ("_" + skin_variant if skin_variant != "" else "")

func _load_sprites() -> void:
	var base := _skin_path()
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", IDLE_FPS)

	var idle_textures: Array[Texture2D] = []
	for i in range(1, IDLE_FRAMES + 1):
		var tex := load("%s/idle/idle___%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: idle_textures.append(tex)

	var idle2_textures: Array[Texture2D] = []
	for i in range(1, IDLE2_FRAMES + 1):
		var tex := load("%s/idle2/idle2___%s.png" % [base, str(i).pad_zeros(3)]) as Texture2D
		if tex: idle2_textures.append(tex)

	# Patrón: idle x4, idle2 x1, en loop
	for _rep in 4:
		for tex in idle_textures:
			frames.add_frame("idle", tex)
	for tex in idle2_textures:
		frames.add_frame("idle", tex)

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
	for i in range(1, THROW_FRAMES + 1):
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

	sprite.sprite_frames = frames
	sprite.position = Vector2(0, -4)
	sprite.play("idle")

func _build_hp_bar() -> void:
	var bar := Node2D.new()
	bar.position = Vector2(0, -56)
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
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if throw_timer > 0.0: throw_timer -= delta
	if hurt_timer  > 0.0: hurt_timer  -= delta
	if pace_timer  > 0.0: pace_timer  -= delta

	match state:
		State.PATROL: _do_patrol(delta)
		State.ALERT:  _do_alert(delta)
		State.THROW:  _do_throw(delta)
		State.HURT:   _do_hurt(delta)
		State.DEAD:   velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

	sprite.flip_h = facing_right
	_update_anim(delta)
	move_and_slide()

func _update_anim(delta: float) -> void:
	if state == State.THROW or state == State.HURT or state == State.DEAD: return

	var moving: bool = abs(velocity.x) > 1.0 and (state == State.PATROL or state == State.ALERT)

	# Transiciones idle_to_walk y walk_to_idle disponibles pero desactivadas
	if moving:
		if sprite.animation != "walk":
			sprite.animation = "walk"
			sprite.speed_scale = 0.0
		var moving_forward: bool = (velocity.x < 0.0 and not facing_right) or (velocity.x > 0.0 and facing_right)
		walk_frame = fposmod(walk_frame + WALK_FPS * delta * (1.0 if moving_forward else -1.0), float(WALK_FRAMES))
		sprite.set_frame_and_progress(floori(walk_frame), 0.0)
	else:
		if sprite.animation != "walk":
			sprite.animation = "walk"
			sprite.speed_scale = 0.0
		sprite.set_frame_and_progress(floori(walk_frame), 0.0)

func _separate_from_player(_delta: float) -> void:
	if not player or state == State.DEAD: return
	const MIN_SEP := 72.0
	var dx: float = global_position.x - player.global_position.x
	var overlap: float = MIN_SEP - abs(dx)
	if overlap > 0.0:
		var push: float = sign(dx) if abs(dx) > 0.5 else (1.0 if not facing_right else -1.0)
		global_position.x += push * overlap * 0.75
		velocity.x         = push * absf(velocity.x + 20.0)

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

	if dist < RETREAT_DIST:
		var retreat_dir := -signf(player.global_position.x - global_position.x)
		velocity.x = move_toward(velocity.x, retreat_dir * MOVE_SPEED * 2.0, 500.0 * delta)
	else:
		# Pace de lado a lado para estar caminando la mayor parte del tiempo
		if pace_timer <= 0.0:
			pace_dir  = -pace_dir
			pace_timer = randf_range(3.0, 4.8)
		velocity.x = move_toward(velocity.x, pace_dir * MOVE_SPEED * 0.95, 220.0 * delta)

	if dist <= THROW_RANGE and throw_timer <= 0.0 and _is_on_screen():
		if throw_burst_left > 0:
			throw_burst_left -= 1
			throw_timer = randf_range(0.40, 0.65)
			sprite.speed_scale = 2.2
		else:
			throw_burst_left = randi_range(3, 4)
			throw_timer = randf_range(1.10, 1.70)
			sprite.speed_scale = 1.0
		state = State.THROW
		sprite.play("throw")

func _is_on_screen() -> bool:
	var screen_pos := get_viewport().get_canvas_transform() * global_position
	return get_viewport_rect().has_point(screen_pos)

func _do_throw(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

func _spawn_plate() -> void:
	var plate := PLATE_SCENE.instantiate() as Node2D
	get_parent().add_child(plate)
	var dir := 1.0 if facing_right else -1.0
	plate.global_position = global_position + Vector2(dir * 85.0, -25.0)
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
	sprite.speed_scale = 1.0
	sprite.play("death")
