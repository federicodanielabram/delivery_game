extends Node2D

@export var car_scale:  float = 0.2782   # 553px target / 1392px body * 0.7
@export var parallax:   float = 1.2    # mismo ritmo que los charcos (puddle_layer.gd). Con
										# parallax≠1 estos autos (colisión real) igual se
										# reposicionan un poco cada frame según la cámara — hay
										# algo de corrimiento real respecto a un objeto 100% fijo
										# como el piso, pero mucho menor que el 1.275 anterior.

const LEVEL_WIDTH:  int   = 32000
const FRAME_COUNT:       int = 8
const FRAME_COUNT_NEW:   int = 9
const FLOOR_Y:      float = 735.0
const MIN_DIST:     float = 600.0

# Config fija, pensada para sostenerse al infinito — la presión progresiva la
# da el dron (persigue casi a la misma velocidad que el PP), no el espaciado
# del tráfico. Los gaps varían dentro de un rango fijo para variedad rítmica,
# pero ya no se achican con la distancia.
const START_X: float = 2500.0   # primer obstáculo: el jugador ya arrancó a correr

# Gap borde-a-borde DENTRO de un grupo (entre obstáculos consecutivos, dado)
const INNER_GAP_MIN: float = 500.0
const INNER_GAP_MAX: float = 750.0

# Gap borde-a-borde ENTRE grupos/singles (respiro)
const BREATH_GAP_MIN: float = 1800.0
const BREATH_GAP_MAX: float = 3000.0

# Probabilidad de tamaño de grupo [solo, dúo, trío] — fija
const GROUP_PROB: Array = [0.35, 0.25, 0.40]

# Prearmados: solo se sortean cuando el tamaño de grupo dio dúo/trío; de esas
# veces, 50% se reemplaza por un patrón de la bolsa en vez de armarlo al dado.
# No aparecen hasta pasar el warm-up (el jugador ve tráfico simple primero).
const PATTERN_CHANCE:      float = 0.5
const PATTERN_WARMUP_DIST: float = 4500.0

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
const BUS_SCALE:       float = 0.7632  # bajado de 0.8232: techo a ~290px (antes ~313px),
										# deja margen de timing real para llegar en doble salto
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
# Tinte propio del cop, más claro que el resto de la línea del medio a propósito:
# el uniforme táctico es de base muy oscuro (azul marino/negro), así que el mismo
# multiplicador que a un auto se le nota mucho más oscuro al lado del PP — hay que
# sobre-compensarlo para que quede a la par visualmente.
const COP_TINT:  Color = Color(0.95, 0.90, 1.05)
const COP_W:     float = 340.0   # ancho para cálculo de gaps — con margen real: canvas 256×
								  # scale 1.1 (~282px) + hasta 45px de offset del sprite según
								  # hacia dónde mira (ver cop.gd), si no el hueco calculado
								  # queda más chico de lo real y se ve pegado a lo de al lado

const LOOKAHEAD:       float = 2000.0
const CLEANUP_BEHIND:  float = 1500.0

# ── Patrones prearmados ───────────────────────────────────────────────────────
# Composiciones fijas, curadas a mano — se sacan de una bolsa sin reposición
# (no se repite ninguno hasta pasar por todos) cuando PATTERN_CHANCE lo decide.
const PATTERN_NAMES: Array = ["rampa_carrera", "techos_bus", "aereo_fakeout"]

# rampa_carrera: camión + 3 autos pegados justo después. El gap camión→auto1
# es grande a propósito (fuerza doble salto real: un salto simple desde la
# plataforma del camión no alcanza a cubrirlo, un doble salto sí, con margen).
const RAMPA_LAUNCH_GAP: float = 300.0
const RAMPA_CARS_GAP:   float = 30.0

# aereo_fakeout: auto aéreo (frame fijo, el más alto: ~259px de techo) seguido
# de un colectivo. El gap da lugar a resolver el aéreo (agachado o saltado) y
# DESPUÉS pararse en idle y saltar al techo del bus con normalidad (salto +
# doble salto, igual que un colectivo suelto) — no es un arco único que cruza
# los dos de una, a propósito: así siempre hay margen para frenar y pensar.
const FAKEOUT_AERIAL_FRAME: int   = 3
const FAKEOUT_GAP:          float = 450.0

# techos_bus: cadena de colectivos/camiones para correr por los techos, con
# la posibilidad de un auto aéreo a nivel calle en las transiciones (bajás,
# lo esquivás con slide, volvés a subir).
const ROOFTOP_PIECE_MIN:     int   = 3
const ROOFTOP_PIECE_MAX:     int   = 4
const ROOFTOP_TRUCK_CHANCE:  float = 0.35
const ROOFTOP_GAP_MIN:       float = 600.0
const ROOFTOP_GAP_MAX:       float = 900.0
const ROOFTOP_AERIAL_CHANCE: float = 0.4
# Cuando la transición SÍ tiene aéreo, se reemplaza el gap único de arriba por
# dos huecos explícitos (no un centrado dentro de un gap random, que en el
# peor caso podía dejar el aéreo casi pegado a un colectivo). El de "después"
# es más grande a propósito: el PP tiene que poder salir del slide (dejar de
# estar "bajo el aéreo", zona de 200px) y quedar parado/corriendo ANTES de
# llegar al próximo techo — si no, queda bugueado a medio camino del salto.
const ROOFTOP_AERIAL_GAP_BEFORE: float = 250.0
const ROOFTOP_AERIAL_GAP_AFTER:  float = 320.0

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
var _pattern_bag:    Array = []
var _stop_x:         float = -1.0   # -1 = infinito; ver stop_at() — fin de nivel (pizzeria)

