extends CanvasLayer

# ── Paleta drone/VHS ──────────────────────────────────────────────────────────
const C_GREEN  := Color(0.0,  1.0,  0.55, 1.0)   # fósforo principal
const C_DIM    := Color(0.0,  0.55, 0.28, 0.85)  # texto secundario
const C_RED    := Color(1.0,  0.18, 0.08, 1.0)   # REC / peligro
const C_AMBER  := Color(1.0,  0.85, 0.0,  1.0)   # boost listo
const C_HOT    := Color(1.0,  0.45, 0.0,  1.0)   # boost activo
const C_BG     := Color(0.0,  0.0,  0.0,  0.60)  # fondo semitransparente

const NITRO_CHARGE_DUR := 7.0
const NITRO_ACTIVE_DUR := 2.0
const HP_MAX           := 5
const BOOST_BLOCKS     := 10

# Canvas del juego en coordenadas de CanvasLayer
const VW := 320.0
const VH := 224.0

var player:       Node = null
var is_game_over       := false

var _lbl_rec:    Label = null
var _lbl_time:   Label = null
var _lbl_spd:    Label = null
var _lbl_hull:   Label = null
var _lbl_boost:  Label = null
var _lbl_sector: Label = null

var _game_over_panel: ColorRect = null
var _blink_t: float = 0.0
var _time_s:  float = 0.0

# ── Font monoespacio del sistema ──────────────────────────────────────────────
func _mono_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Courier New", "Courier", "Lucida Console", "Consolas"])
	return f

func _make_bg(pos: Vector2, sz: Vector2) -> void:
	var bg := ColorRect.new()
	bg.color    = C_BG
	bg.position = pos
	bg.size     = sz
	add_child(bg)

func _make_label(txt: String, pos: Vector2, sz: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text     = txt
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_override("font", _mono_font())
	add_child(lbl)
	return lbl

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	player = get_tree().get_first_node_in_group("player")
	_build_hud()
	_build_game_over()

func _build_hud() -> void:
	# ── TOP-LEFT: REC + timecode + HULL + BOOST apilados ─────────────────
	_make_bg(Vector2(3, 3), Vector2(108, 56))
	_lbl_rec  = _make_label("* REC", Vector2(6,  5), 8, C_RED)
	_lbl_time = _make_label("00:00:00", Vector2(44, 5), 8, C_GREEN)
	_make_label("HULL",  Vector2(6, 20), 7, C_DIM)
	_lbl_hull  = _make_label("█████",       Vector2(6, 30), 8, C_GREEN)
	_make_label("BOOST", Vector2(6, 42), 7, C_DIM)
	_lbl_boost = _make_label("░░░░░░░░░░",  Vector2(6, 52), 8, C_GREEN)

	# ── TOP-RIGHT: velocidad ──────────────────────────────────────────────
	_make_bg(Vector2(VW - 84, 3), Vector2(81, 14))
	_lbl_spd = _make_label("SPD>0000", Vector2(VW - 81, 4), 8, C_GREEN)

	# ── TOP-CENTER: sector ────────────────────────────────────────────────
	_make_bg(Vector2(VW * 0.5 - 42, 3), Vector2(84, 14))
	_lbl_sector = _make_label("SECTOR A-1", Vector2(VW * 0.5 - 39, 4), 8, C_DIM)

func _build_game_over() -> void:
	var panel := ColorRect.new()
	panel.color    = Color(0.0, 0.0, 0.0, 0.85)
	panel.position = Vector2.ZERO
	panel.size     = Vector2(VW, VH)
	panel.visible  = false

	var t1 := Label.new()
	t1.text     = "[ SIGNAL  LOST ]"
	t1.position = Vector2(82, 90)
	t1.add_theme_font_size_override("font_size", 14)
	t1.add_theme_color_override("font_color", C_RED)
	t1.add_theme_font_override("font", _mono_font())
	panel.add_child(t1)

	var t2 := Label.new()
	t2.text     = "Z  =  RECONECTAR"
	t2.position = Vector2(86, 114)
	t2.add_theme_font_size_override("font_size", 9)
	t2.add_theme_color_override("font_color", C_GREEN)
	t2.add_theme_font_override("font", _mono_font())
	panel.add_child(t2)

	add_child(panel)
	_game_over_panel = panel

# ── Loop ──────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if is_game_over: return
	_blink_t += delta
	_time_s  += delta

	# Timecode
	var ss := int(_time_s) % 60
	var mm := (int(_time_s) / 60) % 60
	var hh := int(_time_s) / 3600
	_lbl_time.text = "%02d:%02d:%02d" % [hh, mm, ss]

	# REC parpadeante
	_lbl_rec.modulate.a = 1.0 if fmod(_blink_t, 1.0) < 0.55 else 0.2

	if not player: return

	# HULL
	var hp: int = player.get("hp")
	hp = clampi(hp, 0, HP_MAX)
	var hull_str := _bar(hp, HP_MAX)
	var hull_col := C_GREEN if hp > 2 else (C_AMBER if hp > 1 else C_RED)
	_lbl_hull.text = hull_str
	_lbl_hull.add_theme_color_override("font_color", hull_col)

	# BOOST
	var is_active: bool = player.get("nitro_active")
	var charge: float   = player.get("nitro_charge")
	var timer: float    = player.get("nitro_timer")
	var fill: float
	var boost_col: Color
	if is_active:
		fill = timer / NITRO_ACTIVE_DUR
		boost_col = C_HOT
	elif charge >= NITRO_CHARGE_DUR:
		fill = 1.0
		boost_col = C_AMBER
	else:
		fill = charge / NITRO_CHARGE_DUR
		boost_col = C_GREEN
	_lbl_boost.text = _bar(int(fill * BOOST_BLOCKS), BOOST_BLOCKS)
	_lbl_boost.add_theme_color_override("font_color", boost_col)

	# SPD
	var vel: Variant = player.get("velocity")
	var spd: float   = abs((vel as Vector2).x) if vel is Vector2 else 0.0
	_lbl_spd.text = "SPD>%04d" % int(spd)

func _bar(filled: int, total: int) -> String:
	var s := ""
	for i in total:
		s += char(0x2588) if i < filled else char(0x2591)
	return s

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if is_game_over and event.is_action_pressed("attack"):
		get_tree().paused = false
		get_tree().reload_current_scene()

# ── API pública ───────────────────────────────────────────────────────────────

func show_game_over() -> void:
	if is_game_over: return
	is_game_over = true
	_game_over_panel.visible = true
	get_tree().paused = true
