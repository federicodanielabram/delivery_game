extends Node2D

@export var offset_y: float = -200.0
@export var drone_speed: float = 500.0       # px/s — tope de persecución, siempre a fondo (sin
											  # amortiguar cuando te alcanza): corriendo a fondo deja
											  # 729-500=229px/s de separación neta; si frenás o te
											  # trabás, el dron viene directo a drone_speed hasta
											  # rest_x, sin el crawl lento que tenía antes.
@export var max_escape_dist: float = 4800.0  # distancia de escape en px (triple, para que el recorrido más largo venda más la sensación de velocidad al recuperar)
@export var rest_offset: float = 120.0       # px a la izquierda del PP en reposo; cámara tiene +384 offset → PP aparece en x=256 desde borde izq
@export var tilt_factor: float = 0.003
@export var tilt_max: float = 0.25
@export var tilt_speed: float = 4.0
@export var blink_speed: float = 1.5

var _target: Node2D
var _anim: AnimatedSprite2D
var _light_main: PointLight2D
var _light_fill: PointLight2D
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

var escaped: bool = false

# ── Sonido de movimiento: máquina de estados independiente de la física real
# del dron (ver _update_motion_sound) — QUIET/ACCEL/CRUISE/DECEL, con ACCEL y
# DECEL durando siempre 1 segundo fijo (SoundState.TRANSITION_DUR), sin importar
# la velocidad real. Simple a propósito: evita casos borde de sincronizar
# sonido con la física (rebotes, aceleración real, etc.).
enum SoundState { QUIET, ACCEL, CRUISE, DECEL }
const SOUND_TRANSITION_DUR := 1.0
const MOVING_THRESHOLD     := 1.0   # px de dir_x — por debajo, se considera "quieto" para el sonido
var _sound_state  := SoundState.QUIET
var _sound_timer  := 0.0
var _quiet_player: AudioStreamPlayer
var _accel_player: AudioStreamPlayer
var _cruise_player: AudioStreamPlayer
var _decel_player: AudioStreamPlayer
var _debug_timer := 0.0

func get_gap() -> float:
	if not _target: return 0.0
	return _target.global_position.x - global_position.x

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

	_light_main = PointLight2D.new()
	_light_main.texture = _make_cone_tex(256, 60.0)
	_light_main.color = Color(0.9, 0.95, 1.0)
	_light_main.energy = 5.0
	_light_main.texture_scale = 11.0
	_light_main.z_index = -1
	_light_main.visible = false
	add_child(_light_main)

	_light_fill = PointLight2D.new()
	_light_fill.texture = _make_light_tex(128)
	_light_fill.color = Color(0.85, 0.9, 1.0)
	_light_fill.energy = 1.8
	_light_fill.texture_scale = 18.0
	_light_fill.z_index = -1
	_light_fill.visible = false   # desactivada: solo quedan la roja y la azul
	add_child(_light_fill)

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

	_light_blue = PointLight2D.new()
	_light_blue.texture = _make_light_tex(64)
	_light_blue.color = Color(0.15, 0.4, 1.0)
	_light_blue.energy = 2.5
	_light_blue.texture_scale = 16.0
	_light_blue.position = Vector2(-210, -125)
	_light_blue.visible = false
	add_child(_light_blue)

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
		global_position = Vector2(_target.global_position.x - rest_offset, _target.global_position.y + offset_y)
		_cone_x = _target.global_position.x

	# Los 4 .wav vienen de la misma sesión de grabación, todos ~14.5-15dB por
	# debajo de 0dBFS de pico — el boost por archivo los lleva justo a 0dB de
	# pico (sin clipear) para que ninguno se escuche más fuerte que otro.
	_quiet_player  = _make_loop_player("res://assets/sounds/drone/drone_quieto.wav", 14.5)
	_accel_player  = _make_loop_player("res://assets/sounds/drone/drone_acelerar.wav", 15.0)
	_cruise_player = _make_loop_player("res://assets/sounds/drone/drone_crucero.wav", 14.9)
	_decel_player  = _make_loop_player("res://assets/sounds/drone/drone_desacelerar.wav", 15.0)

func _make_loop_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		player.stream = load(path)
		player.volume_db = volume_db
		player.finished.connect(func():
			if _sound_players()[_sound_state] == player: player.play()
		)
	add_child(player)
	return player

func _sound_players() -> Dictionary:
	return {
		SoundState.QUIET:  _quiet_player,
		SoundState.ACCEL:  _accel_player,
		SoundState.CRUISE: _cruise_player,
		SoundState.DECEL:  _decel_player,
	}

