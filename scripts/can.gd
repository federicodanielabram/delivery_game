extends Area2D

const SPEED     := 620.0
const DMG       := 1
const LIFETIME  := 2.5
const CAN_COUNT := 9
const CAN_SCALE := 0.055  # proporcional al jugador (~21px de largo)
const SPIN      := 0.0    # sin giro, vuela horizontal

var direction := 1.0
var life      := LIFETIME

@onready var col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_mask = 4 | 32   # detecta enemigos (4) y cops-obstáculo de tráfico (32)
	_build_visual()

func init(dir: float) -> void:
	direction = dir

func _build_visual() -> void:
	# Diseño aleatorio entre las 9 latas
	var n := randi_range(1, CAN_COUNT)
	var tex := load("res://assets/sprites/player/cans/can_%s.png" % str(n).pad_zeros(2)) as Texture2D
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale   = Vector2(CAN_SCALE, CAN_SCALE)
	spr.flip_h  = direction < 0.0
	add_child(spr)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(tex.get_width() * CAN_SCALE * 0.8, tex.get_height() * CAN_SCALE * 0.8)
	col.shape  = shape

func _physics_process(delta: float) -> void:
	position.x += SPEED * direction * delta
	rotation   += SPIN * direction * delta
	life        -= delta
	if life <= 0.0:
		queue_free()
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(DMG, direction < 0.0)
			queue_free()
			return
