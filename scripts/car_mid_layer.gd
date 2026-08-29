extends Node2D

@export var car_scale:  float = 0.2782   # 553px target / 1392px body * 0.7
@export var parallax:   float = 1.275

const LEVEL_WIDTH:  int   = 32000
const FRAME_COUNT:       int = 8
const FRAME_COUNT_NEW:   int = 9
const FLOOR_Y:      float = 735.0
const MIN_DIST:     float = 600.0

# Ritmo tipo dino con dificultad progresiva (t=0 inicio → t=1 final del nivel)
# Todos los gaps usan curva ease-in (t²): arranque muy cómodo, cierre más exigente.
const START_X: float = 2500.0   # primer obstáculo: el jugador ya arrancó a correr

# Gap borde-a-borde DENTRO de un grupo (entre autos consecutivos)
const INNER_GAP_EASY_MIN: float = 700.0   # t=0: 1.44s — muy holgado, aprendizaje
const INNER_GAP_EASY_MAX: float = 1000.0
const INNER_GAP_HARD_MIN: float = 180.0   # t=1: 0.37s — ajustado, requiere timing
const INNER_GAP_HARD_MAX: float = 350.0

# Gap borde-a-borde ENTRE grupos (respiro)
const BREATH_GAP_EASY_MIN: float = 3000.0  # t=0: 6.2s — mucho respiro
const BREATH_GAP_EASY_MAX: float = 5000.0
const BREATH_GAP_HARD_MIN: float = 1200.0  # t=1: 2.5s — respiro justo
const BREATH_GAP_HARD_MAX: float = 2200.0

# Probabilidades de tamaño de grupo [solo, par, trío] — se interpolan con t
const GROUP_PROB_EASY: Array = [0.85, 0.13, 0.02]  # casi siempre autos solos
const GROUP_PROB_HARD: Array = [0.35, 0.45, 0.20]  # grupos frecuentes al final

# Anchos reales de carrocería en px de mundo (canvas_span * scale * mult)
# Calculados de los contornos: primer→último índice no-cero × CONTOUR_STEP × scale × mult
const GROUND_BODY_W: Dictionary = {
	0: 383.0,   # ~sedan largo
	1: 374.0,
	2: 356.0,
	3: 374.0,
	4: 356.0,
	5: 365.0,
	6: 389.0,   # frame 6 tiene GROUND_SCALE_MULT=1.15 → 338×1.15
	7: 383.0,
}
const AERIAL_BODY_W: Dictionary = {
	0: 347.0,
	1: 294.0,   # el más corto
	2: 347.0,
	3: 417.0,   # furgón/camioneta — el más largo (mult 1.30)
	4: 348.0,   # mult 1.15 incluido
	5: 329.0,
	6: 347.0,
	7: 321.0,
	8: 347.0,
}

const CAR_CANVAS_W: float = 1424.0
const CAR_CANVAS_H: float = 642.0

# Autos aéreos
const AERIAL_Y:       float = 650.0   # altura base (pecho del PP); ajustar si hace falta
const AERIAL_BOB_AMP: float = 6.0     # ±px de oscilación vertical
const AERIAL_BOB_FREQ: float = 0.22   # Hz — muy lento, suspendido en el aire

# Escala individual por frame (multiplicador sobre car_scale)
const AERIAL_SCALE_MULT: Dictionary = {
	3: 1.30,
	4: 1.15,
}
const GROUND_SCALE_MULT: Dictionary = {
	6: 1.15,
}

