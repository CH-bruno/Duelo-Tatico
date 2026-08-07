extends Control
# MatchStats.gd — Overlay de Estatísticas Pós-Jogo (Com suporte a W.O.).

const AppTheme = preload("res://scripts/AppTheme.gd")
const UIUtils = preload("res://scripts/UIUtils.gd")

@onready var background: ColorRect = $Background
@onready var panel: Panel = $MarginContainer/Panel
@onready var grid: GridContainer = $MarginContainer/Panel/MarginContainer/VBoxContainer/StatsGrid
@onready var close_button: Button = $MarginContainer/Panel/MarginContainer/VBoxContainer/CloseButton
@onready var title_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/Title


func _ready():
	theme = AppTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fundo escuro do overlay com transparência
	if background:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.color = Color(0, 0, 0, 0.75)
		background.mouse_filter = Control.MOUSE_FILTER_STOP

	# Estilização do painel central
	if panel:
		panel.custom_minimum_size = Vector2(550, 450)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = AppTheme.PANEL
		panel_style.border_color = AppTheme.GOLD
		panel_style.set_border_width_all(1)
		panel_style.set_corner_radius_all(10)
		panel_style.set_content_margin_all(16)
		panel.add_theme_stylebox_override("panel", panel_style)

	if grid:
		grid.columns = 2

	# 🏆 AVALIAÇÃO DE VITÓRIA / DERROTA (RESPEITA W.O.)
	var is_victory := _is_player_winner()

	# Configuração do botão de fechar/avançar
	if close_button:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		UIUtils.add_press_feedback(close_button)
		
		if not close_button.pressed.is_connected(_on_close_pressed):
			close_button.pressed.connect(_on_close_pressed)

		if is_victory:
			if GameState.campaign_stage >= GameState.MAX_CAMPAIGN_STAGE:
				close_button.text = "Concluir Campanha"
			else:
				close_button.text = "Próxima Partida"
		else:
			close_button.text = "Tentar Novamente"

	# Configuração do título de resultado
	if title_label:
		if GameState.walkover_winner == "PLAYER":
			title_label.text = "VITÓRIA POR W.O.!"
			title_label.add_theme_color_override("font_color", AppTheme.GOLD)
		elif GameState.walkover_winner == "AI":
			title_label.text = "DERROTA POR W.O.!"
			title_label.add_theme_color_override("font_color", AppTheme.DANGER)
		elif GameState.goals > GameState.ai_goals:
			title_label.text = "VITÓRIA!"
			title_label.add_theme_color_override("font_color", AppTheme.GOLD)
		elif GameState.goals == GameState.ai_goals:
			title_label.text = "EMPATE!"
			title_label.add_theme_color_override("font_color", AppTheme.TEXT_COLOR)
		else:
			title_label.text = "DERROTA!"
			title_label.add_theme_color_override("font_color", AppTheme.DANGER)

	_load_stats()


# 🎯 Checagem centralizada de vencedor
func _is_player_winner() -> bool:
	if GameState.walkover_winner != "":
		return GameState.walkover_winner == "PLAYER"
	return GameState.goals > GameState.ai_goals


func _load_stats():
	if not grid:
		return

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	if not GameState.has_method("match_stats"):
		add_stat("Erro", "Estatísticas indisponíveis")
		return

	var s: Dictionary = GameState.match_stats()

	add_stat("Placar", "%d x %d" % [s.get("goals", 0), s.get("goals_ai", 0)])

	add_stat(
		"Passes",
		"%d/%d (%s)" % [
			s.get("passes_completed", 0),
			s.get("passes_attempted", 0),
			percent(s.get("passes_completed", 0), s.get("passes_attempted", 0))
		]
	)

	add_stat(
		"Dribles",
		"%d/%d (%s)" % [
			s.get("dribbles_completed", 0),
			s.get("dribbles_attempted", 0),
			percent(s.get("dribbles_completed", 0), s.get("dribbles_attempted", 0))
		]
	)

	add_stat(
		"Fintas",
		"%d/%d (%s)" % [
			s.get("feints_completed", 0),
			s.get("feints_attempted", 0),
			percent(s.get("feints_completed", 0), s.get("feints_attempted", 0))
		]
	)

	add_stat("Finalizações", "%d" % s.get("shots", 0))

	add_stat(
		"No alvo",
		"%d (%s)" % [
			s.get("shots_on_target", 0),
			percent(s.get("shots_on_target", 0), s.get("shots", 0))
		]
	)

	add_stat("Chutes longos", "%d" % s.get("long_shots", 0))

	add_stat(
		"No alvo (longos)",
		"%d (%s)" % [
			s.get("long_shots_on_target", 0),
			percent(s.get("long_shots_on_target", 0), s.get("long_shots", 0))
		]
	)

	add_stat("Interceptações", str(s.get("interceptions", 0)))
	add_stat("Desarmes", str(s.get("tackles", 0)))
	add_stat("Bloqueios", str(s.get("blocks", 0)))
	add_stat("Perdas de posse", str(s.get("turnovers", 0)))
	add_stat("XP ganho", "+%d" % s.get("xp", 0))
	add_stat("Rodadas", str(s.get("rounds", 0)))


func add_stat(nome: String, valor: String) -> void:
	if not grid:
		return

	var l = Label.new()
	l.text = nome
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", AppTheme.TEXT_COLOR)

	var v = Label.new()
	v.text = valor
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_font_size_override("font_size", 15)
	v.add_theme_color_override("font_color", AppTheme.GOLD)

	grid.add_child(l)
	grid.add_child(v)


func _on_close_pressed():
	queue_free()

	if _is_player_winner():
		if GameState.game_mode == GameState.GameMode.CAMPAIGN:
			if GameState.campaign_stage < GameState.MAX_CAMPAIGN_STAGE:
				GameState.next_match()
				get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")
			else:
				GameState.reset_game()
				get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
		else:
			GameState.next_challenge_round()
	else:
		if GameState.game_mode == GameState.GameMode.CAMPAIGN:
			GameState.reset_game()
			get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")
		else:
			GameState.reset_game()


func percent(success: int, total: int) -> String:
	if total <= 0:
		return "0%"
	return "%d%%" % int(round(float(success) * 100.0 / float(total)))
