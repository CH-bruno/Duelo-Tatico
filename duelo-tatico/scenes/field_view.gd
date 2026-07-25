extends Control

#
# ===========================
#     CONFIGURAÇÃO DE TESTE
# ===========================
#
# 1 = Mosaico Retrô 16-bit (Cadeiras/Torcida estática colorida)
# 2 = Estilo Clean / Sombra e Iluminação Minimalista
# 3 = Estática em Penumbra com Flashes de Câmera esporádicos
# 0 = Sem arquibancada
const CROWD_OPTION := 3

#
# ===========================
#         CORES
# ===========================
#

const GRASS_LIGHT = Color("#4caf50")
const GRASS_DARK  = Color("#3e9142")

const LINE_COLOR = Color.WHITE

const ACTIVE_GLOW = Color(1,0.92,0.35,0.18)
const AI_GLOW = Color(1,0.30,0.30,0.16)

const PLAYER_COLOR = Color("#4aa3ff")
const PLAYER_BORDER = Color("#0d325e")

const ENEMY_COLOR = Color("#ff6464")
const ENEMY_BORDER = Color("#5d1111")

const BALL_COLOR = Color.WHITE
const BALL_SHADOW = Color(0,0,0,0.35)

const TEXT_COLOR = Color.WHITE

#
# ===========================
#       ANIMAÇÕES
# ===========================
#

var visual_column := 0.0
var pulse_alpha := 0.75
var ball_rotation := 0.0

# Variáveis para o Flash da Câmera (Opção 3)
var flash_pos := Vector2.ZERO
var flash_alpha := 0.0

var _ball_tween : Tween
var _pulse_tween : Tween

#
# ===========================
#          READY
# ===========================
#

func _ready():
	GameState.state_changed.connect(_on_state_changed)
	visual_column = float(GameState.zone_idx)
	_start_pulse()
	set_process(true)


func _process(delta):
	ball_rotation += delta * 4.5

	# Lógica do Flash de Câmera esporádico (Opção 3)
	if CROWD_OPTION == 3:
		if randf() < 0.04 and flash_alpha <= 0.0:
			var side = randi() % 2
			var y_pos = randf_range(2, 16) if side == 0 else randf_range(size.y - 18, size.y - 2)
			flash_pos = Vector2(randf_range(10, size.x - 10), y_pos)
			flash_alpha = 1.0

		if flash_alpha > 0.0:
			flash_alpha -= delta * 4.0

	queue_redraw()


#
# ===========================
#    MUDANÇA DE POSSE
# ===========================
#

func _on_state_changed():
	var ai_has_ball = GameState.possession == GameState.Possession.AI

	var target = float(
		GameState.ai_active_column()
		if ai_has_ball
		else GameState.zone_idx
	)

	if is_equal_approx(target, visual_column):
		queue_redraw()
		return

	if _ball_tween:
		_ball_tween.kill()

	_ball_tween = create_tween()
	_ball_tween.set_trans(Tween.TRANS_BACK)
	_ball_tween.set_ease(Tween.EASE_OUT)

	_ball_tween.tween_method(
		_set_visual_column,
		visual_column,
		target,
		0.35
	)


func _set_visual_column(v):
	visual_column = v
	queue_redraw()


func _start_pulse():
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()

	_pulse_tween.tween_method(
		_set_pulse,
		0.35,
		0.85,
		0.7
	).set_trans(Tween.TRANS_SINE)

	_pulse_tween.tween_method(
		_set_pulse,
		0.85,
		0.35,
		0.7
	).set_trans(Tween.TRANS_SINE)


func _set_pulse(v):
	pulse_alpha = v
	queue_redraw()


#
# ===========================
#   OPÇÕES DE ARQUIBANCADA
# ===========================
#

# Opção 1: Mosaico 16-bit estático (Estilo SNES)
func _draw_crowd_option_1(h: float):
	var crowd_colors = [
		Color("#e74c3c"), Color("#3498db"), Color("#f1c40f"), 
		Color("#ecf0f1"), Color("#95a5a6"), Color("#2ecc71")
	]

	draw_rect(Rect2(0, 0, size.x, h), Color("#2c3e50"))
	draw_rect(Rect2(0, size.y - h, size.x, h), Color("#2c3e50"))

	var step := 8.0
	for row in range(2):
		for i in range(int(size.x / step)):
			var color_idx = (i * 7 + row * 3) % crowd_colors.size()
			var c = crowd_colors[color_idx]

			draw_rect(Rect2(i * step + 1, 2 + row * 8, step - 2, 6), c)
			draw_rect(Rect2(i * step + 1, size.y - h + 2 + row * 8, step - 2, 6), c)


