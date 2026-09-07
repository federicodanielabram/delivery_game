extends Node2D

@export var parallax: float = 1.2
const FLOOR_Y:        int   = 655
const ALPHA_THRESHOLD: int  = 10
const LOOKAHEAD:      float = 2000.0
const CLEANUP_BEHIND: float = 2000.0

var _base_x:      Array = []
var _sprites:     Array = []
var _bounds_cache: Dictionary = {}

var _textures:   Array = []
var _rng:        RandomNumberGenerator = null
var _gen_head_x: float = 0.0
var _stop_x:     float = -1.0   # -1 = infinito; ver stop_at()

# x donde se plantó el edificio de la pizzeria (fin de nivel) — 0 si todavía no apareció
var pizzeria_base_x: float = 0.0

func stop_at(x: float) -> void:
	_stop_x = x

# Genera edificios comunes en secuencia hasta cubrir target_x, sin depender
# de la cámara — para "ponerse al día" antes de plantar un landmark (la
# pizzeria) y que no quede un hueco vacío justo antes.
func fill_to(target_x: float) -> void:
	while _gen_head_x < target_x:
		_gen_head_x = _spawn_building(_gen_head_x)

# Genera exactamente `count` edificios comunes en secuencia arrancando en
# start_x. Devuelve el borde derecho del último — para plantar un puñado fijo
# de edificios justo después de un landmark (la pizzeria), y que el fondo no
# corte en seco ahí mismo.
func spawn_n_buildings(start_x: float, count: int) -> float:
	var x := start_x
	for i in count:
		x = _spawn_building(x)
	_gen_head_x = maxf(_gen_head_x, x)
	return x

# Planta el edificio de la pizzeria CENTRADO en center_x — SIEMPRE ahí, exacto,
# sin excepción (no es negociable: es el landmark de fin de nivel, no un
# edificio procedural más). Si algún edificio común ya generado le pisa el
# lugar (puede pasar: fill_to() u otra generación previa no son exactos, se
# pasan de largo), se lo elimina — la pizzeria nunca se corre para acomodarlo.
# Corta la generación de edificios genéricos a partir de ahí (level1.gd llama
# a stop_at() después). Devuelve el borde derecho real del edificio, para
# poder acomodar cosas como los faroles justo después.
const PIZZERIA_SCALE  := 0.5   # el PNG (2172×724) es mucho más grande que un edificio
								# común (500×500) — a mitad de tamaño queda a la altura del resto
const PIZZERIA_Y_OFFSET := 10.0   # ajuste manual pedido: la pizzeria queda 10px más abajo (Y crece hacia abajo)

func spawn_pizzeria(center_x: float) -> float:
	var tex: Texture2D = load("res://assets/buildings/pizzeria.png")
	var s := PIZZERIA_SCALE
	if not tex:
		pizzeria_base_x = center_x
		return center_x
	var bounds := _content_bounds(tex)
	var content_w := bounds.size.x * s
	var place_x := center_x - content_w * 0.5
	_remove_overlapping(place_x, place_x + content_w)
	var sp := Sprite2D.new()
	sp.texture  = tex
	sp.centered = false
	sp.scale    = Vector2(s, s)
	sp.position = Vector2(place_x - bounds.position.x * s, FLOOR_Y - tex.get_height() * s + PIZZERIA_Y_OFFSET)
	# self_modulate (a diferencia de modulate) no cascadea a hijos, pero SÍ se
	# sigue multiplicando con el tinte nocturno de BuildingsLayer (buildings_night,
	# ver level1.gd _ready) — este boost la deja apenas más iluminada que sus
	# vecinos genéricos, para que se note que es el landmark sin saltar del todo.
	sp.self_modulate = Color(1.25, 1.2, 1.1, 1.0)
	add_child(sp)
	# Entra en _base_x/_sprites como cualquier edificio más — se mueve al
	# mismo ritmo de parallax que los edificios frontales que la rodean
	# (level1.gd ya le pasa un center_x compensado para que, en el instante
	# en que la cámara se traba, caiga centrada en la pantalla).
	_base_x.append(place_x - bounds.position.x * s)
	_sprites.append(sp)
	pizzeria_base_x = place_x
	var right_edge := place_x + content_w - 15.0
	_gen_head_x = maxf(_gen_head_x, right_edge)
	return right_edge

# Saca cualquier edificio común ya generado cuyo rango se meta en [left, right]
# — usado para garantizar que nada le pise el lugar reservado a la pizzeria.
func _remove_overlapping(left: float, right: float) -> void:
	var i := 0
	while i < _sprites.size():
		var sp := _sprites[i] as Sprite2D
		if not is_instance_valid(sp) or not sp.texture:
			i += 1
			continue
		var b := _content_bounds(sp.texture)
		var sp_left  := float(_base_x[i])
		var sp_right := sp_left + b.size.x * sp.scale.x
		if sp_right > left and sp_left < right:
			sp.queue_free()
			_sprites.remove_at(i)
			_base_x.remove_at(i)
		else:
			i += 1

func _ready() -> void:
	var paths := [
		"res://assets/buildings/e1.png",
		"res://assets/buildings/e2.png",
		"res://assets/buildings/e3.png",
		"res://assets/buildings/e4.png",
		"res://assets/buildings/e5.png",
		"res://assets/buildings/e6.png",
		"res://assets/buildings/e7.png",
		"res://assets/buildings/e8.png",
	]
	for p in paths:
		var t = load(p)
		if t: _textures.append(t)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 13
	_gen_head_x = 0.0
	_fill_buildings(0.0)

func _spawn_building(x: float) -> float:
	var tex: Texture2D = _textures[_rng.randi() % _textures.size()]
	var bounds := _content_bounds(tex)
	if bounds.size.x <= 0:
		return x + 200.0
	var sp := Sprite2D.new()
	sp.texture  = tex
	sp.centered = false
	sp.position = Vector2(x - bounds.position.x, FLOOR_Y - tex.get_height())
	add_child(sp)
	_base_x.append(x - bounds.position.x)
	_sprites.append(sp)
	return x + bounds.size.x - 15

func _fill_buildings(cam_x: float) -> void:
	var target_x := cam_x * parallax + LOOKAHEAD
	if _stop_x >= 0.0:
		target_x = minf(target_x, _stop_x)
	while _gen_head_x < target_x:
		_gen_head_x = _spawn_building(_gen_head_x)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var cam_x        := cam.get_screen_center_position().x
	var world_offset := cam_x * (1.0 - parallax)

	for i in range(_sprites.size()):
		(_sprites[i] as Sprite2D).global_position.x = _base_x[i] + world_offset

	if _gen_head_x < cam_x * parallax + LOOKAHEAD:
		_fill_buildings(cam_x)

	var cutoff := cam_x * parallax - CLEANUP_BEHIND
	var i := 0
	while i < _base_x.size():
		if _base_x[i] < cutoff:
			(_sprites[i] as Node).queue_free()
			_base_x.remove_at(i)
			_sprites.remove_at(i)
		else:
			i += 1

func _content_bounds(tex: Texture2D) -> Rect2i:
	var key := tex.resource_path
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var left  := w
	var right := 0
	for y in range(h):
		for px in range(w):
			if img.get_pixel(px, y).a8 > ALPHA_THRESHOLD:
				if px < left:  left  = px
				if px > right: right = px
	var result := Rect2i(0, 0, w, h) if right < left else Rect2i(left, 0, right - left + 1, h)
	_bounds_cache[key] = result
	return result
