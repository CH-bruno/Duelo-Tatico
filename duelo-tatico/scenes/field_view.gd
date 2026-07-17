extends Control
# Desenha a "barra de campo" com as 4 zonas, a posição da bola,
# a marcação do gol e uma sombra sob a bola. Usa _draw() (desenho
# imediato do Godot): toda vez que queue_redraw() é chamado, o motor
# roda _draw() de novo do zero.

const ACTIVE_COLOR = Color(0.85, 0.65, 0.25)     # zona atual
const IDLE_COLOR = Color(0.16, 0.3, 0.2)          # zonas restantes
const BORDER_COLOR = Color(0.05, 0.08, 0.06)      # contorno entre zonas
const BALL_COLOR = Color(0.95, 0.95, 0.9)
const BALL_SHADOW_COLOR = Color(0, 0, 0, 0.35)
const GOAL_COLOR = Color(0.9, 0.9, 0.9, 0.8)

func _ready():
	GameState.state_changed.connect(func(): queue_redraw())


func _draw():
	var zone_count = GameState.ZONES.size()
	var zone_width = size.x / zone_count
	var gap = 4.0

	for i in range(zone_count):
		var color = ACTIVE_COLOR if i == GameState.zone_idx else IDLE_COLOR
		var rect = Rect2(i * zone_width, 0, zone_width - gap, size.y)
		draw_rect(rect, color)
		draw_rect(rect, BORDER_COLOR, false, 2.0)  # contorno fino, dá acabamento

	# Marcação do gol na última zona (Grande Área) — uma baliza com "rede".
	var goal_width = 16.0
	var goal_top = size.y * 0.22
	var goal_bottom = size.y * 0.78
	var goal_rect = Rect2(size.x - goal_width, goal_top, goal_width - 2, goal_bottom - goal_top)
	draw_rect(goal_rect, Color(1, 1, 1, 0.14))       # rede semi-transparente
	draw_rect(goal_rect, GOAL_COLOR, false, 3.0)      # trave contornada, bem mais grossa

	# Bolinha marcando a posição atual, com sombra por baixo pra dar profundidade.
	var ball_x = GameState.zone_idx * zone_width + zone_width / 2.0
	var ball_y = size.y / 2.0
	draw_circle(Vector2(ball_x + 2, ball_y + 3), 10.0, BALL_SHADOW_COLOR)
	draw_circle(Vector2(ball_x, ball_y), 10.0, BALL_COLOR)
	draw_circle(Vector2(ball_x - 3, ball_y - 3), 3.0, Color(1, 1, 1, 0.6))  # brilho