# Opção 2: Estilo Clean / Degradê Discreto
func _draw_crowd_option_2(h: float):
	draw_rect(Rect2(0, 0, size.x, h), Color("#1e272e"))
	draw_rect(Rect2(0, size.y - h, size.x, h), Color("#1e272e"))

	draw_rect(Rect2(0, h - 3, size.x, 3), Color("#0f1418"))
	draw_rect(Rect2(0, size.y - h, size.x, 3), Color("#0f1418"))

	var step := 24.0
	for i in range(int(size.x / step)):
		draw_rect(Rect2(i * step + 4, 4, 4, 3), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(i * step + 4, size.y - h + 10, 4, 3), Color(1, 1, 1, 0.12))


# Opção 3: Estática em Penumbra com Flashes
func _draw_crowd_option_3(h: float):
	draw_rect(Rect2(0, 0, size.x, h), Color("#1a1a24"))
	draw_rect(Rect2(0, size.y - h, size.x, h), Color("#1a1a24"))

	var step := 7.0
	for row in range(3):
		for i in range(int(size.x / step)):
			var seed_val = (i * 13 + row * 7) % 100
			if seed_val > 25:
				var dot_color = Color("#34495e") if seed_val % 2 == 0 else Color("#576574")
				draw_circle(Vector2(i * step + 3, 3 + row * 5), 1.5, dot_color)
				draw_circle(Vector2(i * step + 3, size.y - h + 3 + row * 5), 1.5, dot_color)

	if flash_alpha > 0.0:
		draw_circle(flash_pos, 3.0, Color(1, 1, 1, flash_alpha))
		draw_circle(flash_pos, 6.0, Color(1, 1, 1, flash_alpha * 0.4))


#
# ===========================
#          DRAW
# ===========================
#

func _draw_player(pos:Vector2,color:Color,border:Color):
	draw_circle(pos + Vector2(2,3),11,Color(0,0,0,0.25))
	draw_circle(pos,10,border)
	draw_circle(pos,8,color)
	draw_circle(pos + Vector2(-2,-2), 2.2, Color.WHITE)


func _draw_ball(pos:Vector2):
	draw_circle(pos + Vector2(2,3), 10, BALL_SHADOW)
	draw_circle(pos, 8, BALL_COLOR)

	var p = pos + Vector2(cos(ball_rotation)*4, sin(ball_rotation)*4)
	draw_circle(p, 1.6, Color.BLACK)
	draw_circle(pos + Vector2(-2,-2), 2, Color(1,1,1,0.9))


