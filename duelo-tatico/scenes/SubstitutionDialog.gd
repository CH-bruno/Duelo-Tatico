extends ColorRect
# SubstitutionDialog.gd — Modal de Substituição Expandido e Detalhado

const AppTheme = preload("res://scripts/AppTheme.gd")

signal closed

# Função utilitária para ícones de bateria
func _stamina_icon(st: int) -> String:
	if st >= 75:
		return "🔋"
	elif st >= 40:
		return "🪫"
	else:
		return "🪫"


func setup() -> void:
	color = Color(0, 0, 0, 0.75)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel = PanelContainer.new()
	panel.name = "DialogPanel"
	# Aumentamos a largura para caber com folga as informações do reserva
	panel.custom_minimum_size = Vector2(540, 0)
	
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
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_build_ui(panel)


func _build_ui(panel: PanelContainer) -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Título
	var title = Label.new()
	title.text = "🔄 SUBSTITUIÇÕES (%d restantes)" % GameState.substitutions_left
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", AppTheme.GOLD)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Linhas das 4 posições
	for role_idx in range(RosterData.ROLES.size()):
		var role = RosterData.ROLES[role_idx]
		var starter_roster_idx = GameState.starters[role_idx]
		var starter_p = RosterData.ROSTER[starter_roster_idx]
		var st = int(GameState.get_stamina(starter_roster_idx))

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		# Coluna 1: Informações do Titular Atual
		var lbl_starter = Label.new()
		lbl_starter.text = "[%s] %s  %s %d%%" % [role, starter_p["name"], _stamina_icon(st), st]
		lbl_starter.custom_minimum_size = Vector2(210, 0)
		lbl_starter.add_theme_font_size_override("font_size", 12)
		if st < 50:
			lbl_starter.add_theme_color_override("font_color", AppTheme.DANGER)
		row.add_child(lbl_starter)

		# Seta Indicadora
		var lbl_arrow = Label.new()
		lbl_arrow.text = "➔"
		lbl_arrow.add_theme_font_size_override("font_size", 11)
		lbl_arrow.add_theme_color_override("font_color", AppTheme.MUTED)
		row.add_child(lbl_arrow)

		# Coluna 2: Informações do Reserva e Botão [Trocar]
		var bench_candidates = LineupManager.available_bench_for(GameState, role_idx)

		if bench_candidates.size() > 0 and GameState.substitutions_left > 0:
			var bench_container = VBoxContainer.new()
			bench_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			for bench_idx in bench_candidates:
				var bench_p = RosterData.ROSTER[bench_idx]
				var bench_st = int(GameState.get_stamina(bench_idx))

				var sub_row = HBoxContainer.new()
				sub_row.add_theme_constant_override("separation", 8)

				# Nome + Posição + Stamina
				var lbl_bench = Label.new()
				lbl_bench.text = "%s (%s)  %s %d%%" % [bench_p["name"], bench_p["role"], _stamina_icon(bench_st), bench_st]
				lbl_bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				lbl_bench.add_theme_font_size_override("font_size", 11)
				sub_row.add_child(lbl_bench)

				# Botão compacto "Trocar"
				var btn_sub = Button.new()
				btn_sub.text = "Trocar"
				btn_sub.custom_minimum_size = Vector2(75, 26)
				btn_sub.add_theme_font_size_override("font_size", 10)

				btn_sub.pressed.connect(func():
					if GameState.make_substitution(role_idx, bench_idx):
						_build_ui(panel)
				)
				sub_row.add_child(btn_sub)
				bench_container.add_child(sub_row)

			row.add_child(bench_container)
		else:
			var lbl_no_sub = Label.new()
			lbl_no_sub.text = "Sem opções" if bench_candidates.size() == 0 else "Esgotado"
			lbl_no_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl_no_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lbl_no_sub.add_theme_font_size_override("font_size", 11)
			lbl_no_sub.add_theme_color_override("font_color", AppTheme.MUTED)
			row.add_child(lbl_no_sub)

		vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	# Botão Voltar ao Jogo
	var btn_close = Button.new()
	btn_close.text = "Voltar ao Jogo ▶"
	btn_close.custom_minimum_size = Vector2(0, 34)
	btn_close.pressed.connect(func():
		closed.emit()
		queue_free()
	)
	vbox.add_child(btn_close)
