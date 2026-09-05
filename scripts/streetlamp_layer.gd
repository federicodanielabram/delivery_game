extends Node2D

@export var parallax: float = 1.2
@export var spacing: float = 500.0
@export var scale_factor: float = 0.523
@export var light_color: Color = Color(1.0, 0.88, 0.45)
@export var light_energy: float = 1.4
@export var light_scale: float = 4.0
@export var light_dir_energy: float = 2.2
@export var light_dir_scale: float = 24.0

const LEVEL_WIDTH: int = 2000
const FLOOR_Y: int = 655
const MODE_NORMAL  := 0
const MODE_FLICKER := 1
const MODE_DEAD    := 2

var _base_x: Array = []
var _lamps: Array = []
var _rng := RandomNumberGenerator.new()
var _lamp_head_x: float = 0.0
var _lamp_head_y: float = 0.0
var _gen_head_x:  float = 0.0
var _sprite_tex: Texture2D = null
var _light_tex: GradientTexture2D = null
var _cone_tex: ImageTexture = null

func _make_light_tex() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex

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

func _ready() -> void:
	_rng.seed = 77
	_sprite_tex = load("res://assets/sprites/streetlamp.png")
	if not _sprite_tex:
		return
	_light_tex = _make_light_tex()
	_cone_tex  = _make_cone_tex(128, 32.0)
	var img_h: float = _sprite_tex.get_height() * scale_factor
	_lamp_head_x = 267.0 * scale_factor
	_lamp_head_y = FLOOR_Y - img_h + 17.0 + 40.0 * scale_factor

	var x: float = 0.0
	while x < LEVEL_WIDTH:
		_add_lamp(x)
		x += spacing
	_gen_head_x = x

func _add_lamp(x: float) -> void:
	var img_h: float = _sprite_tex.get_height() * scale_factor

	var sp := Sprite2D.new()
	sp.texture  = _sprite_tex
	sp.centered = false
	sp.scale    = Vector2(scale_factor, scale_factor)
	sp.position = Vector2(x, FLOOR_Y - img_h + 17)
	sp.modulate = Color(0.40, 0.35, 0.50)
	add_child(sp)
	_base_x.append(x)

	var head_pos := Vector2(x + _lamp_head_x, _lamp_head_y)

	var light := PointLight2D.new()
	light.texture       = _light_tex
	light.color         = light_color
	light.energy        = light_energy
	light.texture_scale = light_scale
	light.range_z_max   = 2
	light.position      = head_pos
	add_child(light)

	var light_dir := PointLight2D.new()
	light_dir.texture       = _cone_tex
	light_dir.color         = light_color
	light_dir.energy        = light_dir_energy
	light_dir.texture_scale = light_dir_scale
	light_dir.range_z_max   = 2
	light_dir.position      = head_pos
	add_child(light_dir)

	var light_pp := PointLight2D.new()
	light_pp.texture       = _light_tex
	light_pp.color         = light_color
	light_pp.energy        = light_energy * 0.5
	light_pp.texture_scale = light_scale
	light_pp.range_z_min   = 3
	light_pp.range_z_max   = 3
	light_pp.position      = head_pos
	add_child(light_pp)

	var light_car := PointLight2D.new()
	light_car.texture        = _light_tex
	light_car.color          = light_color
	light_car.energy         = light_energy * 0.5
	light_car.texture_scale  = light_scale
	light_car.range_z_max    = 2
	light_car.set_item_cull_mask(2)
	light_car.position       = head_pos
	add_child(light_car)

	var mode := MODE_FLICKER if (_lamps.size() % 3 == 2) else MODE_NORMAL
	if mode == MODE_DEAD:
		light.enabled     = false
		light_dir.enabled = false
		light_pp.enabled  = false
		light_car.enabled = false

	_lamps.append({
		"sp":            sp,
		"light":         light,
		"light_dir":     light_dir,
		"light_pp":      light_pp,
		"light_car":     light_car,
		"mode":          mode,
		"sub_state":     0,
		"timer":         _rng.randf_range(1.0, 8.0),
		"flicker_timer": 0.0,
	})