func _draw():
	var zone_count = GameState.ZONES.size()
	var zone_width = size.x / zone_count
	var mid_y = size.y / 2.0
	
	var font = ThemeDB.fallback_font
	var font_size = 13

	#
	# ===== 1. FUNDO DO ESTÁDIO =====
	#
	draw_rect(Rect2(Vector2.ZERO, size), Color("#151515"))

	#
	# ===== 2. DESENHO DA ARQUIBANCADA (SELEÇÃO) =====
	#
	var crowd_height := 20.0 if CROWD_OPTION != 0 else 0.0

	match CROWD_OPTION:
		1: _draw_crowd_option_1(crowd_height)
		2: _draw_crowd_option_2(crowd_height)
		3: _draw_crowd_option_3(crowd_height)

	#
	# ===== 3. GRAMADO =====
	#
	var field_margin := crowd_height

	draw_rect(
		Rect2(
			field_margin,
			field_margin,
			size.x - field_margin * 2,
			size.y - field_margin * 2
		),
		GRASS_DARK
	)

	var stripe_h = (size.y - field_margin * 2) / 12.0

	for i in range(12):
		if i % 2 == 0:
			draw_rect(
				Rect2(
					field_margin,
					field_margin + i * stripe_h,
					size.x - field_margin * 2,
					stripe_h
				),
				GRASS_LIGHT
			)

	#
	# ===== 4. DIVISÕES DAS COLUNAS =====
	#
	for i in range(1, zone_count):
		draw_line(
			Vector2(i * zone_width, field_margin),
			Vector2(i * zone_width, size.y - field_margin),
			Color(1, 1, 1, 0.08),
			2
		)

	#
	# ===== 5. LINHA CENTRAL E CÍRCULO =====
	#
	draw_line(
		Vector2(size.x / 2.0, field_margin),
		Vector2(size.x / 2.0, size.y - field_margin),
		LINE_COLOR,
		3
	)

	draw_arc(
		Vector2(size.x / 2.0, size.y / 2.0),
		46,
		0,
		TAU,
		72,
		LINE_COLOR,
		3
	)

	draw_circle(
		Vector2(size.x / 2.0, size.y / 2.0),
		3,
		LINE_COLOR
	)

	#
	# ===== 6. ÁREAS =====
	#
	var area_w = 58
	var area_h = 150

	draw_rect(Rect2(field_margin, mid_y - area_h / 2.0, area_w, area_h), LINE_COLOR, false, 3)
	draw_rect(Rect2(size.x - field_margin - area_w, mid_y - area_h / 2.0, area_w, area_h), LINE_COLOR, false, 3)

	var small_w = 28
	var small_h = 76

	draw_rect(Rect2(field_margin, mid_y - small_h / 2.0, small_w, small_h), LINE_COLOR, false, 3)
	draw_rect(Rect2(size.x - field_margin - small_w, mid_y - small_h / 2.0, small_w, small_h), LINE_COLOR, false, 3)

	#
	# ===== 7. GOLS =====
	#
	draw_rect(Rect2(field_margin - 8, mid_y - 36, 8, 72), Color(0.92, 0.92, 0.92))
	draw_rect(Rect2(size.x - field_margin, mid_y - 36, 8, 72), Color(0.92, 0.92, 0.92))

	#
	# ===== 8. JOGADORES =====
	#
	var ai_has_ball = GameState.possession == GameState.Possession.AI
	var active_column = GameState.ai_active_column() if ai_has_ball else GameState.zone_idx

	for i in range(zone_count):

		if i == active_column:
			draw_rect(
				Rect2(
					i * zone_width,
					field_margin,
					zone_width,
					size.y - field_margin * 2
				),
				AI_GLOW if ai_has_ball else ACTIVE_GLOW
			)

		var attacker = GameState.team_player_at_column(i, !ai_has_ball)
		var defender = GameState.team_player_at_column(i, ai_has_ball)

		var px = i * zone_width + zone_width / 2.0

		var top = Vector2(px, 85)
		var bottom = Vector2(px, size.y - 85)

		if ai_has_ball:
			_draw_player(top, ENEMY_COLOR, ENEMY_BORDER)
			_draw_player(bottom, PLAYER_COLOR, PLAYER_BORDER)
		else:
			_draw_player(top, PLAYER_COLOR, PLAYER_BORDER)
			_draw_player(bottom, ENEMY_COLOR, ENEMY_BORDER)

		draw_string(font, Vector2(px - 45, 108), attacker["role"], HORIZONTAL_ALIGNMENT_CENTER, 90, font_size, TEXT_COLOR)
		draw_string(font, Vector2(px - 45, 124), attacker["name"], HORIZONTAL_ALIGNMENT_CENTER, 90, 11, TEXT_COLOR)

		draw_string(font, Vector2(px - 45, size.y - 54), defender["role"], HORIZONTAL_ALIGNMENT_CENTER, 90, font_size, TEXT_COLOR)
		draw_string(font, Vector2(px - 45, size.y - 38), defender["name"], HORIZONTAL_ALIGNMENT_CENTER, 90, 11, TEXT_COLOR)

		if i == active_column:
			draw_string(
				font,
				Vector2(px - 12, mid_y + 5),
				"VS",
				HORIZONTAL_ALIGNMENT_CENTER,
				25,
				15,
				Color(1, 1, 1, pulse_alpha)
			)

	#
	# ===== 9. BOLA =====
	#
	var ball_x = visual_column * zone_width + zone_width / 2.0
	var ball_y = 150 if !ai_has_ball else size.y - 150

	_draw_ball(Vector2(ball_x, ball_y))
