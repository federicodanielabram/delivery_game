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
# Recorte del borde derecho del rectángulo de hitbox (fracción del ancho total)
const AERIAL_RIGHT_TRIM: Dictionary = {
	8: 0.10,
}
const GROUND_SCALE_MULT: Dictionary = {
	6: 1.15,
}

# Contorno superior por frame: alturas desde el fondo del canvas (px), una por cada
# CAR_CONTOUR_STEP píxeles de canvas. Generado por tools/analyze_car_contour.js
const CAR_CONTOUR_STEP: float = 16.0
const CONTOUR_LIFT:     float = 40.0   # sube la superficie sin cambiar la forma
const CAR_CONTOURS: Dictionary = {
	0: [0, 366, 371, 375, 378, 381, 384, 387, 390, 392, 408, 413, 417, 419, 422, 425, 427, 430, 433, 435, 438, 440, 442, 445, 447, 449, 451, 453, 455, 457, 459, 461, 463, 464, 466, 468, 469, 470, 472, 472, 473, 473, 473, 472, 471, 470, 468, 466, 463, 460, 456, 452, 448, 443, 438, 432, 427, 421, 415, 410, 404, 399, 393, 388, 383, 378, 373, 368, 364, 359, 354, 350, 345, 341, 336, 331, 325, 319, 313, 305, 302, 299, 296, 293, 289, 286, 282, 278, 0],
	1: [0, 0, 331, 333, 335, 337, 338, 339, 340, 342, 343, 353, 356, 358, 360, 363, 365, 368, 371, 374, 378, 381, 385, 389, 393, 396, 399, 402, 405, 407, 409, 411, 413, 414, 415, 416, 417, 417, 416, 416, 415, 413, 411, 409, 406, 403, 399, 395, 390, 385, 379, 373, 367, 360, 354, 347, 341, 334, 328, 323, 317, 312, 307, 302, 298, 293, 289, 286, 282, 279, 275, 271, 267, 263, 258, 253, 247, 237, 224, 221, 217, 213, 209, 205, 200, 194, 188, 0, 0],
	2: [0, 0, 0, 0, 0, 0, 0, 465, 476, 488, 499, 508, 517, 524, 530, 536, 561, 575, 588, 598, 606, 610, 614, 617, 620, 623, 624, 624, 624, 624, 624, 624, 624, 624, 624, 624, 624, 624, 624, 624, 624, 624, 623, 620, 617, 614, 610, 605, 598, 590, 582, 572, 560, 548, 536, 523, 509, 495, 482, 469, 458, 446, 435, 425, 416, 408, 400, 394, 389, 385, 382, 379, 376, 373, 371, 367, 357, 355, 353, 351, 349, 347, 344, 341, 338, 0, 0, 0, 0],
	3: [0, 0, 313, 316, 318, 321, 323, 325, 327, 329, 330, 339, 343, 346, 350, 353, 356, 360, 364, 368, 371, 375, 379, 383, 387, 391, 394, 397, 401, 404, 406, 409, 411, 413, 415, 416, 417, 417, 417, 417, 416, 415, 413, 411, 408, 405, 402, 398, 393, 388, 383, 377, 370, 364, 358, 351, 345, 339, 333, 327, 321, 316, 310, 305, 301, 296, 292, 288, 284, 280, 277, 272, 268, 263, 258, 252, 246, 237, 225, 222, 218, 214, 210, 206, 201, 196, 190, 0, 0],
	4: [0, 0, 0, 0, 537, 544, 549, 554, 558, 561, 564, 567, 569, 592, 600, 603, 604, 605, 605, 605, 605, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 606, 605, 605, 605, 605, 605, 604, 604, 604, 604, 604, 603, 603, 602, 602, 601, 601, 600, 599, 597, 596, 593, 589, 584, 578, 571, 563, 554, 545, 535, 524, 513, 502, 490, 478, 465, 453, 441, 429, 419, 409, 400, 391, 383, 375, 361, 357, 353, 349, 345, 341, 337, 334, 330, 0, 0, 0, 0],
	5: [0, 0, 0, 321, 324, 328, 331, 334, 338, 341, 345, 349, 362, 368, 374, 381, 387, 394, 400, 407, 414, 420, 426, 432, 438, 443, 448, 452, 456, 459, 462, 464, 466, 467, 469, 469, 470, 470, 469, 469, 468, 468, 467, 465, 463, 460, 457, 453, 449, 444, 439, 434, 428, 421, 414, 407, 400, 393, 385, 378, 371, 365, 359, 353, 348, 343, 338, 334, 329, 326, 322, 318, 314, 311, 306, 301, 294, 287, 284, 282, 279, 276, 273, 269, 265, 261, 0, 0, 0],
	6: [0, 0, 0, 0, 0, 0, 500, 509, 516, 522, 527, 532, 536, 539, 542, 566, 579, 585, 587, 588, 588, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 589, 588, 588, 587, 586, 585, 584, 582, 580, 578, 574, 570, 565, 559, 553, 546, 538, 530, 521, 511, 501, 491, 480, 469, 458, 448, 437, 427, 417, 407, 398, 389, 381, 370, 356, 352, 348, 343, 339, 334, 330, 325, 320, 0, 0, 0, 0, 0, 0],
	7: [0, 282, 286, 290, 294, 297, 301, 304, 307, 309, 318, 325, 331, 336, 341, 346, 351, 356, 362, 367, 372, 377, 382, 387, 392, 397, 402, 406, 410, 414, 418, 421, 423, 425, 425, 425, 425, 424, 422, 419, 415, 411, 406, 401, 395, 388, 382, 376, 370, 363, 357, 351, 346, 340, 335, 331, 327, 323, 320, 317, 314, 312, 310, 307, 304, 301, 298, 294, 290, 286, 282, 277, 271, 265, 260, 252, 244, 236, 228, 215, 211, 206, 202, 197, 192, 187, 181, 175, 0],
}

