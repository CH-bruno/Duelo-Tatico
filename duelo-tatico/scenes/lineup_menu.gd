extends Control
# LineupMenu.gd — Prancha Tática & Escalação (Cards de Comparativo Lado a Lado)

const AppTheme = preload("res://scripts/AppTheme.gd")
const UIUtils = preload("res://scripts/UIUtils.gd")

var selected_role_idx: int = 0
var selected_candidate_idx: int = -1

# Nós da Interface
var pitch_view: Control
var back_button: Button
var confirm_button: Button
var comparison_container: VBoxContainer
var swap_button: Button
var bench_container: VBoxContainer


# Classe do Campo Tático 2D
class PitchView extends Control:
	var menu: Control

	func _init(p_menu: Control):
		menu = p_menu
		custom_minimum_size = Vector2(280, 0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	func _draw():
		var size_rect = Rect2(Vector2.ZERO, size)

		# Gramado
		draw_rect(size_rect, Color(0.06, 0.11, 0.08), true)
		draw_rect(size_rect, AppTheme.GOLD.darkened(0.4), false, 2.0)

		# Linhas do Campo
		var center_y = size.y / 2.0
		var center_x = size.x / 2.0
		var line_color = Color(1.0, 1.0, 1.0, 0.15)
		
		draw_line(Vector2(0, center_y), Vector2(size.x, center_y), line_color, 1.5)
		draw_arc(Vector2(center_x, center_y), min(size.x, size.y) * 0.15, 0, TAU, 32, line_color, 1.5)

		draw_rect(Rect2(center_x - 45, 0, 90, 35), line_color, false, 1.5)
		draw_rect(Rect2(center_x - 45, size.y - 35, 90, 35), line_color, false, 1.5)

		# Titulares (ZAG, VOL, MEI, CA)
		var roles_y_pct = [0.82, 0.62, 0.42, 0.22] # ZAG, VOL, MEI, CA
		var font = ThemeDB.fallback_font
		var font_size = 11

		for i in range(4):
			var pos = Vector2(center_x, size.y * roles_y_pct[i])
			var is_selected = (i == menu.selected_role_idx)

			var player_roster_idx = GameState.starters[i]
			var stamina_pct = GameState.get_stamina(player_roster_idx)

			var circle_color = AppTheme.GOLD if is_selected else Color(0.12, 0.20, 0.15)
			var border_color = AppTheme.GOLD if is_selected else Color(0.4, 0.55, 0.4)

			if is_selected:
				draw_circle(pos, 22, Color(0.85, 0.65, 0.25, 0.3))

			draw_circle(pos, 17, circle_color)
			draw_arc(pos, 17, 0, TAU, 24, border_color, 2.0)

			var role_code = RosterData.ROLES[i]
			var str_size = font.get_string_size(role_code, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos = pos + Vector2(-str_size.x / 2.0, font.get_ascent(font_size) / 2.0 - 1.0)
			var text_color = AppTheme.BACKGROUND if is_selected else AppTheme.TEXT_COLOR
			
			draw_string(font, text_pos, role_code, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

			var p_name = GameState.squad[i]["name"] if i < GameState.squad.size() else ""
			draw_string(font, pos + Vector2(-40, -22), p_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, AppTheme.TEXT_COLOR)

			var stamina_color = AppTheme.SUCCESS if stamina_pct > 70 else (AppTheme.WARNING if stamina_pct > 35 else AppTheme.DANGER)
			var bar_w = 44.0
			var bg_bar_rect = Rect2(pos.x - bar_w / 2.0, pos.y + 21, bar_w, 4)
			var bar_rect = Rect2(pos.x - bar_w / 2.0, pos.y + 21, bar_w * (stamina_pct / 100.0), 4)

			draw_rect(bg_bar_rect, Color(0, 0, 0, 0.6))
			draw_rect(bar_rect, stamina_color)

	func _gui_input(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var local_y_pct = event.position.y / size.y
			if local_y_pct > 0.72: menu.selected_role_idx = 0
			elif local_y_pct > 0.52: menu.selected_role_idx = 1
			elif local_y_pct > 0.32: menu.selected_role_idx = 2
			else: menu.selected_role_idx = 3
			menu.selected_candidate_idx = -1
			menu._refresh_ui()


func _ready():
	theme = AppTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_ui_layout()
	_refresh_ui()


func _build_ui_layout():
	var bg = ColorRect.new()
	bg.color = AppTheme.BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# 1. Cabeçalho
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 34)

	back_button = Button.new()
	back_button.text = "◀ Voltar"
	back_button.custom_minimum_size = Vector2(90, 30)
	back_button.pressed.connect(_on_confirm_pressed)
	UIUtils.add_press_feedback(back_button)
	header.add_child(back_button)

	var title_label = Label.new()
	title_label.text = "PRANCHA TÁTICA E ESCALAÇÃO"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", AppTheme.GOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	header.add_child(title_label)

	confirm_button = Button.new()
	confirm_button.text = "✓ Confirmar"
	confirm_button.custom_minimum_size = Vector2(110, 30)
	confirm_button.pressed.connect(_on_confirm_pressed)
	UIUtils.add_press_feedback(confirm_button)
	header.add_child(confirm_button)

	main_vbox.add_child(header)

	# 2. Conteúdo Principal
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(content_hbox)

	# Lado Esquerdo: Campo Tático
	pitch_view = PitchView.new(self)
	content_hbox.add_child(pitch_view)

	# Lado Direito: Container de Cards e Banco
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_hbox.add_child(scroll)

	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(right_vbox)

	# Área do Comparativo de Cards
	comparison_container = VBoxContainer.new()
	right_vbox.add_child(comparison_container)

	# Botão de Troca
	swap_button = Button.new()
	swap_button.text = "Selecione um reserva para comparar"
	swap_button.disabled = true
	swap_button.custom_minimum_size = Vector2(0, 32)
	swap_button.pressed.connect(_on_swap_pressed)
	UIUtils.add_press_feedback(swap_button)
	right_vbox.add_child(swap_button)

	# Card do Banco de Reservas
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = AppTheme.PANEL
	card_style.border_color = AppTheme.GOLD.darkened(0.3)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(8)

	var bench_card = PanelContainer.new()
	bench_card.add_theme_stylebox_override("panel", card_style)

	var bench_vbox = VBoxContainer.new()
	bench_vbox.add_theme_constant_override("separation", 4)

	var bench_title = Label.new()
	bench_title.text = "Reservas da Posição:"
	bench_title.add_theme_font_size_override("font_size", 12)
	bench_title.add_theme_color_override("font_color", AppTheme.GOLD)
	bench_vbox.add_child(bench_title)

	bench_container = VBoxContainer.new()
	bench_container.add_theme_constant_override("separation", 3)
	bench_vbox.add_child(bench_container)

	bench_card.add_child(bench_vbox)
	right_vbox.add_child(bench_card)


func _on_confirm_pressed():
	SaveSystem.save_game()
	get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")


func _refresh_ui():
	if pitch_view:
		pitch_view.queue_redraw()
	_update_comparison_cards()
	_update_bench_list()


func _update_comparison_cards():
	for child in comparison_container.get_children():
		child.queue_free()

	if selected_role_idx < 0 or selected_role_idx >= GameState.squad.size():
		return

	var starter_roster_idx = GameState.starters[selected_role_idx]
	var starter = GameState.squad[selected_role_idx]
	var starter_stamina = GameState.get_stamina(starter_roster_idx)

	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 8)
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# --- CARD 1: TITULAR ---
	var card_starter = _create_player_card(
		starter["name"] + " [TITULAR]",
		starter["role"],
		RosterData.trait_name(starter["trait"]),
		starter_stamina,
		starter,
		AppTheme.GOLD,
		null
	)
	card_starter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hbox.add_child(card_starter)

	# --- CARD 2: RESERVA (Se Houver Selecionado) ---
	if selected_candidate_idx != -1:
		var candidate_raw = RosterData.ROSTER[selected_candidate_idx]
		var candidate_stamina = GameState.get_stamina(selected_candidate_idx)

		var st_mult = 1.0
		if candidate_stamina < 50.0: st_mult = 0.80
		elif candidate_stamina < 75.0: st_mult = 0.90

		var growth = GameState.level - 1
		var candidate_stats = {
			"PAS": min(95, int(round((candidate_raw["PAS"] + 2 * growth) * st_mult))),
			"DRI": min(95, int(round((candidate_raw["DRI"] + 2 * growth) * st_mult))),
			"SHO": min(95, int(round((candidate_raw["SHO"] + 3 * growth) * st_mult))),
			"INT": min(95, int(round((candidate_raw["INT"] + 2 * growth) * st_mult))),
			"TAC": min(95, int(round((candidate_raw["TAC"] + 2 * growth) * st_mult))),
			"BLQ": min(95, int(round((candidate_raw["BLQ"] + 2 * growth) * st_mult)))
		}

		var card_candidate = _create_player_card(
			candidate_raw["name"] + " [RESERVA]",
			RosterData.ROLES[selected_role_idx],
			RosterData.trait_name(candidate_raw["trait"]),
			candidate_stamina,
			candidate_stats,
			AppTheme.SUCCESS,
			starter
		)
		card_candidate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards_hbox.add_child(card_candidate)

	comparison_container.add_child(cards_hbox)


func _create_player_card(p_name: String, role: String, trait_str: String, stamina: float, stats: Dictionary, border_color: Color, base_stats) -> PanelContainer:
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = AppTheme.PANEL
	card_style.border_color = border_color
	card_style.set_border_width_all(2 if base_stats != null else 1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(8)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var lbl_name = Label.new()
	lbl_name.text = p_name
	lbl_name.add_theme_font_size_override("font_size", 12)
	lbl_name.add_theme_color_override("font_color", border_color)
	vbox.add_child(lbl_name)

	var lbl_info = Label.new()
	lbl_info.text = "%s  │  ★ %s" % [role, trait_str]
	lbl_info.add_theme_font_size_override("font_size", 10)
	vbox.add_child(lbl_info)

	var lbl_stamina = Label.new()
	lbl_stamina.text = "⚡ Energia: %d%%" % int(stamina)
	lbl_stamina.add_theme_font_size_override("font_size", 10)
	vbox.add_child(lbl_stamina)

	vbox.add_child(HSeparator.new())

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var stat_list = ["PAS", "DRI", "SHO", "INT", "TAC", "BLQ"]

	for code in stat_list:
		var lbl_code = Label.new()
		lbl_code.text = code
		lbl_code.add_theme_font_size_override("font_size", 11)

		var val = stats[code]
		var lbl_val = Label.new()
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_val.add_theme_font_size_override("font_size", 11)

		if base_stats != null:
			var diff = val - base_stats[code]
			if diff > 0:
				lbl_val.text = "%d (+%d) 🟢" % [val, diff]
				lbl_val.add_theme_color_override("font_color", AppTheme.SUCCESS)
			elif diff < 0:
				lbl_val.text = "%d (%d) 🔴" % [val, diff]
				lbl_val.add_theme_color_override("font_color", AppTheme.DANGER)
			else:
				lbl_val.text = "%d (=)" % val
				lbl_val.add_theme_color_override("font_color", AppTheme.TEXT_COLOR)
		else:
			lbl_val.text = str(val)
			lbl_val.add_theme_color_override("font_color", AppTheme.GOLD)

		grid.add_child(lbl_code)
		grid.add_child(lbl_val)

	vbox.add_child(grid)
	return panel


func _update_bench_list():
	for child in bench_container.get_children():
		child.queue_free()

	var candidates = RosterData.candidates_for(selected_role_idx)
	var current_starter_roster_idx = GameState.starters[selected_role_idx]

	for c_idx in candidates:
		var c_data = RosterData.ROSTER[c_idx]
		var c_stamina = GameState.get_stamina(c_idx)
		var is_current_starter = (c_idx == current_starter_roster_idx)

		var btn = Button.new()
		btn.text = "%s (%d%% ⚡) %s" % [c_data["name"], int(c_stamina), "[TITULAR]" if is_current_starter else ""]
		btn.custom_minimum_size = Vector2(0, 28)

		if is_current_starter:
			btn.disabled = true
		else:
			btn.pressed.connect(func(): _select_candidate(c_idx))

		UIUtils.add_press_feedback(btn)
		bench_container.add_child(btn)


func _select_candidate(roster_idx: int):
	selected_candidate_idx = roster_idx
	swap_button.disabled = false
	swap_button.text = "Escalar %s" % RosterData.ROSTER[roster_idx]["name"]
	_refresh_ui()


func _on_swap_pressed():
	if selected_candidate_idx != -1:
		GameState.set_starter(selected_role_idx, selected_candidate_idx)
		selected_candidate_idx = -1
		swap_button.disabled = true
		swap_button.text = "Selecione um reserva para comparar"
		_refresh_ui()