# Contorno superior por frame: alturas desde el fondo del canvas (px), una por cada
# CAR_CONTOUR_STEP píxeles de canvas. Generado por tools/analyze_car_contour.js
const CAR_CONTOUR_STEP: float = 16.0
const CONTOUR_LIFT:     float = 40.0   # sube la superficie sin cambiar la forma
const CAR_CONTOURS: Dictionary = {
	0: [0, 295, 321, 336, 384, 394, 400, 402, 405, 408, 410, 414, 416, 420, 422, 425, 428, 431, 434, 436, 439, 442, 444, 445, 447, 449, 451, 453, 456, 458, 460, 462, 464, 465, 467, 468, 470, 472, 473, 474, 475, 476, 477, 478, 478, 478, 477, 474, 471, 466, 461, 456, 451, 445, 440, 434, 428, 422, 415, 409, 403, 397, 390, 385, 379, 374, 370, 366, 363, 359, 356, 352, 347, 343, 338, 333, 329, 324, 318, 312, 306, 298, 290, 281, 272, 258, 252, 245, 0],
	1: [0, 0, 294, 308, 316, 347, 349, 350, 350, 351, 351, 352, 351, 352, 353, 355, 358, 363, 368, 373, 378, 383, 387, 391, 395, 399, 403, 406, 409, 411, 414, 415, 416, 417, 418, 419, 419, 419, 419, 419, 418, 418, 417, 415, 413, 410, 406, 402, 396, 390, 384, 377, 370, 363, 356, 348, 340, 331, 323, 315, 308, 303, 299, 296, 293, 291, 289, 287, 284, 281, 278, 275, 271, 267, 263, 258, 253, 247, 241, 234, 227, 219, 208, 185, 154, 140, 119, 0, 0],
	2: [0, 0, 0, 0, 417, 421, 423, 432, 436, 451, 474, 499, 526, 551, 566, 578, 589, 600, 610, 619, 623, 625, 625, 624, 624, 624, 624, 624, 624, 624, 624, 624, 624, 625, 625, 625, 625, 624, 624, 624, 624, 624, 624, 624, 624, 624, 624, 623, 618, 610, 601, 590, 577, 564, 549, 533, 514, 494, 474, 454, 438, 424, 412, 403, 398, 393, 389, 387, 386, 384, 382, 379, 377, 374, 372, 370, 367, 364, 362, 358, 354, 346, 318, 309, 295, 0, 0, 0, 0],
	3: [0, 0, 457, 456, 454, 452, 449, 444, 439, 433, 412, 392, 375, 360, 348, 351, 354, 358, 362, 366, 370, 375, 379, 384, 388, 392, 396, 400, 404, 407, 410, 413, 415, 417, 418, 420, 420, 421, 421, 421, 421, 420, 418, 417, 415, 412, 408, 404, 399, 393, 387, 381, 375, 368, 360, 352, 344, 336, 328, 320, 313, 308, 304, 300, 297, 294, 291, 288, 285, 282, 279, 275, 272, 268, 264, 259, 254, 247, 240, 232, 224, 215, 205, 186, 159, 147, 131, 0, 0],
	4: [0, 0, 0, 0, 416, 458, 485, 563, 587, 596, 600, 602, 603, 603, 604, 605, 605, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 605, 605, 604, 604, 604, 604, 603, 603, 602, 602, 602, 602, 602, 602, 602, 601, 599, 598, 596, 595, 592, 589, 584, 577, 564, 551, 535, 518, 500, 485, 471, 456, 442, 431, 420, 409, 400, 392, 384, 377, 370, 364, 359, 354, 348, 342, 335, 308, 300, 287, 0, 0, 0, 0],
	5: [0, 0, 0, 278, 292, 300, 330, 336, 340, 344, 353, 372, 395, 417, 435, 447, 440, 430, 422, 418, 416, 424, 432, 439, 446, 451, 456, 460, 463, 465, 467, 468, 469, 470, 470, 471, 471, 472, 472, 472, 472, 471, 470, 468, 466, 464, 462, 460, 459, 454, 448, 442, 434, 424, 417, 409, 402, 394, 385, 376, 366, 358, 350, 343, 338, 335, 332, 330, 328, 325, 323, 320, 317, 315, 312, 308, 304, 299, 292, 286, 278, 269, 254, 238, 230, 219, 0, 0, 0],
	6: [0, 0, 0, 0, 0, 0, 343, 397, 432, 512, 557, 577, 583, 586, 587, 588, 588, 589, 589, 589, 589, 589, 588, 588, 588, 588, 589, 589, 590, 590, 589, 589, 589, 588, 589, 589, 589, 589, 590, 590, 590, 590, 590, 589, 588, 588, 587, 586, 585, 583, 581, 578, 574, 570, 566, 560, 552, 542, 530, 517, 504, 492, 480, 467, 455, 442, 430, 419, 410, 400, 392, 385, 377, 369, 363, 356, 350, 343, 336, 321, 294, 284, 268, 0, 0, 0, 0, 0, 0],
	7: [0, 365, 366, 366, 367, 366, 355, 345, 337, 329, 323, 328, 334, 340, 345, 348, 351, 354, 357, 361, 365, 371, 379, 387, 395, 402, 408, 412, 416, 420, 424, 428, 430, 432, 433, 434, 433, 431, 430, 428, 424, 420, 416, 410, 402, 395, 386, 377, 368, 358, 349, 341, 335, 330, 327, 324, 322, 320, 318, 317, 318, 319, 319, 321, 321, 319, 317, 314, 309, 301, 293, 301, 309, 319, 331, 344, 341, 334, 326, 314, 300, 284, 270, 255, 241, 216, 207, 195, 0],
}

