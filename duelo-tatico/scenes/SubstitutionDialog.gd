extends Control
# SubstitutionDialog.gd — Modal de Substituições com Campo Mini + Painel por Posição.

signal closed

const AppTheme = preload("res://scripts/AppTheme.gd")
const UIUtils = preload("res://scripts/UIUtils.gd")

const GK_SLOT = 4 # 🧤 selected_role_idx == 4 representa o goleiro

var selected_role_idx: int = 0

var title_label: Label
var pitch_view: Control
var right_panel: VBoxContainer
var close_button: Button


# 🏟️ Campo Mini — mesma linguagem visual da Prancha Tática, mas lendo o
# estado AO VIVO da partida (energia, expulsão) em vez da escalação salva.
class MiniPitch extends Control:
	var dialog: Control

	func _init(p_dialog: Control):
		dialog = p_dialog
		custom_minimum_size = Vector2(220, 0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	func _draw():
		var size_rect = Rect2(Vector2.ZERO, size)
		draw_rect(size_rect, Color(0.06, 0.11, 0.08), true)
		draw_rect(size_rect, AppTheme.GOLD.darkened(0.4), false, 2.0)

		var center_x = size.x / 2.0
		var line_color = Color(1.0, 1.0, 1.0, 0.15)
		draw_line(Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0), line_color, 1.5)
		draw_rect(Rect2(center_x - 40, 0, 80, 30), line_color, false, 1.5)
		draw_rect(Rect2(center_x - 40, size.y - 30, 80, 30), line_color, false, 1.5)

		var roles_y_pct = [0.80, 0.60, 0.40, 0.20] # ZAG, VOL, MEI, CA
		var font = ThemeDB.fallback_font

		for i in range(4):
			var pos = Vector2(center_x, size.y * roles_y_pct[i])
			var player = GameState.squad[i] if i < GameState.squad.size() else {}
			var roster_idx = GameState.starters[i] if i < GameState.starters.size() else -1
			var is_ejected = player.get("is_ejected", false)
			var stamina = GameState.get_stamina(roster_idx) if roster_idx != -1 else 100.0
			var is_selected = (i == dialog.selected_role_idx)

			_draw_slot(pos, RosterData.ROLES[i], player.get("name", ""), stamina, is_ejected, is_selected, font)

		# 🧤 Goleiro
		var gk_pos = Vector2(center_x, size.y * 0.95)
		var gk = GameState.active_goalkeeper()
		var gk_stamina = GameState.get_gk_stamina()
		var gk_selected = (dialog.selected_role_idx == dialog.GK_SLOT)

		_draw_slot(gk_pos, "GOL", gk.get("name", ""), gk_stamina, false, gk_selected, font, 13.0)

	func _draw_slot(pos: Vector2, code: String, p_name: String, stamina: float, is_ejected: bool, is_selected: bool, font: Font, radius: float = 15.0) -> void:
		var circle_color = AppTheme.GOLD if is_selected else Color(0.12, 0.20, 0.15)
		var border_color = AppTheme.GOLD if is_selected else Color(0.4, 0.55, 0.4)

		if is_ejected:
			circle_color = Color(0.2, 0.2, 0.2)
			border_color = Color(0.5, 0.15, 0.15)

		if is_selected:
			draw_circle(pos, radius + 5, Color(0.85, 0.65, 0.25, 0.3))

		draw_circle(pos, radius, circle_color)
		draw_arc(pos, radius, 0, TAU, 24, border_color, 2.0)

		var font_size = 10
		var str_size = font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos = pos + Vector2(-str_size.x / 2.0, font.get_ascent(font_size) / 2.0 - 1.0)
		var text_color = Color(0.9, 0.3, 0.3) if is_ejected else (AppTheme.BACKGROUND if is_selected else AppTheme.TEXT_COLOR)
		draw_string(font, text_pos, code, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

		var name_prefix = "🟥 " if is_ejected else ""
		draw_string(font, pos + Vector2(-38, -radius - 5), name_prefix + p_name, HORIZONTAL_ALIGNMENT_CENTER, 76, 10, AppTheme.TEXT_COLOR)

		if not is_ejected:
			var stamina_color = AppTheme.SUCCESS if stamina > 70 else (AppTheme.WARNING if stamina > 35 else AppTheme.DANGER)
			var bar_w = 40.0
			var bg_bar_rect = Rect2(pos.x - bar_w / 2.0, pos.y + radius + 4, bar_w, 4)
			var bar_rect = Rect2(pos.x - bar_w / 2.0, pos.y + radius + 4, bar_w * (stamina / 100.0), 4)
			draw_rect(bg_bar_rect, Color(0, 0, 0, 0.6))
			draw_rect(bar_rect, stamina_color)

	func _gui_input(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var local_y_pct = event.position.y / size.y
			if local_y_pct > 0.88: dialog.selected_role_idx = dialog.GK_SLOT
			elif local_y_pct > 0.70: dialog.selected_role_idx = 0
			elif local_y_pct > 0.50: dialog.selected_role_idx = 1
			elif local_y_pct > 0.30: dialog.selected_role_idx = 2
			else: dialog.selected_role_idx = 3
			dialog._refresh_ui()


func _ready():
	theme = AppTheme.build()
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_dialog_structure()
	setup()


func _build_dialog_structure() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 480)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = AppTheme.PANEL
	panel_style.border_color = AppTheme.GOLD
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(main_vbox)

	# Título
	title_label = Label.new()
	title_label.text = "🔄 SUBSTITUIÇÕES"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", AppTheme.GOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title_label)

	# Conteúdo: campo à esquerda, painel da posição à direita
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 14)
	main_vbox.add_child(content_hbox)

	pitch_view = MiniPitch.new(self)
	content_hbox.add_child(pitch_view)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_hbox.add_child(scroll)

	right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 8)
	scroll.add_child(right_panel)

	# Botão de Fechar / Voltar
	close_button = Button.new()
	close_button.text = "Voltar ao Jogo ►"
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.pressed.connect(_on_close_pressed)
	UIUtils.add_press_feedback(close_button)
	main_vbox.add_child(close_button)


