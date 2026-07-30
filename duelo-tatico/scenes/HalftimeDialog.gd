extends ColorRect
# HalftimeDialog.gd — Tela de Intervalo da Partida (Overlay Escuro + Modal Centralizado)

const AppTheme = preload("res://scripts/AppTheme.gd")

signal continued

func setup(data: Dictionary = {}) -> void:
	# 1. Torna este nó um Fundo Transparente Escuro (Modal Overlay)
	color = Color(0, 0, 0, 0.65)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 2. Painel Centralizado da Janela
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	
	# Âncoras perfeitamente centralizadas
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = AppTheme.PANEL
	style.border_color = AppTheme.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# 3. Conteúdo Interno
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Título
	var lbl_title = Label.new()
	lbl_title.text = "⏱ INTERVALO"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 20)
	lbl_title.add_theme_color_override("font_color", AppTheme.GOLD)
	vbox.add_child(lbl_title)

	vbox.add_child(HSeparator.new())

	# ✅ PLACAR: Busca prioritariamente do GameState para evitar exibir 0x0 incorreto
	var player_goals = data.get("goals", GameState.goals)
	var ai_goals = data.get("ai_goals", GameState.ai_goals)

	var lbl_score = Label.new()
	lbl_score.text = "%d  ×  %d" % [player_goals, ai_goals]
	lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_score.add_theme_font_size_override("font_size", 32)
	vbox.add_child(lbl_score)

	# Estatísticas Rápidas
	var stats_dict = GameState.match_stats()
	var lbl_stats = Label.new()
	lbl_stats.text = "Chutes: %d    │    Passes Certo: %d    │    Desarmes: %d" % [
		stats_dict.get("shots", 0),
		stats_dict.get("passes_completed", 0),
		stats_dict.get("tackles", 0)
	]
	lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_stats.add_theme_font_size_override("font_size", 11)
	lbl_stats.add_theme_color_override("font_color", AppTheme.TEXT_COLOR)
	vbox.add_child(lbl_stats)

	var lbl_info = Label.new()
	lbl_info.text = "⚡ Jogadores recuperaram stamina no vestiário!"
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info.add_theme_font_size_override("font_size", 11)
	lbl_info.add_theme_color_override("font_color", AppTheme.SUCCESS)
	vbox.add_child(lbl_info)

	vbox.add_child(HSeparator.new())

	# Botão Continuar
	var btn = Button.new()
	btn.text = "Voltar para o 2º Tempo ▶"
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(func():
		continued.emit()
		queue_free()
	)
	vbox.add_child(btn)