# ── Tipos de obstáculo ────────────────────────────────────────────────────────
const OBS_GROUND := 0   # auto en el piso
const OBS_AERIAL := 1   # auto aéreo
const OBS_BUS    := 2   # colectivo (techo transitable)
const OBS_COP    := 3   # policía (1 golpe si es jump+kick o slide)

# Probabilidades fijas por tipo (suman 1.0)
const OBS_PROB_GROUND: float = 0.44
const OBS_PROB_AERIAL: float = 0.28
const OBS_PROB_BUS:    float = 0.08
# Cop: 0.20 (el resto)

# ── Colectivos (buses) ────────────────────────────────────────────────────────
const BUS_DATA: Array = [
	{"cw": 1007.0, "ch": 400.0, "body_h": 320.0},  # bus_01
	{"cw": 1007.0, "ch": 386.0, "body_h": 309.0},  # bus_02
	{"cw": 1009.0, "ch": 394.0, "body_h": 315.0},  # bus_03
]
const BUS_SCALE:       float = 0.588
const BUS_FLOOR_Y:     float = 695.0
const BUS_ROOF_OFFSET: float = 15.0

# ── Policía ───────────────────────────────────────────────────────────────────
const COP_SCENE := preload("res://scenes/enemies/Cop.tscn")
const COP_W:     float = 200.0   # ancho aproximado para cálculo de gaps