# Máquina de estados de sonido, totalmente aparte de la física del dron:
# QUIET -> (empieza a moverse) -> ACCEL (1s fijo) -> CRUISE (si sigue
# moviéndose) o QUIET (si ya se frenó) -> ... -> DECEL se dispara de forma
# PREDICTIVA: no cuando ya se detuvo, sino cuando a la distancia/velocidad
# actual, falta ~1 segundo para llegar a destino (time_to_rest, ver
# _process) -> DECEL dura ese mismo 1s fijo -> termina justo cuando el dron
# llega -> QUIET (o vuelve a ACCEL si el PP se alejó de nuevo antes de que
# termine ese segundo).
func _update_motion_sound(delta: float, is_moving: bool, time_to_rest: float) -> void:
	match _sound_state:
		SoundState.QUIET:
			if is_moving:
				_set_sound_state(SoundState.ACCEL)
		SoundState.CRUISE:
			if not is_moving:
				_set_sound_state(SoundState.QUIET)
			elif time_to_rest <= SOUND_TRANSITION_DUR:
				_set_sound_state(SoundState.DECEL)
		SoundState.ACCEL:
			_sound_timer -= delta
			if _sound_timer <= 0.0:
				if not is_moving:
					_set_sound_state(SoundState.QUIET)
				elif time_to_rest <= SOUND_TRANSITION_DUR:
					_set_sound_state(SoundState.DECEL)
				else:
					_set_sound_state(SoundState.CRUISE)
		SoundState.DECEL:
			if time_to_rest > SOUND_TRANSITION_DUR:
				_set_sound_state(SoundState.ACCEL)
			else:
				_sound_timer -= delta
				if _sound_timer <= 0.0:
					_set_sound_state(SoundState.QUIET)

func _set_sound_state(new_state: SoundState) -> void:
	var players := _sound_players()
	var old_player: AudioStreamPlayer = players[_sound_state]
	var new_player: AudioStreamPlayer = players[new_state]
	if old_player != new_player and old_player.playing: old_player.stop()
	_sound_state = new_state
	_sound_timer = SOUND_TRANSITION_DUR
	if new_player.stream and not new_player.playing: new_player.play()

func _process(delta: float) -> void:
	if not _target: return
	if escaped:
		var p: AudioStreamPlayer = _sound_players()[_sound_state]
		if p.playing: p.stop()
		return

	# Persecución bidireccional: el dron mantiene rest_offset px a la izquierda
	# del PP, viajando hasta drone_speed a fondo — movimiento simple, sin rampa
	# física (el sonido de arranque/frenado es un timer aparte, ver
	# _update_motion_sound, no está atado a esto).
	var rest_x := _target.global_position.x - rest_offset
	var dir_x := rest_x - global_position.x
	var move_step := clampf(dir_x, -drone_speed * delta, drone_speed * delta)
	global_position.x += move_step

	# Tiempo estimado hasta llegar a rest_x a la velocidad actual — es lo que
	# dispara DECEL de forma predictiva (ver _update_motion_sound), no recién
	# cuando ya está parado.
	var time_to_rest := absf(dir_x) / drone_speed if drone_speed > 0.0 else 0.0
	_update_motion_sound(delta, absf(dir_x) >= MOVING_THRESHOLD, time_to_rest)

	_debug_timer += delta
	if _debug_timer >= 1.0:
		_debug_timer = 0.0
		print("[drone] state=%s dir_x=%.2f" % [SoundState.keys()[_sound_state], dir_x])

	# Escape: si el PP logra alejarse max_escape_dist del dron
	var gap := get_gap()
	if gap >= max_escape_dist:
		escaped = true
		return

	# Y: sigue la altura del PP suavemente
	var target_y := _target.global_position.y + offset_y
	global_position.y = lerpf(global_position.y, target_y, 3.0 * delta)

	# Tilt según velocidad horizontal
	var target_tilt := clampf((move_step / delta) * tilt_factor, -tilt_max, tilt_max)
	_anim.rotation = lerpf(_anim.rotation, target_tilt, tilt_speed * delta)

	# Bob
	_bob_timer += delta
	var bob_y := sin(_bob_timer * 1.2) * 6.0
	_anim.position.y = bob_y
	_light_red.position.y = -120.0 + bob_y
	_light_red_mid.position.y = -120.0 + bob_y
	_light_blue.position.y = -125.0 + bob_y
	_light_blue_mid.position.y = -125.0 + bob_y

	# Blink rojo/azul
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

	# Spotlight apuntando al PP con inercia
	_cone_vel += (_target.global_position.x - _cone_x) * 28.0 * delta
	_cone_vel *= maxf(0.0, 1.0 - 9.0 * delta)
	_cone_x += _cone_vel * delta
	var dx := _cone_x - global_position.x
	var dy := (_target.global_position.y + 20.0) - global_position.y
	_light_main.rotation = Vector2(dx, dy).angle() - PI / 2.0