# Oculta los faroles sobre la pizzeria y agrega uno sobre el edificio derecho.
func finalize_for_pizzeria(skip_from: float, skip_to: float, extra_x: float) -> void:
	for i in range(_lamps.size()):
		if _base_x[i] >= skip_from and _base_x[i] <= skip_to:
			var lamp: Dictionary = _lamps[i]
			lamp["mode"]              = MODE_NORMAL  # evita que _process reactive las luces
			lamp["sp"].visible        = false
			lamp["light"].enabled     = false
			lamp["light_dir"].enabled = false
			lamp["light_pp"].enabled  = false
			lamp["light_car"].enabled = false
	_add_lamp(extra_x)

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)

	for i in range(_lamps.size()):
		var lamp: Dictionary = _lamps[i]
		var new_x: float = _base_x[i] + world_offset
		var head_pos := Vector2(new_x + _lamp_head_x, _lamp_head_y)
		lamp["sp"].global_position.x      = new_x
		lamp["light"].global_position     = head_pos
		lamp["light_dir"].global_position = head_pos
		lamp["light_pp"].global_position  = head_pos
		lamp["light_car"].global_position = head_pos

		var light: PointLight2D     = lamp["light"]
		var light_dir: PointLight2D = lamp["light_dir"]
		var light_pp: PointLight2D  = lamp["light_pp"]
		var light_car: PointLight2D = lamp["light_car"]
		lamp["timer"] -= delta

		match lamp["mode"]:
			MODE_FLICKER:
				if lamp["sub_state"] == 0:
					if lamp["timer"] <= 0.0:
						lamp["sub_state"] = 1
						lamp["timer"] = _rng.randf_range(0.3, 1.0)
						lamp["flicker_timer"] = 0.0
				else:
					lamp["flicker_timer"] -= delta
					if lamp["flicker_timer"] <= 0.0:
						light.enabled     = !light.enabled
						light_dir.enabled = light.enabled
						light_pp.enabled  = light.enabled
						light_car.enabled = light.enabled
						lamp["flicker_timer"] = _rng.randf_range(0.03, 0.12)
					if lamp["timer"] <= 0.0:
						light.enabled     = true
						light_dir.enabled = true
						light_pp.enabled  = true
						light_car.enabled = true
						lamp["sub_state"] = 0
						lamp["timer"] = _rng.randf_range(0.5, 3.0)

			MODE_DEAD:
				if lamp["sub_state"] == 0:
					if lamp["timer"] <= 0.0:
						lamp["sub_state"] = 1
						lamp["timer"] = _rng.randf_range(0.8, 2.5)
						lamp["flicker_timer"] = 0.0
				else:
					lamp["flicker_timer"] -= delta
					if lamp["flicker_timer"] <= 0.0:
						light.enabled     = !light.enabled
						light_dir.enabled = light.enabled
						light_pp.enabled  = light.enabled
						light_car.enabled = light.enabled
						lamp["flicker_timer"] = _rng.randf_range(0.04, 0.15)
					if lamp["timer"] <= 0.0:
						light.enabled     = false
						light_dir.enabled = false
						light_pp.enabled  = false
						light_car.enabled = false
						lamp["sub_state"] = 0
						lamp["timer"] = _rng.randf_range(6.0, 22.0)

	# Generación infinita de faroles
	var cam_base := cam.get_screen_center_position().x * parallax
	while _gen_head_x < cam_base + spacing * 4:
		_add_lamp(_gen_head_x)
		_gen_head_x += spacing

	# Limpieza de faroles que quedaron atrás
	var cutoff := cam_base - spacing * 3
	var j := 0
	while j < _lamps.size():
		if _base_x[j] < cutoff:
			var old: Dictionary = _lamps[j]
			old["sp"].queue_free()
			old["light"].queue_free()
			old["light_dir"].queue_free()
			old["light_pp"].queue_free()
			old["light_car"].queue_free()
			_lamps.remove_at(j)
			_base_x.remove_at(j)
		else:
			j += 1