const CAR_CONTOURS_NEW: Dictionary = {
	0: [0, 0, 0, 0, 0, 320, 330, 337, 355, 364, 367, 370, 373, 375, 378, 381, 383, 385, 388, 390, 392, 394, 397, 399, 402, 405, 407, 410, 411, 413, 415, 417, 419, 420, 422, 424, 426, 426, 427, 428, 429, 429, 431, 431, 431, 430, 428, 425, 421, 417, 411, 405, 399, 393, 386, 379, 372, 364, 357, 350, 343, 336, 329, 323, 317, 311, 306, 302, 298, 294, 290, 286, 282, 278, 273, 268, 262, 256, 249, 241, 231, 218, 211, 203, 0, 0, 0, 0, 0],
	1: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 252, 268, 282, 320, 350, 378, 414, 445, 473, 486, 499, 499, 499, 500, 499, 499, 488, 478, 469, 460, 451, 453, 454, 454, 454, 453, 453, 452, 452, 451, 451, 451, 452, 452, 452, 448, 443, 437, 428, 419, 411, 401, 391, 381, 369, 357, 345, 334, 325, 316, 310, 305, 300, 297, 294, 290, 287, 283, 278, 273, 267, 259, 250, 234, 210, 200, 187, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	2: [0, 0, 0, 0, 0, 276, 289, 297, 330, 330, 329, 329, 328, 328, 327, 325, 322, 320, 318, 318, 320, 324, 329, 333, 337, 340, 343, 347, 350, 353, 356, 359, 360, 361, 362, 362, 363, 363, 363, 363, 362, 360, 358, 355, 351, 346, 341, 336, 331, 326, 320, 314, 307, 300, 292, 285, 278, 271, 265, 260, 257, 255, 253, 252, 250, 248, 245, 243, 240, 237, 234, 230, 225, 221, 215, 209, 203, 197, 190, 182, 170, 156, 150, 141, 0, 0, 0, 0, 0],
	3: [0, 0, 0, 0, 0, 0, 0, 0, 243, 272, 295, 346, 373, 398, 415, 428, 439, 449, 457, 467, 475, 483, 488, 492, 491, 487, 484, 481, 477, 475, 475, 475, 475, 475, 474, 474, 473, 473, 473, 474, 474, 474, 471, 468, 464, 461, 458, 458, 459, 459, 461, 462, 461, 461, 460, 459, 457, 457, 457, 457, 462, 469, 478, 486, 483, 474, 460, 444, 427, 420, 411, 400, 385, 367, 347, 325, 305, 279, 240, 223, 203, 0, 0, 0, 0, 0, 0, 0, 0],
	4: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 288, 311, 329, 386, 405, 427, 444, 463, 477, 489, 492, 498, 499, 497, 486, 475, 468, 460, 454, 457, 460, 460, 460, 460, 460, 460, 459, 457, 454, 451, 448, 445, 444, 444, 444, 444, 445, 446, 446, 447, 447, 446, 446, 445, 444, 446, 446, 442, 437, 428, 414, 400, 387, 373, 360, 346, 333, 319, 307, 294, 281, 268, 255, 241, 227, 211, 189, 179, 168, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	5: [0, 0, 0, 0, 0, 0, 0, 233, 252, 268, 310, 336, 358, 378, 394, 410, 417, 423, 428, 434, 434, 433, 434, 447, 459, 459, 460, 459, 445, 446, 448, 448, 448, 451, 443, 447, 453, 459, 462, 463, 463, 462, 462, 460, 450, 441, 428, 414, 399, 390, 379, 369, 359, 348, 338, 326, 315, 304, 294, 285, 277, 271, 266, 262, 259, 257, 254, 251, 249, 246, 243, 239, 235, 230, 225, 220, 213, 205, 192, 175, 167, 157, 0, 0, 0, 0, 0, 0, 0],
	6: [0, 0, 0, 0, 0, 251, 263, 271, 298, 302, 306, 310, 316, 322, 330, 338, 347, 355, 373, 390, 400, 407, 414, 411, 408, 413, 420, 426, 432, 437, 439, 440, 440, 440, 441, 441, 443, 455, 467, 478, 490, 499, 499, 497, 485, 473, 461, 448, 432, 425, 417, 407, 397, 389, 381, 371, 361, 351, 340, 329, 319, 310, 301, 294, 289, 285, 282, 279, 277, 274, 271, 268, 265, 262, 258, 254, 249, 244, 237, 229, 214, 196, 187, 175, 0, 0, 0, 0, 0],
	7: [0, 0, 0, 0, 0, 0, 0, 0, 212, 246, 289, 348, 407, 443, 469, 476, 483, 489, 495, 499, 501, 501, 501, 501, 496, 492, 487, 483, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 477, 477, 477, 477, 476, 476, 476, 474, 473, 471, 470, 468, 465, 458, 450, 440, 427, 412, 401, 387, 374, 359, 345, 331, 316, 303, 289, 275, 261, 246, 219, 208, 195, 0, 0, 0, 0, 0, 0, 0, 0],
	8: [0, 0, 0, 0, 0, 302, 308, 311, 325, 323, 320, 317, 312, 305, 301, 298, 297, 298, 302, 307, 311, 315, 319, 323, 327, 331, 335, 338, 341, 344, 346, 348, 349, 349, 349, 349, 349, 349, 349, 349, 346, 343, 338, 332, 325, 319, 313, 306, 299, 292, 284, 276, 268, 260, 253, 248, 244, 241, 238, 237, 237, 236, 235, 233, 231, 227, 224, 221, 218, 214, 210, 205, 197, 188, 181, 174, 168, 161, 153, 141, 123, 97, 85, 71, 0, 0, 0, 0, 0],
}