func get_placed_x() -> Array:
	return _base_x

# Corta la generación a partir de x (usado al llegar a la pizzeria, fin del modo infinito).
func stop_at(x: float) -> void:
	_stop_x = x

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

const _DEBUG_TYPE_NAMES := ["GROUND", "AERIAL", "BUS", "COP", "TRUCK"]

func _spawn_obstacle(obs: Dictionary) -> void:
	var sc := car_scale
	var px: float = obs.x
	var fi: int   = obs.frame
	# DEBUG temporal — sacar cuando encontremos el bug de la "pared invisible".
	# PX aprox. porque el player arranca en x=256 (ver Player en Game.tscn).
	print("[obstacle] %s frame=%d x=%.0f (~PX %.0f) width=%s" % [
		_DEBUG_TYPE_NAMES[obs.type], fi, px, px - 256.0, str(obs.get("width", "?"))
	])
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
			sp.light_mask = 2   # igual que los autos de piso: solo las luces "mid" (tenues) del
								# dron — sin esto quedaba en el mask por defecto (1), enganchado
								# a las luces fuertes del dron (cono principal energy=5.0), y se
								# veía mucho más iluminado que el resto de la línea de noche
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
			# Comportamiento normal (patrulla/ataca) — solo el *spawn* está integrado
			# al mismo sorteo y espaciado que el resto de los obstáculos.
			# obstacle_mode=true: golpearlo (slide o air kick) no dispara hitstop, y
			# bloquea físicamente al jugador si lo corre de lleno (ver player.gd).
			var cop := COP_SCENE.instantiate() as Node2D
			cop.position = Vector2(px, 570.0)   # 30px más arriba que el original (600) — sprite,
												 # hitbox, área de contacto y sombra viajan
												 # todos juntos porque son relativos a esto
			cop.set("obstacle_mode", true)
			# Se instancia como hermano de esta capa (no hijo), así que no hereda
			# su modulate — se lo aplicamos a mano para que quede integrado con
			# el resto de la línea del medio (autos/buses/camiones), no a color pleno.
			cop.modulate = COP_TINT
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
	if _stop_x >= 0.0:
		target_x = minf(target_x, _stop_x)
	var x := _gen_head_x
	while x < target_x:
		var group_size := _roll_group_size()
		var past_warmup := (x - START_X) >= PATTERN_WARMUP_DIST

		if group_size >= 2 and past_warmup and _rng.randf() < PATTERN_CHANCE:
			x = _spawn_pattern(_next_pattern_name(), x)
		else:
			x = _spawn_dice_group(group_size, x)

		x += _rng.randf_range(BREATH_GAP_MIN, BREATH_GAP_MAX)
	_gen_head_x = x

func _roll_group_size() -> int:
	var roll := _rng.randf()
	if roll < GROUP_PROB[0]:
		return 1
	elif roll < GROUP_PROB[0] + GROUP_PROB[1]:
		return 2
	return 3

# allow_cop=false redistribuye también la porción del cop (proporcional, junto
# con la del camión si tampoco está permitido) — el cop solo sale en solitario.
func _roll_obstacle_type(allow_truck: bool, allow_cop: bool) -> int:
	var p_truck := OBS_PROB_TRUCK if allow_truck else 0.0
	var p_cop   := (1.0 - OBS_PROB_GROUND - OBS_PROB_AERIAL - OBS_PROB_BUS - OBS_PROB_TRUCK) if allow_cop else 0.0
	var scale: float = 1.0 / (OBS_PROB_GROUND + OBS_PROB_AERIAL + OBS_PROB_BUS + p_truck + p_cop)
	var p_ground := OBS_PROB_GROUND * scale
	var p_aerial := OBS_PROB_AERIAL * scale
	var p_bus    := OBS_PROB_BUS    * scale
	p_truck *= scale
	var tr := _rng.randf()
	if tr < p_ground:
		return OBS_GROUND
	elif tr < p_ground + p_aerial:
		return OBS_AERIAL
	elif tr < p_ground + p_aerial + p_bus:
		return OBS_BUS
	elif allow_truck and tr < p_ground + p_aerial + p_bus + p_truck:
		return OBS_TRUCK
	elif allow_cop:
		return OBS_COP
	else:
		return OBS_GROUND   # resto por redondeo de floats: nunca cae acá en la práctica

