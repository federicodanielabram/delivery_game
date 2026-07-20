extends Area2D

const SPEED       := 820.0
const DMG         := 1
const LIFETIME    := 3.0
const FRAME_COUNT := 30
const SPIN_FPS    := 120.0

var direction := 1.0
var life      := LIFETIME

@onready var col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_mask = 2  # detecta al jugador (layer 2)
	_build_visual()

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
			body.take_damage(DMG, direction > 0.0, 0.0)
			queue_free()
			return