var _rng     := RandomNumberGenerator.new()
var _base_x:  Array = []
var _bodies:  Array = []
var _aerial_base_x:   Array = []
var _aerial_bodies:   Array = []
var _aerial_phases:   Array = []
var _aerial_shadows:  Array = []
var _bus_base_x:  Array = []
var _bus_bodies:  Array = []
var _cop_base_x:  Array = []
var _cop_nodes:   Array = []

func get_placed_x() -> Array:
	return _base_x

func _ready() -> void:
	_rng.randomize()
	z_index = 2   # detrás del player (z=3), delante del fondo

	var sc := car_scale
	var shadow_tex: Texture2D = load("res://assets/sprites/cars/side_test/car_side_06 - copia.png")

	var bus_textures: Array = []
	for i in range(1, BUS_DATA.size() + 1):
		bus_textures.append(load("res://assets/sprites/buses/bus_0%d.png" % i))

	var obstacles := _generate_obstacles()
	for obs: Dictionary in obstacles:
		var px: float = obs.x
		var fi: int   = obs.frame

		match obs.type:
			OBS_GROUND:
				var tex: Texture2D = load("res://assets/sprites/cars/side_test/car_side_%02d.png" % fi)
				if not tex: continue
				var frame_sc := sc * float(GROUND_SCALE_MULT.get(fi, 1.0))
				var body := StaticBody2D.new()
				body.position = Vector2(px, FLOOR_Y)
				var sp := Sprite2D.new()
				sp.texture  = tex
				sp.centered = false
				sp.scale    = Vector2(frame_sc, frame_sc)
				sp.position = Vector2(-CAR_CANVAS_W * frame_sc * 0.5, -CAR_CANVAS_H * frame_sc)
				body.add_child(sp)
				_add_contour_collision(body, fi, frame_sc)
				body.add_to_group("car_obstacle")
				add_child(body)
				_base_x.append(px)
				_bodies.append(body)

			OBS_AERIAL:
				var tex: Texture2D = load("res://assets/sprites/cars/side_chatgpt/car_side_%02d.png" % fi)
				if not tex: continue
				var frame_sc := sc * float(AERIAL_SCALE_MULT.get(fi, 1.0))
				var body := StaticBody2D.new()
				body.position = Vector2(px, AERIAL_Y)
				var sp := Sprite2D.new()
				sp.texture  = tex
				sp.centered = false
				sp.scale    = Vector2(frame_sc, frame_sc)
				sp.position = Vector2(-CAR_CANVAS_W * frame_sc * 0.5, -CAR_CANVAS_H * frame_sc)
				body.add_child(sp)
				_add_contour_collision_new(body, fi, frame_sc)
				body.collision_layer = 8
				body.z_as_relative   = false
				body.z_index         = 4
				body.add_to_group("car_obstacle")
				add_child(body)
				_aerial_base_x.append(px)
				_aerial_bodies.append(body)
				_aerial_phases.append(_rng.randf_range(0.0, TAU))
				if shadow_tex:
					var sh := Sprite2D.new()
					sh.texture  = shadow_tex
					sh.centered = false
					sh.scale    = Vector2(sc, sc)
					add_child(sh)
					_aerial_shadows.append(sh)

			OBS_BUS:
				var d: Dictionary = BUS_DATA[fi]
				var cw: float = d.cw
				var ch: float = d.ch
				var bh: float = d.body_h
				var bsc: float = BUS_SCALE
				var shadow_h: float = ch - bh
				var tex: Texture2D = bus_textures[fi]
				if not tex: continue
				var body := StaticBody2D.new()
				body.position      = Vector2(px, BUS_FLOOR_Y + shadow_h * bsc)
				body.collision_layer = 1
				body.collision_mask  = 0
				add_child(body)
				var sp := Sprite2D.new()
				sp.texture  = tex
				sp.centered = false
				sp.scale    = Vector2(bsc, bsc)
				sp.position = Vector2(-cw * bsc * 0.5, -ch * bsc)
				body.add_child(sp)
				var col   := CollisionShape2D.new()
				var shape := RectangleShape2D.new()
				shape.size = Vector2(cw * bsc * 0.80, 6.0)
				col.shape             = shape
				col.one_way_collision = true
				col.position          = Vector2(0.0, -(ch - BUS_ROOF_OFFSET) * bsc)
				body.add_child(col)
				_bus_base_x.append(px)
				_bus_bodies.append(body)

			OBS_COP:
				var cop := COP_SCENE.instantiate() as Node2D
				cop.position = Vector2(px, 600.0)
				cop.set("obstacle_mode", true)
				cop.set("hp", 1)
				add_child(cop)
				_cop_base_x.append(px)
				_cop_nodes.append(cop)