# Arma un grupo tirando el dado por obstáculo (como antes), sin ramp de dificultad.
# Los camiones quedan afuera del sorteo salvo en trío: solitario y dúo son
# obstáculos poco interesantes para lucir la rampa (ver rampa_carrera para eso,
# y techos_bus, que no pasan por este sorteo). Se redistribuye su probabilidad
# proporcionalmente entre el resto de los tipos, no se le regala a ninguno en particular.
func _spawn_dice_group(group_size: int, x: float) -> float:
	var allow_truck := group_size > 2
	var allow_cop   := group_size == 1
	var last_x := x
	var last_w := 370.0
	for i in range(group_size):
		var obs_type := _roll_obstacle_type(allow_truck, allow_cop)

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
			x += body_w + _rng.randf_range(INNER_GAP_MIN, INNER_GAP_MAX)

	return last_x + last_w

# ── Selección de la bolsa de prearmados ──────────────────────────────────────
func _next_pattern_name() -> String:
	if _pattern_bag.is_empty():
		_pattern_bag = PATTERN_NAMES.duplicate()
		_pattern_bag.shuffle()
	return _pattern_bag.pop_front()

func _spawn_pattern(pattern_name: String, x: float) -> float:
	match pattern_name:
		"rampa_carrera": return _spawn_rampa_carrera(x)
		"techos_bus":    return _spawn_techos_bus(x)
		"aereo_fakeout": return _spawn_aereo_fakeout(x)
		_: return x

# Camión-rampa + 3 autos pegados. El hueco camión→auto1 fuerza doble salto
# (ver RAMPA_LAUNCH_GAP); los 3 autos van casi sin gap entre sí.
func _spawn_rampa_carrera(x: float) -> float:
	var truck_idx := _rng.randi() % TRUCK_DATA.size()
	var truck_w: float = float(TRUCK_DATA[truck_idx].cw) * TRUCK_SCALE
	_spawn_obstacle({"x": x, "type": OBS_TRUCK, "frame": truck_idx, "width": truck_w})
	x += truck_w + RAMPA_LAUNCH_GAP

	var last_x := x
	var last_w := 370.0
	for i in range(3):
		var fi := _rng.randi() % FRAME_COUNT
		var w: float = float(GROUND_BODY_W.get(fi, 370.0))
		_spawn_obstacle({"x": x, "type": OBS_GROUND, "frame": fi, "width": w})
		last_x = x
		last_w = w
		if i < 2:
			x += w + RAMPA_CARS_GAP
	return last_x + last_w

# Auto aéreo (frame fijo, el más alto) + colectivo pegado. Una sola secuencia
# salto→doble salto despeja el aéreo y aterriza en el techo del bus.
func _spawn_aereo_fakeout(x: float) -> float:
	var aerial_w: float = float(AERIAL_BODY_W.get(FAKEOUT_AERIAL_FRAME, 417.0))
	_spawn_obstacle({"x": x, "type": OBS_AERIAL, "frame": FAKEOUT_AERIAL_FRAME, "width": aerial_w})
	x += aerial_w + FAKEOUT_GAP

	var bus_idx := _rng.randi() % BUS_DATA.size()
	var bus_w: float = float(BUS_DATA[bus_idx].cw) * BUS_SCALE
	_spawn_obstacle({"x": x, "type": OBS_BUS, "frame": bus_idx, "width": bus_w})
	return x + bus_w

# Cadena de colectivos/camiones para correr por los techos. En algunas de las
# transiciones a nivel calle entre uno y el siguiente puede aparecer un auto
# aéreo (bajás, lo esquivás con slide, volvés a subir).
func _spawn_techos_bus(x: float) -> float:
	var piece_count := _rng.randi_range(ROOFTOP_PIECE_MIN, ROOFTOP_PIECE_MAX)
	var last_x := x
	var last_w := 370.0
	for i in range(piece_count):
		var w: float
		if _rng.randf() < ROOFTOP_TRUCK_CHANCE:
			var ti := _rng.randi() % TRUCK_DATA.size()
			w = float(TRUCK_DATA[ti].cw) * TRUCK_SCALE
			_spawn_obstacle({"x": x, "type": OBS_TRUCK, "frame": ti, "width": w})
		else:
			var bi := _rng.randi() % BUS_DATA.size()
			w = float(BUS_DATA[bi].cw) * BUS_SCALE
			_spawn_obstacle({"x": x, "type": OBS_BUS, "frame": bi, "width": w})
		last_x = x
		last_w = w
		if i < piece_count - 1:
			if _rng.randf() < ROOFTOP_AERIAL_CHANCE:
				var ai := _rng.randi() % FRAME_COUNT_NEW
				var aw: float = float(AERIAL_BODY_W.get(ai, 347.0))
				x += w + ROOFTOP_AERIAL_GAP_BEFORE
				_spawn_obstacle({"x": x, "type": OBS_AERIAL, "frame": ai, "width": aw})
				x += aw + ROOFTOP_AERIAL_GAP_AFTER
			else:
				x += w + _rng.randf_range(ROOFTOP_GAP_MIN, ROOFTOP_GAP_MAX)
	return last_x + last_w

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
