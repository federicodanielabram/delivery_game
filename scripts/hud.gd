extends CanvasLayer

const BLOCK_W   := 8
const BLOCK_H   := 6
const BLOCK_GAP := 2
const COLOR_ON  := Color(0.0,  1.0,  0.85, 1.0)
const COLOR_OFF := Color(0.06, 0.06, 0.14, 1.0)

var player:          Node      = null
var hp_blocks:       Array     = []
var game_over_panel: ColorRect = null
var is_game_over              := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	player = get_tree().get_first_node_in_group("player")
	_build_player_hp()
	_build_game_over_screen()

# ── Barra de vida del jugador ─────────────────────────────────────────────

func _build_player_hp() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0, 0, 0, 0.55)
	bg.position = Vector2(2, 2)
	bg.size     = Vector2(5 * (BLOCK_W + BLOCK_GAP) - BLOCK_GAP + 4, BLOCK_H + 4)
	add_child(bg)

	for i in 5:
		var b := ColorRect.new()
		b.size     = Vector2(BLOCK_W, BLOCK_H)
		b.position = Vector2(4 + i * (BLOCK_W + BLOCK_GAP), 3)
		b.color    = COLOR_ON
		add_child(b)
		hp_blocks.append(b)

# ── Pantalla de Game Over ─────────────────────────────────────────────────

func _build_game_over_screen() -> void:
	var panel := ColorRect.new()
	panel.color    = Color(0, 0, 0, 0.78)
	panel.position = Vector2.ZERO
	panel.size     = Vector2(320, 224)
	panel.visible  = false

	var lbl_title := Label.new()
	lbl_title.text     = "GAME  OVER"
	lbl_title.position = Vector2(88, 88)
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	panel.add_child(lbl_title)

	var lbl_hint := Label.new()
	lbl_hint.text     = "Z  =  REINICIAR"
	lbl_hint.position = Vector2(96, 120)
	lbl_hint.add_theme_font_size_override("font_size", 10)
	lbl_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	panel.add_child(lbl_hint)

	add_child(panel)
	game_over_panel = panel

# ── Loop ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not player or is_game_over: return
	var current_hp: int = player.get("hp")
	for i in hp_blocks.size():
		(hp_blocks[i] as ColorRect).color = COLOR_ON if i < current_hp else COLOR_OFF

func _input(event: InputEvent) -> void:
	if is_game_over and event.is_action_pressed("attack"):
		get_tree().paused = false
		get_tree().reload_current_scene()

# ── API pública ───────────────────────────────────────────────────────────

func show_game_over() -> void:
	if is_game_over: return
	is_game_over = true
	game_over_panel.visible = true
	get_tree().paused = true
