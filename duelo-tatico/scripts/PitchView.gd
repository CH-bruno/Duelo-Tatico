extends Control
# PitchView.gd — Renderizador 2D do Campo, Arquibancada, Jogadores e Bola.

const AppTheme = preload("res://scripts/AppTheme.gd")

# ===========================
#             CORES
# ===========================
const GRASS_LIGHT = Color("#4caf50")
const GRASS_DARK  = Color("#3e9142")

const LINE_COLOR = AppTheme.TEXT_COLOR

var ACTIVE_GLOW = AppTheme.GOLD.darkened(0.1)
var AI_GLOW = AppTheme.DANGER

const PLAYER_COLOR = Color("#4aa3ff")
const PLAYER_BORDER = Color("#0d325e")

const ENEMY_COLOR = Color("#ff6464")
const ENEMY_BORDER = Color("#5d1111")

const EJECTED_COLOR = Color(0.2, 0.2, 0.2, 0.5)
const EJECTED_BORDER = Color(0.4, 0.1, 0.1, 0.6)

const BALL_COLOR = AppTheme.TEXT_COLOR
const BALL_SHADOW = Color(0, 0, 0, 0.35)

# ===========================
#           ANIMAÇÕES
# ===========================
var visual_column := 0.0
var pulse_alpha := 0.75
var ball_rotation := 0.0

var flash_pos := Vector2.ZERO
var flash_alpha := 0.0

var _pulse_tween: Tween


func _ready():
	ACTIVE_GLOW.a = 0.18
	AI_GLOW.a = 0.16

	visual_column = float(_target_column())
	_start_pulse()
	set_process(true)


func _process(delta):
	ball_rotation += delta * 4.5

	# 🎯 A bola sempre persegue a coluna correta a cada frame, lendo o
	# estado atual do jogo direto — nada de Tween/sinal aqui. Um Tween
	# criado e morto repetidamente em trocas de posse encadeadas (ex: o
	# passe automático de zona desprotegida, seguido do próximo turno)
	# podia ficar "preso" num alvo antigo; perseguir o alvo todo frame
	# elimina essa possibilidade por completo.
	var target = float(_target_column())
	if not is_equal_approx(target, visual_column):
		visual_column = move_toward(visual_column, target, delta * 6.0)

	if randf() < 0.04 and flash_alpha <= 0.0:
		var side = randi() % 2
		var y_pos = randf_range(2, 16) if side == 0 else randf_range(size.y - 18, size.y - 2)
		flash_pos = Vector2(randf_range(10, size.x - 10), y_pos)
		flash_alpha = 1.0

	if flash_alpha > 0.0:
		flash_alpha -= delta * 4.0

	queue_redraw()


# ===========================
#      CÁLCULO DE COLUNAS
# ===========================
func _target_column() -> int:
	var ai_has_ball = (GameState.possession == GameState.Possession.AI)

	if ai_has_ball:
		# 🎯 squad e opponent_squad seguem sempre a ordem fixa ZAG/VOL/MEI/CA.
		# Como o pareamento de marcação é CA<->ZAG e MEI<->VOL, a coluna do
		# seu time que exibe o atacante ativo da IA é sempre "3 - índice do
		# atacante" — cálculo direto a partir de ai_active_idx, sem precisar
		# comparar nome/role (que ficava defasado durante trocas de posse
		# encadeadas, como no passe automático de zona desprotegida).
		return clampi(3 - int(GameState.ai_active_idx), 0, 3)
	else:
		return clampi(int(GameState.active_idx), 0, 3)


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


func _set_pulse(v: float):
	pulse_alpha = v
	queue_redraw()


# ===========================
#        ARQUIBANCADA
# ===========================
func _draw_crowd(h: float):
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


# ===========================
#            DRAW
# ===========================
func _draw_player(pos: Vector2, color: Color, border: Color, is_ejected: bool = false, has_yellow: bool = false, radius: float = 8.0):
	if is_ejected:
		# Cartão Vermelho (Jogador Indisponível/Escurecido)
		draw_circle(pos + Vector2(2, 3), radius + 3, Color(0, 0, 0, 0.15))
		draw_circle(pos, radius + 2, EJECTED_BORDER)
		draw_circle(pos, radius, EJECTED_COLOR)
		# Desenha Cartão Vermelho Visual ao lado da peça
		draw_rect(Rect2(pos.x + radius, pos.y - 10, 6, 9), Color(0.9, 0.1, 0.1))
	else:
		draw_circle(pos + Vector2(2, 3), radius + 3, Color(0, 0, 0, 0.25))
		draw_circle(pos, radius + 2, border)
		draw_circle(pos, radius, color)
		draw_circle(pos + Vector2(-2, -2), 2.2, Color.WHITE)

		# 🟨 Desenha Cartão Amarelo Visual ao lado da peça (se estiver amarelado)
		if has_yellow:
			draw_rect(Rect2(pos.x + radius, pos.y - 10, 6, 9), Color(0.95, 0.8, 0.1))


