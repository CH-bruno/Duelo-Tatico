extends Control
# Cada coluna é um duelo fixo daquela faixa do campo: quem ataca em cima,
# quem defende embaixo. A bola muda de coluna; o atacante muda com o
# passe; o defensor é sempre a coluna espelhada do outro time. Sem
# "3 - i" nem espelhamento aqui — tudo isso já vem resolvido do
# GameState via team_player_at_column().

const ACTIVE_COLOR = Color(0.85, 0.65, 0.25)
const AI_ACTIVE_COLOR = Color(0.80, 0.22, 0.22)
const IDLE_COLOR = Color(0.16, 0.30, 0.20)
const BORDER_COLOR = Color(0.05, 0.08, 0.06)
const BALL_COLOR = Color(0.95, 0.95, 0.90)
const AI_BALL_COLOR = Color(1.0, 0.35, 0.35)
const BALL_SHADOW_COLOR = Color(0, 0, 0, 0.35)
const GOAL_COLOR = Color(0.9, 0.9, 0.9, 0.8)
const TEXT_COLOR = Color(0.08, 0.08, 0.05)
const VS_COLOR = Color(1, 1, 1, 0.55)


func _ready():
	GameState.state_changed.connect(func(): queue_redraw())


func _draw():
	var zone_count = GameState.ZONES.size()
	var zone_width = size.x / zone_count
	var gap = 4.0
	var mid_y = size.y / 2.0

	var ai_has_ball = GameState.possession == GameState.Possession.AI
	var active_column = GameState.ai_active_column() if ai_has_ball else GameState.zone_idx

	var font = ThemeDB.fallback_font
	var font_size = 12

	for i in range(zone_count):
		var is_active = i == active_column
		var color = IDLE_COLOR
		if is_active:
			color = AI_ACTIVE_COLOR if ai_has_ball else ACTIVE_COLOR

		var rect = Rect2(i * zone_width, 0, zone_width - gap, size.y)
		draw_rect(rect, color)
		draw_rect(rect, BORDER_COLOR, false, 2.0)

		# Quem ataca fica sempre em cima, quem defende embaixo — mesma
		# regra pra toda coluna, ativa ou não.
		var attacker = GameState.team_player_at_column(i, not ai_has_ball)
		var defender = GameState.team_player_at_column(i, ai_has_ball)

		var top_text = "%s %s" % [attacker["role"], attacker["name"]]
		var bottom_text = "%s %s" % [defender["role"], defender["name"]]

		draw_string(font, Vector2(i * zone_width + 6, 16), top_text, HORIZONTAL_ALIGNMENT_LEFT, zone_width - gap - 10, font_size, TEXT_COLOR)
		draw_string(font, Vector2(i * zone_width + 6, size.y - 8), bottom_text, HORIZONTAL_ALIGNMENT_LEFT, zone_width - gap - 10, font_size, TEXT_COLOR)

		if is_active:
			# "VS" marca o duelo em disputa nessa coluna.
			draw_string(font, Vector2(i * zone_width + zone_width / 2.0 - 14, mid_y + 4), "VS", HORIZONTAL_ALIGNMENT_LEFT, 30, font_size, VS_COLOR)

	# Um gol em cada ponta — campo de mão dupla: seu time ataca pro
	# direito, o adversário ataca pro esquerdo.
	var goal_width = 16.0
	var goal_top = size.y * 0.22
	var goal_bottom = size.y * 0.78

	var right_goal = Rect2(size.x - goal_width, goal_top, goal_width - 2, goal_bottom - goal_top)
	draw_rect(right_goal, Color(1, 1, 1, 0.14))
	draw_rect(right_goal, GOAL_COLOR, false, 3.0)

	var left_goal = Rect2(2, goal_top, goal_width - 2, goal_bottom - goal_top)
	draw_rect(left_goal, Color(1, 1, 1, 0.14))
	draw_rect(left_goal, GOAL_COLOR, false, 3.0)

	# Bola na coluna ativa, do lado de quem está atacando (perto do topo
	# se é seu ataque, perto da base se é o da IA).
	var ball_x = active_column * zone_width + zone_width / 2.0
	var ball_y = mid_y - 22.0 if not ai_has_ball else mid_y + 22.0
	var ball_color = AI_BALL_COLOR if ai_has_ball else BALL_COLOR

	draw_circle(Vector2(ball_x + 2, ball_y + 3), 9.0, BALL_SHADOW_COLOR)
	draw_circle(Vector2(ball_x, ball_y), 9.0, ball_color)
	draw_circle(Vector2(ball_x - 3, ball_y - 3), 2.5, Color(1, 1, 1, 0.6))