func setup():
	_refresh_ui()


func _refresh_ui() -> void:
	if title_label:
		title_label.text = "🔄 SUBSTITUIÇÕES (%d restantes)" % GameState.substitutions_left

	if pitch_view:
		pitch_view.queue_redraw()

	if selected_role_idx == GK_SLOT:
		_build_gk_panel()
	else:
		_build_outfield_panel()


func _clear_right_panel() -> void:
	for child in right_panel.get_children():
		child.queue_free()


func _section_title(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", AppTheme.GOLD)
	return lbl


func _starter_card(name_text: String, sub_text: String, stamina: float, is_ejected: bool) -> PanelContainer:
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = AppTheme.BACKGROUND.lightened(0.03)
	card_style.border_color = AppTheme.GOLD.darkened(0.3)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(10)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var lbl_sub = Label.new()
	lbl_sub.text = sub_text
	lbl_sub.add_theme_font_size_override("font_size", 10)
	lbl_sub.add_theme_color_override("font_color", AppTheme.GOLD)
	vbox.add_child(lbl_sub)

	var lbl_name = Label.new()
	lbl_name.text = ("🟥 " + name_text + " [EXPULSO]") if is_ejected else name_text
	lbl_name.add_theme_font_size_override("font_size", 14)
	lbl_name.add_theme_color_override("font_color", AppTheme.DANGER if is_ejected else AppTheme.TEXT_COLOR)
	vbox.add_child(lbl_name)

	if not is_ejected:
		var lbl_stamina = Label.new()
		lbl_stamina.text = "🔋 Energia: %d%%" % int(stamina)
		lbl_stamina.add_theme_font_size_override("font_size", 11)
		vbox.add_child(lbl_stamina)

	return card


func _bench_row(name_text: String, stamina: float, on_pressed: Callable, enabled: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl = Label.new()
	lbl.text = "%s   🔋 %d%%" % [name_text, int(stamina)]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var btn = Button.new()
	btn.text = "Trocar"
	btn.custom_minimum_size = Vector2(80, 28)
	btn.disabled = not enabled
	btn.pressed.connect(on_pressed)
	UIUtils.add_press_feedback(btn)
	row.add_child(btn)

	return row


func _build_outfield_panel() -> void:
	_clear_right_panel()

	var role_idx = selected_role_idx
	var starter_player = GameState.squad[role_idx]
	var starter_roster_idx = GameState.starters[role_idx]
	var starter_stamina = GameState.get_stamina(starter_roster_idx)
	var is_ejected = starter_player.get("is_ejected", false)

	right_panel.add_child(_section_title("TITULAR — %s" % RosterData.ROLES[role_idx]))
	right_panel.add_child(_starter_card(starter_player.get("name", "Jogador"), "[%s] TITULAR" % starter_player.get("role", ""), starter_stamina, is_ejected))

	right_panel.add_child(HSeparator.new())
	right_panel.add_child(_section_title("RESERVAS DA POSIÇÃO"))

	if is_ejected:
		var lbl = Label.new()
		lbl.text = "Jogador expulso não pode ser substituído."
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", AppTheme.DANGER)
		right_panel.add_child(lbl)
		return

	var candidates = RosterData.candidates_for(role_idx)
	var can_swap_base = GameState.substitutions_left > 0 and not GameState.match_over
	var found_any = false

	for candidate_idx in candidates:
		if candidate_idx == starter_roster_idx:
			continue
		if candidate_idx in GameState.subbed_out_players:
			continue

		found_any = true
		var candidate_data = RosterData.ROSTER[candidate_idx]
		var candidate_stamina = GameState.get_stamina(candidate_idx)

		var c_idx = candidate_idx
		var r_idx = role_idx
		right_panel.add_child(_bench_row(
			"%s (%s)" % [candidate_data["name"], candidate_data["role"]],
			candidate_stamina,
			func(): _do_substitute_outfield(r_idx, c_idx),
			can_swap_base
		))

	if not found_any:
		var lbl_empty = Label.new()
		lbl_empty.text = "Sem reservas disponíveis nesta partida."
		lbl_empty.add_theme_font_size_override("font_size", 11)
		lbl_empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		right_panel.add_child(lbl_empty)


func _build_gk_panel() -> void:
	_clear_right_panel()

	var gk = GameState.active_goalkeeper()
	var gk_stamina = GameState.get_gk_stamina()

	right_panel.add_child(_section_title("TITULAR — GOL"))
	right_panel.add_child(_starter_card(gk.get("name", "Goleiro"), "[GOL] TITULAR", gk_stamina, false))

	right_panel.add_child(HSeparator.new())
	right_panel.add_child(_section_title("RESERVAS DO GOL"))

	var can_swap = GameState.substitutions_left > 0 and not GameState.match_over
	var bench = LineupManager.available_gk_bench(GameState)

	if bench.is_empty():
		var lbl_empty = Label.new()
		lbl_empty.text = "Sem reservas disponíveis nesta partida."
		lbl_empty.add_theme_font_size_override("font_size", 11)
		lbl_empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		right_panel.add_child(lbl_empty)
		return

	for gk_idx in bench:
		var gk_data = RosterData.GOALKEEPERS[gk_idx]
		var gk_bench_stamina = GameState.gk_stamina.get(gk_idx, 100.0)

		var idx = gk_idx
		right_panel.add_child(_bench_row(
			"%s (GOL)" % gk_data["name"],
			gk_bench_stamina,
			func(): _do_substitute_gk(idx),
			can_swap
		))


func _do_substitute_outfield(role_idx: int, new_roster_idx: int) -> void:
	if GameState.substitutions_left <= 0:
		return

	# 📝 Não loga aqui — GameState.substitute() -> LineupManager.make_substitution()
	# já registra a substituição (com o cargo incluso), logar de novo aqui duplicava a linha.
	GameState.substitute(role_idx, new_roster_idx)
	_refresh_ui()


func _do_substitute_gk(new_gk_idx: int) -> void:
	if GameState.substitutions_left <= 0:
		return

	GameState.substitute_goalkeeper(new_gk_idx)
	_refresh_ui()


func _on_close_pressed():
	closed.emit()
	queue_free()
