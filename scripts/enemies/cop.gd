extends CharacterBody2D

const GRAVITY        := 850.0
const PARALLAX       := 1.275
const MAX_HP         := 8
const MOVE_SPEED     := 75.0
const DETECT_RANGE   := 900.0
const ATTACK_RANGE   := 100.0
const ATTACK_CDN     := 2.2
const HURT_DUR       := 0.4
const KNOCKBACK_DEC  := 400.0

const WALK_START_FPS    := 24.0
const WALK_START_FRAMES := 9
const WALK_LOOP_FPS     := 24.0
const WALK_LOOP_FRAMES  := 32
const WALK_END_FPS      := 24.0
const WALK_END_FRAMES   := 10
const ATTACK_FPS        := 28.0
const ATTACK_FRAMES     := 48
const ATTACK_HIT_FRAME  := 28
const HURT_FPS          := 24.0
const HURT_FRAMES       := 44
const DEATH_FPS         := 24.0
const DEATH_FRAMES      := 45

enum State     { PATROL, ALERT, ATTACK, HURT, DEAD }
enum WalkPhase { IDLE, STARTING, LOOPING, STOPPING }

var state      := State.PATROL
var walk_phase := WalkPhase.IDLE
var facing_right  := false
var hp            := MAX_HP

var attack_timer     := 0.0
var hurt_timer       := 0.0
var knockback        := Vector2.ZERO
var patrol_origin    := Vector2.ZERO
var _attack_hit_done  := false
var _parallax_base_x  := 0.0
var _cam_ready        := false
var player: CharacterBody2D = null

var obstacle_mode: bool = false

var hp_bar_node:   Node2D = null
var hp_bar_blocks: Array  = []
var _shadow: Sprite2D = null

@onready var sprite:    AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 4
	collision_mask  = 1
	z_index = 2
	add_to_group("enemy")
	add_to_group("cop")
	patrol_origin = global_position
	_load_sprites()
	_build_hp_bar()
	_create_shadow()
	call_deferred("_find_player")
	sprite.animation_finished.connect(_on_animation_finished)

func _create_shadow() -> void:
	_shadow = Sprite2D.new()
	_shadow.z_index = -1
	var w := 90
	var h := 28
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w * 0.5
	var cy := h * 0.5
	for x in range(w):
		for y in range(h):
			var dx := (x - cx) / cx
			var dy := (y - cy) / cy
			var a := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	_shadow.texture = ImageTexture.create_from_image(img)
	_shadow.position = Vector2(0, 30)
	_shadow.modulate.a = 0.45
	add_child(_shadow)
	move_child(_shadow, 0)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

func _load_sprites() -> void:
	const BASE := "res://assets/sprites/enemies/cop"
	var frames := SpriteFrames.new()

	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 1.0)
	var idle_tex := load(BASE + "/walk/cop__001.png") as Texture2D
	if idle_tex: frames.add_frame("idle", idle_tex)

	frames.add_animation("walk_start")
	frames.set_animation_loop("walk_start", false)
	frames.set_animation_speed("walk_start", WALK_START_FPS)
	for i in range(5, 10):  # frames 005-009; 002-004 skip (static/pre-walk)
		var tex := load(BASE + "/walk_start/cop__%s.png" % str(i).pad_zeros(3)) as Texture2D
		if tex: frames.add_frame("walk_start", tex)

	frames.add_animation("walk_loop")
	frames.set_animation_loop("walk_loop", true)
	frames.set_animation_speed("walk_loop", WALK_LOOP_FPS)
	for i in range(1, WALK_LOOP_FRAMES + 1):
		var tex := load(BASE + "/walk_loop/cop__%s.png" % str(i).pad_zeros(3)) as Texture2D
		if tex: frames.add_frame("walk_loop", tex)

	frames.add_animation("walk_end")
	frames.set_animation_loop("walk_end", false)
	frames.set_animation_speed("walk_end", WALK_END_FPS)
	for i in range(1, WALK_END_FRAMES + 1):
		var tex := load(BASE + "/walk_end/cop__%s.png" % str(i).pad_zeros(3)) as Texture2D
		if tex: frames.add_frame("walk_end", tex)

	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", ATTACK_FPS)
	for i in range(1, ATTACK_FRAMES + 1):
		var tex := load(BASE + "/attack/cop__%s.png" % str(i).pad_zeros(3)) as Texture2D
		if tex: frames.add_frame("attack", tex)

	frames.add_animation("hurt")
	frames.set_animation_loop("hurt", false)
	frames.set_animation_speed("hurt", HURT_FPS)
	for i in range(1, HURT_FRAMES + 1):
		var tex := load(BASE + "/hurt/cop__%s.png" % str(i).pad_zeros(3)) as Texture2D
		if tex: frames.add_frame("hurt", tex)

	frames.add_animation("death")
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", DEATH_FPS)
	for i in range(1, DEATH_FRAMES + 1):
		var tex := load(BASE + "/death/cop__%s.png" % str(i).pad_zeros(3)) as Texture2D
		if tex: frames.add_frame("death", tex)

	sprite.sprite_frames = frames
	sprite.position   = Vector2(0, -30)
	sprite.scale      = Vector2(1.1, 1.1)
	sprite.light_mask = 2
	sprite.play("idle")

