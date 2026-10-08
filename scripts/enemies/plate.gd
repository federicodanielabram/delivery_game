extends Area2D

const DUST_PUFF_SCENE := preload("res://scenes/vfx/DustPuff.tscn")
var tex_hit_impact_frames: Array[Texture2D] = []

const SPEED       := 820.0
const DMG         := 1
const LIFETIME    := 3.0

# ── DEBUG: el plato no le saca vida al jugador ────────────────────────────────
# Con esto en true se puede probar la jugabilidad de los mozos sin morir por
# los platos. Volver a false para el flujo normal.
const DEBUG_NO_DAMAGE_TO_PLAYER := true
const FRAME_COUNT := 30
const SPIN_FPS    := 120.0

# Estados agachados de player.gd (State enum) — si el PP está en alguno de
# estos, el plato pasa por encima sin pegarle, en vez de conectar siempre.
const _PLAYER_STATE_CROUCH            := 10
const _PLAYER_STATE_CROUCH_WALK       := 11
const _PLAYER_STATE_ROLL              := 13
const _PLAYER_STATE_CROUCH_ATTACKING  := 16
const _CROUCHED_STATES := [_PLAYER_STATE_CROUCH, _PLAYER_STATE_CROUCH_WALK, _PLAYER_STATE_ROLL, _PLAYER_STATE_CROUCH_ATTACKING]

var direction := 1.0
var life      := LIFETIME

@onready var col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_mask = 2  # detecta al jugador (layer 2)
	z_index = 3   # por delante del boss (z_index 2 en boss.gd) — pedido a mano
	for i in range(1, 7):
		tex_hit_impact_frames.append(load("res://assets/sprites/vfx/hit_impact/hit_impact_%03d.png" % i))
	_build_visual()

func _spawn_hit_impact(at_position: Vector2) -> void:
	var puff := DUST_PUFF_SCENE.instantiate() as Node2D
	get_parent().add_child(puff)
	puff.global_position = at_position
	puff.z_index = 10   # por delante de todo, es un flash de impacto
	puff.z_as_relative = false
	if puff.has_method("play"):
		puff.call("play", tex_hit_impact_frames, 22.0)

func init(dir: float) -> void:
	direction = dir
	col.position.x = 15.0 * dir

func _build_visual() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("spin")
	frames.set_animation_loop("spin", true)
	frames.set_animation_speed("spin", SPIN_FPS)
	for i in range(1, FRAME_COUNT + 1):
		var tex := load("res://assets/sprites/enemies/waiter/plate_spin/plate_spin___%s.png" % str(i).pad_zeros(3)) as Texture2D
		if tex: frames.add_frame("spin", tex)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.play("spin")
	add_child(spr)
	scale = Vector2(0.24, 0.24)

func _physics_process(delta: float) -> void:
	position.x += SPEED * direction * delta
	life        -= delta
	if life <= 0.0:
		queue_free()
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			if body.get("state") in _CROUCHED_STATES: continue
			var real_dmg := 0 if DEBUG_NO_DAMAGE_TO_PLAYER else DMG
			body.take_damage(real_dmg, direction > 0.0, 0.0)
			_spawn_hit_impact(global_position)
			queue_free()
			return
