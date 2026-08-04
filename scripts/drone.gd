extends Node2D

@export var offset: Vector2 = Vector2(-320, -200)
@export var follow_speed: float = 3.0
@export var max_x_speed: float = 340.0   # px/s — PP corre a 528, drone se queda atrás
@export var follow_speed_x: float = 3.0  # factor proporcional en X (más bajo = frenada más suave)
@export var tilt_factor: float = 0.003
@export var tilt_max: float = 0.25
@export var tilt_speed: float = 4.0
@export var blink_speed: float = 1.5

var _target: Node2D
var _anim: AnimatedSprite2D
var _prev_x: float = 0.0
var _light_main: PointLight2D
var _light_red: PointLight2D
var _light_blue: PointLight2D
var _light_red_mid: PointLight2D
var _light_blue_mid: PointLight2D
var _halo_red: Sprite2D
var _halo_blue: Sprite2D
var _bob_timer: float = 0.0
var _blink_timer: float = 0.0
var _blink_state: bool = false
var _cone_x: float = 0.0
var _cone_vel: float = 0.0

func _make_cone_tex(tex_size: int, half_angle_deg: float) -> ImageTexture:
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var cx := tex_size / 2.0
	var cy := tex_size / 2.0
	var max_dist := cx
	var half_angle := deg_to_rad(half_angle_deg)
	var down := Vector2(0.0, 1.0)
	for y in range(tex_size):
		for x in range(tex_size):
			var dx := x - cx
			var dy := y - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist < 0.5:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
				continue
			if dist > max_dist:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var angle := absf(Vector2(dx, dy).normalized().angle_to(down))
			if angle > half_angle:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var b := (1.0 - angle / half_angle) * (1.0 - dist / max_dist)
				img.set_pixel(x, y, Color(b, b, b, b))
	return ImageTexture.create_from_image(img)

func _make_light_tex(size: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex

func _ready() -> void:
	add_to_group("drone")
	_target = get_tree().get_first_node_in_group("player")

	_anim = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation("fly")
	frames.set_animation_loop("fly", true)
	frames.set_animation_speed("fly", 12.0)

	for i in range(1, 13):
		var path := "res://assets/sprites/drone/drone_%04d.png" % i
		var tex: Texture2D = load(path)
		if tex:
			frames.add_frame("fly", tex)

	_anim.sprite_frames = frames
	_anim.scale = Vector2(0.112, 0.112)
	_anim.modulate = Color(0.55, 0.52, 0.63)
	_anim.play("fly")
	add_child(_anim)

	# Luz principal: cono direccional apuntando hacia el PP
	_light_main = PointLight2D.new()
	_light_main.texture = _make_cone_tex(128, 35.0)
	_light_main.color = Color(0.9, 0.95, 1.0)
	_light_main.energy = 6.0
	_light_main.texture_scale = 4.5
	add_child(_light_main)

	# Luz roja de navegación
	_light_red = PointLight2D.new()
	_light_red.texture = _make_light_tex(64)
	_light_red.color = Color(1.0, 0.1, 0.1)
	_light_red.energy = 2.5
	_light_red.texture_scale = 16.0
	_light_red.position = Vector2(-190, -120)
	add_child(_light_red)

	_halo_red = Sprite2D.new()
	_halo_red.texture = _make_light_tex(32)
	_halo_red.modulate = Color(1.0, 0.1, 0.1, 1.0)
	_halo_red.scale = Vector2(20, 20)
	_halo_red.position = Vector2(-190, -370)
	_anim.add_child(_halo_red)

	# Luz azul de navegación
	_light_blue = PointLight2D.new()
	_light_blue.texture = _make_light_tex(64)
	_light_blue.color = Color(0.15, 0.4, 1.0)
	_light_blue.energy = 2.5
	_light_blue.texture_scale = 16.0
	_light_blue.position = Vector2(-210, -125)
	_light_blue.visible = false
	add_child(_light_blue)

	# Luces de edificios intermedios (mitad de intensidad, light_mask=2)
	_light_red_mid = PointLight2D.new()
	_light_red_mid.texture = _make_light_tex(64)
	_light_red_mid.color = Color(1.0, 0.1, 0.1)
	_light_red_mid.energy = 1.25
	_light_red_mid.texture_scale = 20.0
	_light_red_mid.range_item_cull_mask = 2
	_light_red_mid.position = Vector2(-190, -120)
	_light_red_mid.visible = false
	add_child(_light_red_mid)

	_light_blue_mid = PointLight2D.new()
	_light_blue_mid.texture = _make_light_tex(64)
	_light_blue_mid.color = Color(0.15, 0.4, 1.0)
	_light_blue_mid.energy = 1.25
	_light_blue_mid.texture_scale = 20.0
	_light_blue_mid.range_item_cull_mask = 2
	_light_blue_mid.position = Vector2(-210, -125)
	_light_blue_mid.visible = false
	add_child(_light_blue_mid)

	_halo_blue = Sprite2D.new()
	_halo_blue.texture = _make_light_tex(32)
	_halo_blue.modulate = Color(0.15, 0.4, 1.0, 1.0)
	_halo_blue.scale = Vector2(20, 20)
	_halo_blue.position = Vector2(0, -355)
	_halo_blue.visible = false
	_anim.add_child(_halo_blue)

	if _target:
		global_position = _target.global_position + offset
		_prev_x = global_position.x
		_cone_x = _target.global_position.x

func _process(delta: float) -> void:
	if not _target:
		return
	var target_pos := _target.global_position + offset
	var diff_x := target_pos.x - global_position.x
	var vel_x_desired := clampf(diff_x * follow_speed_x, -max_x_speed, max_x_speed)
	global_position.x += vel_x_desired * delta
	global_position.y = lerpf(global_position.y, target_pos.y, follow_speed * delta)

	var vel_x := (global_position.x - _prev_x) / delta
	_prev_x = global_position.x
	var target_tilt: float = clampf(vel_x * tilt_factor, -tilt_max, tilt_max)
	_anim.rotation = lerpf(_anim.rotation, target_tilt, tilt_speed * delta)

	_bob_timer += delta
	var bob_y := sin(_bob_timer * 1.2) * 6.0
	_anim.position.y = bob_y
	_light_red.position.y = -120.0 + bob_y
	_light_red_mid.position.y = -120.0 + bob_y
	_light_blue.position.y = -125.0 + bob_y
	_light_blue_mid.position.y = -125.0 + bob_y

	_blink_timer += delta
	if _blink_timer >= 1.0 / blink_speed:
		_blink_timer = 0.0
		_blink_state = !_blink_state
		_light_red.visible = _blink_state
		_halo_red.visible = _blink_state
		_light_blue.visible = !_blink_state
		_halo_blue.visible = !_blink_state
		_light_red_mid.visible = _blink_state
		_light_blue_mid.visible = !_blink_state
		if _blink_state:
			_anim.modulate = Color(0.68, 0.44, 0.55)
		else:
			_anim.modulate = Color(0.44, 0.50, 0.75)

	var player_x := _target.global_position.x
	_cone_vel += (player_x - _cone_x) * 28.0 * delta
	_cone_vel *= maxf(0.0, 1.0 - 9.0 * delta)
	_cone_x += _cone_vel * delta
	var dx := _cone_x - global_position.x
	var dy := (_target.global_position.y + 20.0) - global_position.y
	_light_main.rotation = Vector2(dx, dy).angle() - PI / 2.0