func _build_hp_bar() -> void:
	var bar := Node2D.new()
	bar.position = Vector2(0, -70)
	bar.visible  = false
	var bw    := 6.0
	var gap   := 2.0
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
	var cam := get_viewport().get_camera_2d()
	var cam_x := cam.get_screen_center_position().x if cam else 0.0

	if not _cam_ready and cam:
		_parallax_base_x = global_position.x - cam_x * (1.0 - PARALLAX)
		_cam_ready = true

	if _cam_ready:
		global_position.x = _parallax_base_x + cam_x * (1.0 - PARALLAX)

	if state == State.DEAD:
		velocity = Vector2.ZERO
		if _cam_ready:
			_parallax_base_x = global_position.x - cam_x * (1.0 - PARALLAX)
		return

	if obstacle_mode:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.y = 0.0
		if sprite.animation != "idle":
			sprite.play("idle")
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if attack_timer > 0.0: attack_timer -= delta
	if hurt_timer  > 0.0: hurt_timer  -= delta

	match state:
		State.PATROL: _do_patrol(delta)
		State.ALERT:  _do_alert(delta)
		State.ATTACK: _do_attack(delta)
		State.HURT:   _do_hurt(delta)

	sprite.flip_h = facing_right
	if state == State.ATTACK:
		var attack_x := 17.0 if not facing_right else -17.0
		sprite.position.x = attack_x
	elif sprite.animation == "walk_start":
		# frame 0 (cop__005) = idle pose → same offset as idle
		# frame 4 (cop__009) = walk pose → same offset as walk_loop
		var idle_x := 45.0 if not facing_right else -35.0
		var walk_x := 45.0 if not facing_right else -35.0
		var t := float(sprite.frame) / 4.0
		sprite.position.x = lerpf(idle_x, walk_x, t)
	else:
		sprite.position.x = 45.0 if not facing_right else -35.0
	_update_walk_anim()
	move_and_slide()
	if _cam_ready:
		_parallax_base_x = global_position.x - cam_x * (1.0 - PARALLAX)

func _update_walk_anim() -> void:
	if state == State.ATTACK or state == State.HURT or state == State.DEAD:
		return
	var moving: bool = abs(velocity.x) > 1.0
	match walk_phase:
		WalkPhase.IDLE:
			if moving:
				walk_phase = WalkPhase.STARTING
				sprite.play("walk_start")
			else:
				if sprite.animation != "idle":
					sprite.play("idle")
		WalkPhase.STARTING:
			pass
		WalkPhase.LOOPING:
			if not moving:
				walk_phase = WalkPhase.STOPPING
				sprite.play("walk_end")
			elif sprite.animation != "walk_loop":
				sprite.play("walk_loop")
		WalkPhase.STOPPING:
			if moving:
				walk_phase = WalkPhase.STARTING
				sprite.play("walk_start")

func _do_patrol(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	if player:
		facing_right = player.global_position.x > global_position.x
		if _player_dist() <= DETECT_RANGE:
			state = State.ALERT

func _do_alert(delta: float) -> void:
	if not player:
		state = State.PATROL
		return
	facing_right = player.global_position.x > global_position.x
	var dist := _player_dist()
	if dist <= ATTACK_RANGE and _is_on_screen():
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		if attack_timer <= 0.0:
			state = State.ATTACK
			walk_phase = WalkPhase.IDLE
			_attack_hit_done = false
			z_index = 3
			sprite.play("attack")
	else:
		var dir := signf(player.global_position.x - global_position.x)
		velocity.x = move_toward(velocity.x, dir * MOVE_SPEED, 250.0 * delta)

func _do_attack(delta: float) -> void:
	velocity.x = 0.0
	if not _attack_hit_done and sprite.frame >= ATTACK_HIT_FRAME:
		_attack_hit_done = true
		_try_hit_player()

func _try_hit_player() -> void:
	if not player: return
	if _player_dist() > ATTACK_RANGE + 20.0: return
	if player.has_method("take_damage"):
		player.take_damage(1, facing_right, 0.0)

func _do_hurt(delta: float) -> void:
	velocity.x  = knockback.x
	knockback.x = move_toward(knockback.x, 0.0, KNOCKBACK_DEC * delta)
	if hurt_timer <= 0.0:
		state = State.ALERT if (player and _player_dist() <= DETECT_RANGE * 1.5) else State.PATROL

func _on_animation_finished() -> void:
	match sprite.animation:
		"walk_start":
			walk_phase = WalkPhase.LOOPING
			sprite.play("walk_loop")
		"walk_end":
			walk_phase = WalkPhase.IDLE
		"attack":
			z_index = 2
			attack_timer = 0.0
			walk_phase = WalkPhase.STOPPING
			state = State.ALERT if (player and _player_dist() <= DETECT_RANGE * 1.5) else State.PATROL
		"hurt":
			state = State.ALERT if (player and _player_dist() <= DETECT_RANGE * 1.5) else State.PATROL
		"death":
			pass

func _player_dist() -> float:
	if not player: return INF
	return abs(player.global_position.x - global_position.x)

func _is_on_screen() -> bool:
	var screen_pos := get_viewport().get_canvas_transform() * global_position
	return get_viewport_rect().has_point(screen_pos)

func take_damage(amount: int, from_right: bool, kb: float = 0.0) -> void:
	if state == State.DEAD: return
	hp -= amount
	knockback.x = kb * (-1.0 if from_right else 1.0)
	_refresh_hp_bar()
	if hp <= 0:
		if obstacle_mode:
			collision.disabled = true
		_die()
	else:
		walk_phase = WalkPhase.IDLE
		state      = State.HURT
		hurt_timer = HURT_DUR
		sprite.play("hurt")

func take_weakness_damage(from_right: bool) -> void:
	if state == State.DEAD: return
	_refresh_hp_bar()
	_die()

func _die() -> void:
	state = State.DEAD
	walk_phase = WalkPhase.IDLE
	z_index = 2
	collision.set_deferred("disabled", true)
	if _shadow: _shadow.visible = false
	sprite.play("death")
