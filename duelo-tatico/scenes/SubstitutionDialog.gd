extends Control
# SubstitutionDialog.gd — Modal de Substituições Totalmente Centralizado e Responsivo.

signal closed

const AppTheme = preload("res://scripts/AppTheme.gd")
const UIUtils = preload("res://scripts/UIUtils.gd")

var title_label: Label
var container: VBoxContainer
var close_button: Button


func _ready():
	theme = AppTheme.build()
	
	# 📐 Garante expansão total na tela inteira
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


# 🛠️ Constrói a estrutura visual totalmente centralizada
func _build_dialog_structure() -> void:
	# 1. Fundo Escuro Transparente Cobrindo 100% da Tela
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# 2. Container Centralizador
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	# 3. Painel de Fundo Fixo e Centralizado
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 440)
	
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

	# 4. Título
	title_label = Label.new()
	title_label.text = "🔄 SUBSTITUIÇÕES"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", AppTheme.GOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title_label)

	# 5. Lista de Substituições com Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 10)
	scroll.add_child(container)

	# 6. Botão de Fechar / Voltar
	close_button = Button.new()
	close_button.text = "Voltar ao Jogo ►"
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.pressed.connect(_on_close_pressed)
	UIUtils.add_press_feedback(close_button)
	main_vbox.add_child(close_button)


func setup():
	if title_label:
		title_label.text = "🔄 SUBSTITUIÇÕES (%d restantes)" % GameState.substitutions_left

	_rebuild_list()


func _rebuild_list():
	if not container:
		return

	for child in container.get_children():
		child.queue_free()

	# Itera pelos 4 slots de titulares (0: ZAG, 1: VOL, 2: MEI, 3: CA)
	for role_idx in range(GameState.squad.size()):
		var starter_player = GameState.squad[role_idx]
		var starter_roster_idx = GameState.starters[role_idx]
		var starter_stamina = GameState.get_stamina(starter_roster_idx)
		var is_ejected = starter_player.get("is_ejected", false)

		# --- CARD DO SLOT TÁTICO ---
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = AppTheme.BACKGROUND.lightened(0.03)
		card_style.border_color = AppTheme.GOLD.darkened(0.4)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card_style.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", card_style)

		var card_hbox = HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 12)
		card.add_child(card_hbox)

		# 1. LADO ESQUERDO: TITULAR
		var starter_vbox = VBoxContainer.new()
		starter_vbox.custom_minimum_size = Vector2(170, 0)
		starter_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var lbl_role = Label.new()
		lbl_role.text = "[%s] TITULAR" % starter_player.get("role", RosterData.ROLES[role_idx])
		lbl_role.add_theme_font_size_override("font_size", 10)
		lbl_role.add_theme_color_override("font_color", AppTheme.GOLD)
		starter_vbox.add_child(lbl_role)

		var lbl_starter_name = Label.new()
		lbl_starter_name.text = starter_player.get("name", "Jogador")
		if is_ejected:
			lbl_starter_name.text = "🟥 " + lbl_starter_name.text + " [EXPULSO]"
			lbl_starter_name.add_theme_color_override("font_color", AppTheme.DANGER)
		else:
			lbl_starter_name.add_theme_color_override("font_color", AppTheme.TEXT_COLOR)
		lbl_starter_name.add_theme_font_size_override("font_size", 13)
		starter_vbox.add_child(lbl_starter_name)

		var lbl_starter_stamina = Label.new()
		lbl_starter_stamina.text = "🔋 %d%%" % int(starter_stamina)
		lbl_starter_stamina.add_theme_font_size_override("font_size", 11)
		starter_vbox.add_child(lbl_starter_stamina)

		card_hbox.add_child(starter_vbox)

		# DIVISOR / SETA
		var arrow = Label.new()
		arrow.text = "➔"
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow.add_theme_color_override("font_color", AppTheme.GOLD.darkened(0.2))
		card_hbox.add_child(arrow)

		# 2. LADO DIREITO: RESERVAS DA POSIÇÃO
		var bench_vbox = VBoxContainer.new()
		bench_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_vbox.add_theme_constant_override("separation", 6)

		var candidates = RosterData.candidates_for(role_idx)
		var bench_count = 0

		for candidate_idx in candidates:
			if candidate_idx == starter_roster_idx:
				continue # Pula o titular que já está jogando

			bench_count += 1
			var candidate_data = RosterData.ROSTER[candidate_idx]
			var candidate_stamina = GameState.get_stamina(candidate_idx)

			var sub_row = HBoxContainer.new()
			sub_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			# Informações do Reserva
			var lbl_cand = Label.new()
			lbl_cand.text = "%s (%s)  🔋 %d%%" % [
				candidate_data["name"],
				candidate_data["role"],
				int(candidate_stamina)
			]
			lbl_cand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl_cand.add_theme_font_size_override("font_size", 12)
			sub_row.add_child(lbl_cand)

			# Botão de Trocar
			var btn_sub = Button.new()
			btn_sub.text = "Trocar"
			btn_sub.custom_minimum_size = Vector2(80, 26)
			
			var can_swap = (GameState.substitutions_left > 0) and not GameState.match_over and not is_ejected
			btn_sub.disabled = not can_swap

			var c_idx = candidate_idx
			var r_idx = role_idx
			btn_sub.pressed.connect(func(): _do_substitute(r_idx, c_idx))
			UIUtils.add_press_feedback(btn_sub)

			sub_row.add_child(btn_sub)
			bench_vbox.add_child(sub_row)

		if bench_count == 0:
			var lbl_empty = Label.new()
			lbl_empty.text = "Sem reservas disponíveis"
			lbl_empty.add_theme_font_size_override("font_size", 11)
			lbl_empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			bench_vbox.add_child(lbl_empty)

		card_hbox.add_child(bench_vbox)
		container.add_child(card)


func _do_substitute(role_idx: int, new_roster_idx: int):
	if GameState.substitutions_left <= 0:
		return

	var old_player_name = GameState.squad[role_idx]["name"]
	GameState.substitute(role_idx, new_roster_idx)
	var new_player_name = GameState.squad[role_idx]["name"]

	GameState.push_log("🔄 Substituição: Entra %s no lugar de %s!" % [new_player_name, old_player_name])

	setup()


func _on_close_pressed():
	closed.emit()
	queue_free()