# ── Tipos de obstáculo ────────────────────────────────────────────────────────
const OBS_GROUND := 0   # auto en el piso
const OBS_AERIAL := 1   # auto aéreo
const OBS_BUS    := 2   # colectivo (techo transitable)
const OBS_COP    := 3   # policía (1 golpe si es jump+kick o slide)
const OBS_TRUCK  := 4   # camión (techo transitable, más ancho que el colectivo)

# Probabilidades fijas por tipo (suman 1.0)
const OBS_PROB_GROUND: float = 0.30
const OBS_PROB_AERIAL: float = 0.25
const OBS_PROB_BUS:    float = 0.15
const OBS_PROB_TRUCK:  float = 0.10
# Cop: 0.20 (el resto)

# ── Colectivos (buses) ────────────────────────────────────────────────────────
const BUS_DATA: Array = [
	{"cw": 1007.0, "ch": 400.0, "body_h": 320.0},  # bus_01
	{"cw": 1007.0, "ch": 386.0, "body_h": 309.0},  # bus_02
	{"cw": 1009.0, "ch": 394.0, "body_h": 315.0},  # bus_03
]
const BUS_SCALE:       float = 0.8232
const BUS_FLOOR_Y:     float = 725.0
const BUS_ROOF_OFFSET: float = 15.0

# ── Camiones ──────────────────────────────────────────────────────────────────
# Portacoches con rampa hacia el piso. La colisión tiene dos partes que forman
# una sola superficie pisable continua:
#  - un rectángulo sobre la cabina + plataforma (parte maciza, a la derecha)
#  - una rampa triangular pegada a su izquierda que baja hasta el asfalto,
#    con el mismo alto en la costura para que no haya escalón entre las dos.
# platform_h: altura real (px de canvas) de la plataforma en la costura —
# medida sobre el sprite, más baja que la baranda/techo de la cabina.
const TRUCK_DATA: Array = [
	{"cw": 964.0, "ch": 317.0, "solid_w": 404.0, "platform_h": 220.0},  # truck_01
	{"cw": 965.0, "ch": 317.0, "solid_w": 404.0, "platform_h": 226.0},  # truck_02
	{"cw": 971.0, "ch": 320.0, "solid_w": 407.0, "platform_h": 226.0},  # truck_03
]
const TRUCK_SCALE:   float = 0.9003   # ajustado para que la cabina quede a la altura del colectivo
# Ajustes finos de la hitbox — escalados en la misma proporción que TRUCK_SCALE
# (×1.0937 respecto de los valores originales a 0.8232) para que el agrandado
# del camión no descuadre la plataforma/rampa ya afinadas.
const PLATFORM_SHRINK_LEFT: float = 164.0   # borde izquierdo de la plataforma, corrido a la derecha
const PLATFORM_OFFSET_X:    float = -10.9   # corrimiento fino de todo el rectángulo (negativo = izquierda)
const PLATFORM_GROW_UP:     float = 32.8    # agranda la plataforma hacia arriba (borde de abajo fijo)
const RAMP_OFFSET_X:        float = 0.0     # corrimiento de la rampa (positivo = derecha)
const RAMP_TIP_EXTEND_LEFT: float = 10.9   # estira la punta izquierda de la rampa más a la izquierda