func _draw_ball(pos: Vector2):
	draw_circle(pos + Vector2(2, 3), 10, BALL_SHADOW)
	draw_circle(pos, 8, BALL_COLOR)

	var p = pos + Vector2(cos(ball_rotation) * 4, sin(ball_rotation) * 4)
	draw_circle(p, 1.6, Color.BLACK)
	draw_circle(pos + Vector2(-2, -2), 2, Color(1, 1, 1, 0.9))


func _draw_stamina_bar(center_bottom: Vector2, stamina: float, font: Font) -> void:
	var bar_w := 44.0
	var bar_h := 5.0
	var pct := clampf(stamina / 100.0, 0.0, 1.0)
	var top_left := center_bottom - Vector2(bar_w / 2.0, bar_h)

	# Fundo
	draw_rect(Rect2(top_left, Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.45))

	# Preenchimento (vermelho -> amarelo -> verde conforme a energia)
	var fill_color = Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.85, 0.35), pct)
	if pct > 0.0:
		draw_rect(Rect2(top_left, Vector2(bar_w * pct, bar_h)), fill_color)

	# Contorno
	draw_rect(Rect2(top_left, Vector2(bar_w, bar_h)), Color(1, 1, 1, 0.3), false, 1.0)

	# 🔋 Ícone de energia — mesmo padrão usado na tela de Escalação
	var energy_icon = "🔋" if stamina >= 75.0 else ("🪫" if stamina >= 50.0 else "⚠️")
	draw_string(font, top_left + Vector2(bar_w + 4, bar_h + 1), energy_icon, HORIZONTAL_ALIGNMENT_LEFT, 20, 12)


# 🧤 Goleiro — desenhado perto da própria meta (esquerda = seu, direita = da IA)
func _draw_goalkeeper(pos: Vector2, is_player: bool, font: Font) -> void:
	var color = PLAYER_COLOR if is_player else ENEMY_COLOR
	var border = PLAYER_BORDER if is_player else ENEMY_BORDER

	_draw_player(pos, color, border, false, false, 9.0)

	var label = "GOL"
	var name_str = ""
	if is_player:
		name_str = GameState.active_goalkeeper().get("name", "")
	else:
		name_str = GameState.current_opponent_team().get("goalkeeper", {}).get("name", "Goleiro")

	# 🏷️ Fundo atrás do rótulo/nome — sem isso, as linhas brancas da
	# grande área/pequena área (bem perto da meta) atrapalhavam a leitura
	var label_bg = Rect2(pos.x - 38, pos.y - 32, 76, 42)
	draw_rect(label_bg, Color(0, 0, 0, 0.6))
	draw_rect(label_bg, Color(1, 1, 1, 0.12), false, 1.0)

	draw_string(font, pos + Vector2(-30, -22), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 11, AppTheme.TEXT_COLOR)
	draw_string(font, pos + Vector2(-30, -9), name_str, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, AppTheme.TEXT_COLOR)

	# Só o SEU goleiro tem energia rastreada — a IA não tem stamina própria
	if is_player:
		_draw_stamina_bar(pos + Vector2(0, 24), GameState.get_gk_stamina(), font)