func _build_car_polygon(raw: Array, sc: float) -> CollisionPolygon2D:
	var first := -1
	var last  := -1
	for i in range(raw.size()):
		if raw[i] > 0:
			if first == -1: first = i
			last = i
	if first == -1 or last <= first:
		return null

	# Promedio móvil — suaviza micro-escalones sin perder la forma
	const SMOOTH_RADIUS := 2
	var sm: Array = raw.duplicate()
	for i in range(first, last + 1):
		if int(raw[i]) == 0:
			continue
		var sum := 0.0
		var cnt := 0
		for j in range(maxi(first, i - SMOOTH_RADIUS), mini(last + 1, i + SMOOTH_RADIUS + 1)):
			if int(raw[j]) > 0:
				sum += float(raw[j])
				cnt += 1
		sm[i] = int(round(sum / float(cnt))) if cnt > 0 else 0

	# Altura mínima del contorno suavizado — base del polígono (evita paredes largas invisibles)
	var min_h := 999999
	for i in range(first, last + 1):
		var h: int = int(sm[i])
		if h > 0 and h < min_h:
			min_h = h
	var base_y: float = -float(min_h) * sc   # sin CONTOUR_LIFT: el piso toca el visual real

	var left_x: float  = float(first) * CAR_CONTOUR_STEP * sc - CAR_CANVAS_W * sc * 0.5
	var right_x: float = float(last)  * CAR_CONTOUR_STEP * sc - CAR_CANVAS_W * sc * 0.5

	# Polígono cerrado: base-izq → contorno superior izq→der → base-der
	var poly := PackedVector2Array()
	poly.append(Vector2(left_x, base_y))
	for i in range(first, last + 1):
		var h: int = int(sm[i])
		if h > 0:
			poly.append(Vector2(
				float(i) * CAR_CONTOUR_STEP * sc - CAR_CANVAS_W * sc * 0.5,
				-float(h) * sc))
	poly.append(Vector2(right_x, base_y))

	var col_poly := CollisionPolygon2D.new()
	col_poly.polygon = poly
	return col_poly

func _add_contour_collision(body: StaticBody2D, frame_idx: int, sc: float) -> void:
	var raw: Array = CAR_CONTOURS.get(frame_idx, [])
	var col_poly := _build_car_polygon(raw, sc)
	if col_poly:
		body.add_child(col_poly)