# ── Policía ───────────────────────────────────────────────────────────────────
const COP_SCENE := preload("res://scenes/enemies/Cop.tscn")
const COP_W:     float = 200.0   # ancho aproximado para cálculo de gaps

const LOOKAHEAD:       float = 2000.0
const CLEANUP_BEHIND:  float = 1500.0
const DIFFICULTY_RAMP: float = 20000.0

const CAR_CONTOURS_NEW: Dictionary = {
	0: [0, 0, 0, 0, 0, 352, 355, 357, 359, 361, 363, 365, 367, 368, 375, 380, 382, 385, 388, 390, 392, 395, 397, 399, 402, 404, 406, 408, 410, 412, 414, 416, 418, 419, 421, 422, 424, 425, 426, 426, 427, 427, 426, 425, 424, 422, 419, 416, 413, 410, 405, 400, 395, 389, 384, 377, 371, 364, 358, 351, 345, 339, 333, 327, 321, 316, 310, 305, 300, 295, 290, 285, 280, 274, 268, 261, 258, 255, 253, 250, 247, 243, 240, 236, 0, 0, 0, 0, 0],
	1: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 330, 340, 348, 355, 361, 366, 371, 375, 379, 395, 405, 414, 422, 428, 434, 438, 441, 443, 445, 446, 448, 449, 450, 450, 451, 451, 452, 453, 452, 451, 450, 448, 445, 442, 438, 434, 429, 424, 418, 411, 403, 395, 387, 378, 369, 360, 352, 344, 336, 328, 321, 314, 307, 301, 295, 289, 282, 275, 265, 262, 259, 256, 253, 250, 246, 242, 237, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	2: [0, 0, 0, 0, 0, 258, 262, 265, 268, 271, 274, 277, 280, 282, 292, 297, 302, 307, 311, 315, 319, 323, 327, 331, 335, 338, 341, 344, 347, 350, 352, 354, 356, 357, 358, 359, 359, 359, 358, 357, 355, 353, 351, 348, 345, 341, 337, 332, 327, 322, 316, 310, 305, 299, 293, 288, 283, 278, 273, 269, 264, 260, 256, 253, 249, 246, 243, 240, 237, 233, 229, 225, 221, 215, 209, 202, 199, 196, 193, 190, 187, 183, 180, 176, 0, 0, 0, 0, 0],
	3: [0, 0, 0, 0, 0, 0, 0, 0, 352, 362, 370, 378, 385, 393, 399, 405, 410, 431, 443, 453, 460, 465, 469, 473, 475, 477, 479, 480, 480, 480, 479, 478, 477, 476, 475, 474, 473, 472, 471, 470, 469, 468, 467, 467, 466, 466, 465, 464, 463, 462, 461, 460, 459, 459, 457, 455, 453, 455, 453, 450, 448, 446, 443, 440, 436, 431, 424, 416, 407, 397, 386, 374, 356, 352, 342, 337, 330, 323, 314, 303, 292, 0, 0, 0, 0, 0, 0, 0, 0],
	4: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 377, 384, 389, 394, 398, 401, 404, 407, 409, 427, 433, 437, 441, 444, 445, 445, 445, 446, 446, 446, 446, 446, 446, 445, 445, 445, 445, 445, 445, 445, 445, 445, 445, 445, 445, 445, 445, 445, 445, 445, 444, 442, 440, 438, 434, 430, 425, 419, 412, 405, 397, 388, 378, 368, 357, 345, 332, 319, 306, 293, 277, 270, 263, 256, 250, 243, 236, 228, 221, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	5: [0, 0, 0, 0, 0, 0, 0, 316, 324, 332, 339, 345, 351, 356, 360, 364, 381, 390, 398, 405, 411, 415, 419, 421, 423, 425, 426, 427, 427, 427, 427, 427, 427, 427, 427, 427, 426, 426, 425, 423, 421, 419, 416, 413, 409, 404, 399, 393, 386, 379, 371, 363, 355, 346, 337, 328, 319, 311, 303, 296, 289, 282, 276, 270, 265, 260, 255, 251, 247, 243, 239, 234, 228, 220, 218, 215, 213, 210, 207, 204, 200, 196, 0, 0, 0, 0, 0, 0, 0],
	6: [0, 0, 0, 0, 0, 289, 293, 297, 301, 305, 310, 314, 318, 322, 335, 342, 349, 355, 362, 368, 375, 381, 387, 392, 397, 401, 405, 409, 412, 414, 416, 418, 419, 419, 420, 420, 420, 420, 420, 419, 419, 419, 418, 417, 416, 414, 411, 408, 405, 401, 396, 391, 385, 379, 372, 365, 357, 349, 342, 334, 327, 319, 312, 306, 299, 293, 288, 283, 278, 274, 270, 266, 262, 257, 250, 243, 240, 238, 235, 232, 230, 226, 223, 219, 0, 0, 0, 0, 0],
	7: [0, 0, 0, 0, 0, 0, 0, 0, 361, 373, 382, 390, 397, 402, 407, 412, 415, 434, 451, 462, 470, 474, 476, 477, 477, 477, 477, 477, 477, 477, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 478, 477, 477, 477, 477, 476, 476, 474, 473, 471, 468, 465, 461, 457, 452, 446, 439, 431, 422, 413, 403, 392, 381, 369, 356, 344, 330, 313, 305, 298, 291, 283, 276, 268, 261, 253, 0, 0, 0, 0, 0, 0, 0, 0],
	8: [0, 0, 0, 0, 0, 263, 264, 266, 268, 271, 273, 275, 277, 280, 284, 288, 292, 297, 301, 305, 309, 313, 317, 321, 325, 329, 331, 334, 337, 339, 341, 343, 344, 346, 346, 346, 345, 344, 342, 339, 337, 333, 329, 325, 320, 315, 309, 303, 297, 291, 284, 278, 273, 267, 262, 258, 253, 249, 245, 241, 238, 235, 232, 229, 227, 223, 220, 216, 211, 206, 200, 194, 187, 180, 171, 160, 156, 152, 147, 142, 137, 131, 125, 120, 0, 0, 0, 0, 0],
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
var _truck_base_x: Array = []
var _truck_bodies: Array = []

var _gen_head_x:   float = 0.0
var _shadow_tex:   Texture2D = null
var _bus_textures:   Array = []
var _truck_textures: Array = []

func get_placed_x() -> Array:
	return _base_x

func _ready() -> void:
	_rng.randomize()
	z_index = 2
	_shadow_tex = load("res://assets/sprites/cars/side_test/car_side_06 - copia.png")
	for i in range(1, BUS_DATA.size() + 1):
		_bus_textures.append(load("res://assets/sprites/buses/bus_0%d.png" % i))
	for i in range(1, TRUCK_DATA.size() + 1):
		_truck_textures.append(load("res://assets/sprites/trucks/truck_0%d.png" % i))
	_gen_head_x = START_X
	_fill_lookahead(0.0)

func _spawn_obstacle(obs: Dictionary) -> void:
	var sc := car_scale
	var px: float = obs.x
	var fi: int   = obs.frame
	match obs.type:
		OBS_GROUND:
			var tex: Texture2D = load("res://assets/sprites/cars/side_test/car_side_%02d.png" % fi)
			if not tex: return
			var frame_sc := sc * float(GROUND_SCALE_MULT.get(fi, 1.0))
			var body := StaticBody2D.new()
			body.position = Vector2(px, FLOOR_Y)
			var sp := Sprite2D.new()
			sp.texture     = tex
			sp.centered    = false
			sp.scale       = Vector2(frame_sc, frame_sc)
			sp.position    = Vector2(-CAR_CANVAS_W * frame_sc * 0.5, -CAR_CANVAS_H * frame_sc)
			sp.light_mask  = 2
			body.add_child(sp)
			_add_contour_collision(body, fi, frame_sc)
			# Rectángulo en la mitad inferior ajustado al tamaño real de cada auto
			var raw_c: Array = CAR_CONTOURS.get(fi, [])
			var bounds := _car_body_bounds(raw_c, frame_sc)
			if not bounds.is_empty():
				var rect_col   := CollisionShape2D.new()
				var rect_shape := RectangleShape2D.new()
				rect_shape.size   = Vector2(bounds.w, bounds.h * 0.5)
				rect_col.shape    = rect_shape
				rect_col.position = Vector2(bounds.cx, -bounds.h * 0.25)
				body.add_child(rect_col)
			body.add_to_group("car_obstacle")
			add_child(body)
			_base_x.append(px)
			_bodies.append(body)

		OBS_AERIAL:
			var tex: Texture2D = load("res://assets/sprites/cars/side_chatgpt/car_side_%02d.png" % fi)
			if not tex: return
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
			var raw_a: Array = CAR_CONTOURS_NEW.get(fi, [])
			var bounds_a := _car_body_bounds(raw_a, frame_sc)
			if not bounds_a.is_empty():
				var trim_f: float = float(AERIAL_RIGHT_TRIM.get(fi, 0.0))
				if trim_f > 0.0:
					var trim_px: float = float(bounds_a.w) * trim_f
					bounds_a.w  -= trim_px
					bounds_a.cx -= trim_px * 0.5
				var rect_col_a   := CollisionShape2D.new()
				var rect_shape_a := RectangleShape2D.new()
				rect_shape_a.size   = Vector2(bounds_a.w, bounds_a.h * 0.5)
				rect_col_a.shape    = rect_shape_a
				rect_col_a.position = Vector2(bounds_a.cx, -bounds_a.h * 0.25)
				body.add_child(rect_col_a)
			body.collision_layer = 8
			body.z_as_relative   = false
			body.z_index         = 4
			body.add_to_group("car_obstacle")
			add_child(body)
			_aerial_base_x.append(px)
			_aerial_bodies.append(body)
			_aerial_phases.append(_rng.randf_range(0.0, TAU))
			if _shadow_tex:
				var sh := Sprite2D.new()
				sh.texture  = _shadow_tex
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
			var tex: Texture2D = _bus_textures[fi]
			if not tex: return
			var body := StaticBody2D.new()
			body.position        = Vector2(px, BUS_FLOOR_Y + shadow_h * bsc)
			body.collision_layer = 1
			body.collision_mask  = 0
			body.add_to_group("car_obstacle")
			body.add_to_group("car_obstacle_tall")   # plataforma alta: al bajarse, sí dispara la caída
			add_child(body)
			var sp := Sprite2D.new()
			sp.texture    = tex
			sp.centered   = false
			sp.scale      = Vector2(bsc, bsc)
			sp.position   = Vector2(-cw * bsc * 0.5, -ch * bsc)
			sp.light_mask = 0
			body.add_child(sp)
			var col   := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size   = Vector2(cw * bsc * 0.98 - 20.0, ch * bsc * 0.95)
			col.shape    = shape
			col.position = Vector2(-cw * bsc * 0.01, -ch * bsc * 0.475)
			body.add_child(col)
			_bus_base_x.append(px)
			_bus_bodies.append(body)

		OBS_TRUCK:
			var d: Dictionary = TRUCK_DATA[fi]
			var cw: float = d.cw
			var ch: float = d.ch
			var solid_w: float = d.solid_w
			var plat_h: float = d.platform_h
			var tsc: float = TRUCK_SCALE
			var tex: Texture2D = _truck_textures[fi]
			if not tex: return
			var body := StaticBody2D.new()
			body.position        = Vector2(px, FLOOR_Y)
			body.collision_layer = 1
			body.collision_mask  = 0
			body.add_to_group("car_obstacle")
			body.add_to_group("car_obstacle_tall")   # plataforma alta: al bajarse, sí dispara la caída
			add_child(body)
			var sp := Sprite2D.new()
			sp.texture    = tex
			sp.centered   = false
			sp.scale      = Vector2(tsc, tsc)
			sp.position   = Vector2(-cw * tsc * 0.5, -ch * tsc)
			sp.light_mask = 0
			body.add_child(sp)
			# Plataforma: rectángulo sobre la cabina + plataforma (parte maciza),
			# con el borde derecho fijo en el borde del sprite (la cabina). El
			# borde izquierdo se corre PLATFORM_SHRINK_LEFT px hacia la derecha
			# (achica el rectángulo, deja un hueco entre este y la rampa).
			var seam_x: float = cw * tsc * 0.5 - solid_w * tsc
			var plat_w: float = solid_w * tsc - PLATFORM_SHRINK_LEFT
			var plat_h_scaled: float = plat_h * tsc + PLATFORM_GROW_UP
			var col   := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size   = Vector2(plat_w, plat_h_scaled)
			col.shape    = shape
			col.position = Vector2(seam_x + PLATFORM_SHRINK_LEFT + plat_w * 0.5 + PLATFORM_OFFSET_X, -plat_h_scaled * 0.5)
			body.add_child(col)
			# Rampa: cuña triangular pegada a la izquierda de la plataforma. Su
			# borde derecho se estira hasta tocar el borde izquierdo real de la
			# plataforma (con todos sus ajustes) para que no quede hueco ni
			# escalón. La punta izquierda, en el asfalto, se estira
			# RAMP_TIP_EXTEND_LEFT px más hacia la izquierda.
			var rect_left_x: float = col.position.x - plat_w * 0.5
			var rect_top_y:  float = col.position.y - plat_h_scaled * 0.5
			var ramp := CollisionPolygon2D.new()
			ramp.position = Vector2(RAMP_OFFSET_X, 0.0)
			ramp.polygon = PackedVector2Array([
				Vector2(-cw * tsc * 0.5 - RAMP_TIP_EXTEND_LEFT, 0.0),  # punta de la rampa en el piso
				Vector2(rect_left_x - RAMP_OFFSET_X, rect_top_y),      # arriba, tocando la plataforma
				Vector2(rect_left_x - RAMP_OFFSET_X, 0.0),             # abajo, tocando la plataforma
			])
			body.add_child(ramp)
			_truck_base_x.append(px)
			_truck_bodies.append(body)

		OBS_COP:
			# Comportamiento normal (patrulla/persigue/ataca) — solo el *spawn* está
			# integrado al mismo sorteo y espaciado que el resto de los obstáculos.
			var cop := COP_SCENE.instantiate() as Node2D
			cop.position = Vector2(px, 600.0)
			get_parent().add_child(cop)

func _car_body_bounds(raw: Array, sc: float) -> Dictionary:
	var first := -1
	var last  := -1
	var max_h := 0
	for i in range(raw.size()):
		if int(raw[i]) > 0:
			if first == -1: first = i
			last = i
			if int(raw[i]) > max_h: max_h = int(raw[i])
	if first == -1: return {}
	var left_x  := float(first) * CAR_CONTOUR_STEP * sc - CAR_CANVAS_W * sc * 0.5
	var right_x := float(last)  * CAR_CONTOUR_STEP * sc - CAR_CANVAS_W * sc * 0.5
	return {
		"w":  right_x - left_x,
		"h":  float(max_h) * sc,
		"cx": (left_x + right_x) * 0.5,
	}

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
	const SMOOTH_RADIUS := 8
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
	var cam_x  := cam.get_screen_center_position().x
	var offset := cam_x * (1.0 - parallax)

	for i in range(_bodies.size()):
		(_bodies[i] as Node2D).global_position.x = _base_x[i] + offset

	var t  := Time.get_ticks_msec() / 1000.0
	var sc := car_scale
	for i in range(_aerial_bodies.size()):
		var body := _aerial_bodies[i] as Node2D
		body.global_position.x = _aerial_base_x[i] + offset
		body.global_position.y = AERIAL_Y + sin(t * AERIAL_BOB_FREQ * TAU + _aerial_phases[i]) * AERIAL_BOB_AMP
		if i < _aerial_shadows.size():
			var sh: Sprite2D = _aerial_shadows[i] as Sprite2D
			sh.global_position.x = _aerial_base_x[i] + offset - CAR_CANVAS_W * sc * 0.5
			sh.global_position.y = FLOOR_Y - CAR_CANVAS_H * sc

	for i in range(_bus_bodies.size()):
		(_bus_bodies[i] as Node2D).global_position.x = _bus_base_x[i] + offset

	for i in range(_truck_bodies.size()):
		(_truck_bodies[i] as Node2D).global_position.x = _truck_base_x[i] + offset

	if _gen_head_x < cam_x * parallax + LOOKAHEAD:
		_fill_lookahead(cam_x)
	_cleanup_old(cam_x)

func _fill_lookahead(cam_x: float) -> void:
	var target_x := cam_x * parallax + LOOKAHEAD
	var x := _gen_head_x
	while x < target_x:
		var t: float  = clampf((x - START_X) / DIFFICULTY_RAMP, 0.0, 1.0)
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

		var last_x := x
		var last_w := 370.0
		for i in range(group_size):
			var tr := _rng.randf()
			var obs_type: int
			if tr < OBS_PROB_GROUND:
				obs_type = OBS_GROUND
			elif tr < OBS_PROB_GROUND + OBS_PROB_AERIAL:
				obs_type = OBS_AERIAL
			elif tr < OBS_PROB_GROUND + OBS_PROB_AERIAL + OBS_PROB_BUS:
				obs_type = OBS_BUS
			elif tr < OBS_PROB_GROUND + OBS_PROB_AERIAL + OBS_PROB_BUS + OBS_PROB_TRUCK:
				obs_type = OBS_TRUCK
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
				OBS_TRUCK:
					local_idx = _rng.randi() % TRUCK_DATA.size()
					body_w    = float(TRUCK_DATA[local_idx].cw) * TRUCK_SCALE
				OBS_COP:
					local_idx = 0
					body_w    = COP_W
				_:
					local_idx = 0
					body_w    = 370.0

			_spawn_obstacle({"x": x, "type": obs_type, "frame": local_idx, "width": body_w})
			last_x = x
			last_w = body_w
			if i < group_size - 1:
				x += body_w + _rng.randf_range(inner_min, inner_max)

		x = last_x + last_w + _rng.randf_range(breath_min, breath_max)
	_gen_head_x = x

func _cleanup_old(cam_x: float) -> void:
	var cutoff := cam_x * parallax - CLEANUP_BEHIND

	var i := 0
	while i < _base_x.size():
		if _base_x[i] < cutoff:
			(_bodies[i] as Node).queue_free()
			_base_x.remove_at(i)
			_bodies.remove_at(i)
		else:
			i += 1

	i = 0
	while i < _aerial_base_x.size():
		if _aerial_base_x[i] < cutoff:
			(_aerial_bodies[i] as Node).queue_free()
			_aerial_base_x.remove_at(i)
			_aerial_bodies.remove_at(i)
			_aerial_phases.remove_at(i)
			if i < _aerial_shadows.size():
				(_aerial_shadows[i] as Node).queue_free()
				_aerial_shadows.remove_at(i)
		else:
			i += 1

	i = 0
	while i < _bus_base_x.size():
		if _bus_base_x[i] < cutoff:
			(_bus_bodies[i] as Node).queue_free()
			_bus_base_x.remove_at(i)
			_bus_bodies.remove_at(i)
		else:
			i += 1

	i = 0
	while i < _truck_base_x.size():
		if _truck_base_x[i] < cutoff:
			(_truck_bodies[i] as Node).queue_free()
			_truck_base_x.remove_at(i)
			_truck_bodies.remove_at(i)
		else:
			i += 1
