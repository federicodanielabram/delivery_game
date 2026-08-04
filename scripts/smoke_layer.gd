extends Node2D

@export var particle_count: int = 12
@export var lifetime: float = 18.0
@export var speed_min: float = 6.0
@export var speed_max: float = 15.0
@export var scale_min: float = 1.8
@export var scale_max: float = 3.2
@export var smoke_color: Color = Color(0.55, 0.60, 0.82, 0.05)
@export var emit_extents: Vector2 = Vector2(800, 400)
@export var parallax: float = 0.02
@export var y_offset: float = 0.0

func _ready() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(emit_extents.x, emit_extents.y, 1.0)
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = 30.0
	mat.gravity = Vector3(1.5, 0.0, 0.0)
	mat.initial_velocity_min = speed_min
	mat.initial_velocity_max = speed_max
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.color = smoke_color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.15, Color(1, 1, 1, 1.0))
	ramp.add_point(0.85, Color(1, 1, 1, 1.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex

	var p := GPUParticles2D.new()
	p.process_material = mat
	p.texture = tex
	p.local_coords = true
	p.amount = particle_count
	p.lifetime = lifetime
	p.preprocess = lifetime
	add_child(p)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		var cx := cam.get_screen_center_position().x
		var cy := cam.get_screen_center_position().y
		global_position = Vector2(cx, cy + y_offset)
