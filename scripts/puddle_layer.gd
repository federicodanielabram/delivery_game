extends Node2D

@export var parallax: float = 1.2
@export var puddle_count: int = 16
@export var scale_min: float = 0.22
@export var scale_max: float = 0.45
@export var alpha: float = 0.75

const LEVEL_WIDTH: int = 32000
const FLOOR_Y_MIN: int = 658
const FLOOR_Y_MAX: int = 710
const COLS: int = 3
const ROWS: int = 4
const FRAME_W: int = 341
const FRAME_H: int = 256
const MIN_GAP: float = 300.0   # separación mínima centro-a-centro: evita que se encimen

var _base_x: Array = []
var _sprites: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 42

	var sheet: Texture2D = load("res://assets/sprites/puddles/puddles.png")
	if not sheet:
		return

	for i in range(puddle_count):
		var frame_idx := _rng.randi_range(0, COLS * ROWS - 1)
		var col := frame_idx % COLS
		var row := frame_idx / COLS

		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
		atlas.filter_clip = true

		var sp := Sprite2D.new()
		sp.texture = atlas
		sp.centered = true

		var px := _pick_spaced_x(0.0, LEVEL_WIDTH)
		var py := _rng.randf_range(float(FLOOR_Y_MIN), float(FLOOR_Y_MAX))

		var depth := (py - FLOOR_Y_MIN) / (FLOOR_Y_MAX - FLOOR_Y_MIN)
		var sc := lerpf(scale_min, scale_max, depth)
		sp.scale = Vector2(sc, sc * 0.5)
		sp.position = Vector2(px, py)
		sp.z_index = 1
		# Charcos: tinte oscuro azulado semi-transparente sobre el piso
		sp.modulate = Color(0.30, 0.32, 0.42, 0.70)
		add_child(sp)

		_base_x.append(px)
		_sprites.append(sp)

# Busca una posición con al menos MIN_GAP de separación de los charcos ya
# ubicados; si no encuentra ninguna candidata perfecta en unos intentos, se
# queda con la mejor (más separada) que haya salido — mejor esfuerzo, nunca bloquea.
func _pick_spaced_x(range_min: float, range_max: float) -> float:
	const TRIES := 12
	var best_x := _rng.randf_range(range_min, range_max)
	var best_gap := _min_gap_to_others(best_x)
	for i in range(TRIES - 1):
		if best_gap >= MIN_GAP:
			break
		var cand := _rng.randf_range(range_min, range_max)
		var gap := _min_gap_to_others(cand)
		if gap > best_gap:
			best_gap = gap
			best_x = cand
	return best_x

func _min_gap_to_others(x: float) -> float:
	var min_gap := INF
	for bx in _base_x:
		min_gap = minf(min_gap, absf(x - bx))
	return min_gap

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var world_offset := cam.get_screen_center_position().x * (1.0 - parallax)

	var cam_base := cam.get_screen_center_position().x * parallax
	for i in range(_sprites.size()):
		var new_x: float = _base_x[i] + world_offset
		(_sprites[i] as Sprite2D).global_position.x = new_x
		# Reciclar charcos que quedaron atrás
		if _base_x[i] < cam_base - 1500.0:
			_base_x[i] = _pick_spaced_x(cam_base + 800.0, cam_base + 2500.0)