func _add_contour_collision_new(body: StaticBody2D, frame_idx: int, sc: float) -> void:
	var raw: Array = CAR_CONTOURS_NEW.get(frame_idx, [])
	var col_poly := _build_car_polygon(raw, sc)
	if col_poly:
		body.add_child(col_poly)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var offset := cam.get_screen_center_position().x * (1.0 - parallax)

	for i in range(_bodies.size()):
		var body: Node2D = _bodies[i] as Node2D
		body.global_position.x = _base_x[i] + offset

	var t  := Time.get_ticks_msec() / 1000.0
	var sc := car_scale
	for i in range(_aerial_bodies.size()):
		var body: Node2D = _aerial_bodies[i] as Node2D
		body.global_position.x = _aerial_base_x[i] + offset
		body.global_position.y = AERIAL_Y + sin(t * AERIAL_BOB_FREQ * TAU + _aerial_phases[i]) * AERIAL_BOB_AMP
		# Sombra fija en el piso, sincronizada en X
		if i < _aerial_shadows.size():
			var sh: Sprite2D = _aerial_shadows[i] as Sprite2D
			sh.global_position.x = _aerial_base_x[i] + offset - CAR_CANVAS_W * sc * 0.5
			sh.global_position.y = FLOOR_Y - CAR_CANVAS_H * sc

	for i in range(_bus_bodies.size()):
		(_bus_bodies[i] as Node2D).global_position.x = _bus_base_x[i] + offset

	for i in range(_cop_nodes.size()):
		(_cop_nodes[i] as Node2D).global_position.x = _cop_base_x[i] + offset

# Devuelve Array de dicts {x, type, frame, width}
# Dificultad progresiva: t = posición normalizada (0→1), curva t²
func _generate_obstacles() -> Array:
	var result: Array = []
	var x: float = START_X
	var level_span: float = float(LEVEL_WIDTH) - 800.0 - START_X

	while x < float(LEVEL_WIDTH) - 800.0:
		var t: float  = clampf((x - START_X) / level_span, 0.0, 1.0)
		var tc: float = t * t

		var inner_min  := lerpf(INNER_GAP_EASY_MIN,  INNER_GAP_HARD_MIN,  tc)
		var inner_max  := lerpf(INNER_GAP_EASY_MAX,  INNER_GAP_HARD_MAX,  tc)
		var breath_min := lerpf(BREATH_GAP_EASY_MIN, BREATH_GAP_HARD_MIN, tc)
		var breath_max := lerpf(BREATH_GAP_EASY_MAX, BREATH_GAP_HARD_MAX, tc)
		var p1 := lerpf(GROUP_PROB_EASY[0], GROUP_PROB_HARD[0], tc)
		var p2 := lerpf(GROUP_PROB_EASY[1], GROUP_PROB_HARD[1], tc)

		var roll := _rng.randf()
		var group_size: int
		if roll < p1:
			group_size = 1
		elif roll < p1 + p2:
			group_size = 2
		else:
			group_size = 3

		for i in range(group_size):
			if x >= float(LEVEL_WIDTH) - 800.0:
				break

			# Tipo de obstáculo — fijo, no escala con dificultad
			var tr := _rng.randf()
			var obs_type: int
			if tr < OBS_PROB_GROUND:
				obs_type = OBS_GROUND
			elif tr < OBS_PROB_GROUND + OBS_PROB_AERIAL:
				obs_type = OBS_AERIAL
			elif tr < OBS_PROB_GROUND + OBS_PROB_AERIAL + OBS_PROB_BUS:
				obs_type = OBS_BUS
			else:
				obs_type = OBS_COP

			var local_idx: int
			var body_w: float
			match obs_type:
				OBS_GROUND:
					local_idx = _rng.randi() % FRAME_COUNT
					body_w    = float(GROUND_BODY_W.get(local_idx, 370.0))
				OBS_AERIAL:
					local_idx = _rng.randi() % FRAME_COUNT_NEW
					body_w    = float(AERIAL_BODY_W.get(local_idx, 347.0))
				OBS_BUS:
					local_idx = _rng.randi() % BUS_DATA.size()
					body_w    = float(BUS_DATA[local_idx].cw) * BUS_SCALE
				OBS_COP:
					local_idx = 0
					body_w    = COP_W
				_:
					local_idx = 0
					body_w    = 370.0

			result.append({"x": x, "type": obs_type, "frame": local_idx, "width": body_w})
			if i < group_size - 1:
				x += body_w + _rng.randf_range(inner_min, inner_max)

		if not result.is_empty():
			var last: Dictionary = result[-1]
			x = last.x + last.width + _rng.randf_range(breath_min, breath_max)
	return result