func _draw():
	var zone_count = GameState.ZONES.size()
	var zone_width = size.x / zone_count
	var mid_y = size.y / 2.0

	var font = ThemeDB.fallback_font
	var font_size = 13

	# ===== 1. FUNDO DO ESTÁDIO =====
	draw_rect(Rect2(Vector2.ZERO, size), Color("#151515"))

	# ===== 2. ARQUIBANCADA =====
	var crowd_height := 20.0
	_draw_crowd(crowd_height)

	# ===== 3. GRAMADO =====
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

	# ===== 4. DIVISÕES DAS COLUNAS =====
	for i in range(1, zone_count):
		draw_line(
			Vector2(i * zone_width, field_margin),
			Vector2(i * zone_width, size.y - field_margin),
			Color(1, 1, 1, 0.08),
			2
		)

	# ===== 5. LINHA CENTRAL E CÍRCULO =====
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

	# ===== 6. ÁREAS =====
	var area_w = 58
	var area_h = 150

	draw_rect(Rect2(field_margin, mid_y - area_h / 2.0, area_w, area_h), LINE_COLOR, false, 3)
	draw_rect(Rect2(size.x - field_margin - area_w, mid_y - area_h / 2.0, area_w, area_h), LINE_COLOR, false, 3)

	var small_w = 28
	var small_h = 76

	draw_rect(Rect2(field_margin, mid_y - small_h / 2.0, small_w, small_h), LINE_COLOR, false, 3)
	draw_rect(Rect2(size.x - field_margin - small_w, mid_y - small_h / 2.0, small_w, small_h), LINE_COLOR, false, 3)

	# ===== 7. GOLS =====
	draw_rect(Rect2(field_margin - 8, mid_y - 36, 8, 72), Color(0.92, 0.92, 0.92))
	draw_rect(Rect2(size.x - field_margin, mid_y - 36, 8, 72), Color(0.92, 0.92, 0.92))

	# ===== 7B. GOLEIROS — na faixa central, perto de cada meta =====
	# Esquerda = seu goleiro (sua meta) / Direita = goleiro da IA (meta deles)
	_draw_goalkeeper(Vector2(field_margin + 22, mid_y), true, font)
	_draw_goalkeeper(Vector2(size.x - field_margin - 22, mid_y), false, font)

	# ===== 8. JOGADORES (ALINHAMENTO POR DUELO MATCHUP) =====
	var ai_has_ball = (GameState.possession == GameState.Possession.AI)
	var active_column = _target_column()

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

		var my_player = GameState.squad[clampi(i, 0, GameState.squad.size() - 1)]
		var opp_player = Matchups.opponent_marker_for_player(GameState, my_player)

		# Verificação de expulsão
		var my_is_ejected = my_player.get("is_ejected", false)
		var opp_is_ejected = opp_player.get("is_ejected", false)

		# Verificação de cartão amarelo
		var roster_idx = GameState.starters[clampi(i, 0, GameState.starters.size() - 1)]
		var my_has_yellow = GameState.yellow_cards.get(roster_idx, false) and not my_is_ejected
		var opp_has_yellow = opp_player.get("has_yellow", false) and not opp_is_ejected

		var px = i * zone_width + zone_width / 2.0

		var top_pos = Vector2(px, 75)
		var bottom_pos = Vector2(px, size.y - 75)

		# Desenha IA (Topo)
		_draw_player(top_pos, ENEMY_COLOR, ENEMY_BORDER, opp_is_ejected, opp_has_yellow)
		# Desenha Usuário (Baixo)
		_draw_player(bottom_pos, PLAYER_COLOR, PLAYER_BORDER, my_is_ejected, my_has_yellow)

		# Textos da IA (Topo)
		var opp_prefix = "🟥 " if opp_is_ejected else ("🟨 " if opp_has_yellow else "")
		var opp_name = opp_prefix + opp_player.get("name", "")
		var opp_color = Color(0.9, 0.3, 0.3) if opp_is_ejected else (Color(1.0, 0.85, 0.3) if opp_has_yellow else AppTheme.TEXT_COLOR)
		draw_string(font, Vector2(px - 45, 48), opp_player.get("role", ""), HORIZONTAL_ALIGNMENT_CENTER, 90, font_size, opp_color)
		draw_string(font, Vector2(px - 45, 62), opp_name, HORIZONTAL_ALIGNMENT_CENTER, 90, 11, opp_color)

		# Textos do Usuário (Baixo)
		var my_prefix = "🟥 " if my_is_ejected else ("🟨 " if my_has_yellow else "")
		var my_name = my_prefix + my_player.get("name", "")
		var my_color = Color(0.9, 0.3, 0.3) if my_is_ejected else (Color(1.0, 0.85, 0.3) if my_has_yellow else AppTheme.TEXT_COLOR)
		draw_string(font, Vector2(px - 45, size.y - 48), my_player.get("role", ""), HORIZONTAL_ALIGNMENT_CENTER, 90, font_size, my_color)
		draw_string(font, Vector2(px - 45, size.y - 32), my_name, HORIZONTAL_ALIGNMENT_CENTER, 90, 11, my_color)

		# ⚡ Barra de energia (só time do jogador — a IA não tem stamina)
		if not my_is_ejected:
			_draw_stamina_bar(Vector2(px, size.y - 20), GameState.get_stamina(roster_idx), font)

		if i == active_column and not my_is_ejected and not opp_is_ejected:
			draw_string(
				font,
				Vector2(px - 12, mid_y + 5),
				"VS",
				HORIZONTAL_ALIGNMENT_CENTER,
				25,
				15,
				Color(1, 1, 1, pulse_alpha)
			)

	# ===== 9. BOLA =====
	var ball_x = visual_column * zone_width + zone_width / 2.0
	var ball_y = 75.0 if ai_has_ball else (size.y - 75.0)

	_draw_ball(Vector2(ball_x, ball_y))
