extends Control
# Tela de Campanha e Escalação Tática — Com Correção de Layout Vertical.

const AppTheme = preload("res://scripts/AppTheme.gd")

@onready var stage_label: Label = $VBoxContainer/StageLabel
@onready var enemy_label: Label = $VBoxContainer/EnemyLabel
@onready var stage_dots_label: Label = $VBoxContainer/StageDotsLabel
@onready var squad_summary_label: Label = $VBoxContainer/SquadSummaryLabel

@onready var lineup_button: Button = $VBoxContainer/LineupButton
@onready var start_button: Button = $VBoxContainer/StartMatchButton
@onready var hint_label: Label = $VBoxContainer/HintLabel
@onready var back_button: Button = $VBoxContainer/BackButton

@onready var lineup_panel: VBoxContainer = $VBoxContainer/LineupPanel
@onready var zag_option: OptionButton = $VBoxContainer/LineupPanel/ZagOption
@onready var vol_option: OptionButton = $VBoxContainer/LineupPanel/VolOption
@onready var mei_option: OptionButton = $VBoxContainer/LineupPanel/MeiOption
@onready var ca_option: OptionButton = $VBoxContainer/LineupPanel/CaOption
@onready var confirm_lineup_button: Button = $VBoxContainer/LineupPanel/ConfirmLineupButton

var lineup_confirmed := true


func _ready():
	theme = AppTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	lineup_confirmed = true
	start_button.disabled = false
	lineup_panel.visible = false

	_create_background()
	_setup_visuals()
	_populate_lineup_options()
	update_ui()

	# Conexões
	lineup_button.pressed.connect(_on_lineup_pressed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	confirm_lineup_button.pressed.connect(_confirm_lineup)

	var option_buttons = [zag_option, vol_option, mei_option, ca_option]
	for ob in option_buttons:
		ob.item_selected.connect(func(_idx): _on_option_changed())


func _create_background():
	if not has_node("CustomBackground"):
		var bg = ColorRect.new()
		bg.name = "CustomBackground"
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0.07, 0.12, 0.09, 1.0)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		move_child(bg, 0)


func _setup_visuals():
	# 1. Redução de espaçamentos para evitar estouro em 648px
	var main_vbox = $VBoxContainer
	if main_vbox:
		main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		main_vbox.add_theme_constant_override("separation", 6) # 👈 Espaçamento reduzido de 12 para 6

	var gold_color = Color(0.85, 0.65, 0.25)
	var text_light = Color(0.95, 0.95, 0.92)

	if stage_label:
		stage_label.add_theme_color_override("font_color", gold_color)
		stage_label.add_theme_font_size_override("font_size", 18)
		stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if enemy_label:
		enemy_label.add_theme_color_override("font_color", text_light)
		enemy_label.add_theme_font_size_override("font_size", 14)
		enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if stage_dots_label:
		stage_dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var track_box = StyleBoxFlat.new()
		track_box.bg_color = Color(0.05, 0.09, 0.06, 0.8)
		track_box.border_color = Color(0.85, 0.65, 0.25, 0.5)
		track_box.set_border_width_all(1)
		track_box.set_corner_radius_all(6)
		track_box.set_content_margin_all(6)
		stage_dots_label.add_theme_stylebox_override("normal", track_box)

	if squad_summary_label:
		squad_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var card_box = StyleBoxFlat.new()
		card_box.bg_color = Color(0.12, 0.18, 0.14)
		card_box.border_color = Color(0.85, 0.65, 0.25)
		card_box.set_border_width_all(1)
		card_box.set_corner_radius_all(8)
		card_box.set_content_margin_all(10)
		squad_summary_label.add_theme_stylebox_override("normal", card_box)

	if hint_label:
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_size_override("font_size", 12)

	# 2. Ajuste de altura nos seletores
	if lineup_panel:
		lineup_panel.add_theme_constant_override("separation", 4)

	# 3. Ajuste de altura nos Botões
	var buttons = [lineup_button, start_button, confirm_lineup_button, back_button]
	for btn in buttons:
		if btn:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.custom_minimum_size = Vector2(260, 32) # 👈 Altura de 32px mais enxuta
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_add_press_feedback(btn)

	start_button.theme_type_variation = "" 
	lineup_button.theme_type_variation = "GhostButton"
	back_button.theme_type_variation = "GhostButton"


func _build_campaign_track_text() -> String:
	var current_stage = GameState.campaign_stage
	var track_parts: Array[String] = []

	for stage in range(1, GameState.MAX_CAMPAIGN_STAGE + 1):
		var team = GameState.OpponentTeams.team_for_stage(stage)
		var team_name = team["name"]

		if stage < current_stage:
			track_parts.append("✔ %s" % team_name)
		elif stage == current_stage:
			track_parts.append("⚔️ [%s]" % team_name.to_upper())
		else:
			track_parts.append("🔒 %s" % team_name)

	return "  ➔  ".join(track_parts)


func _populate_lineup_options():
	var option_buttons = [zag_option, vol_option, mei_option, ca_option]
	
	for role_idx in range(option_buttons.size()):
		var ob = option_buttons[role_idx]
		ob.clear()
		ob.custom_minimum_size = Vector2(560, 32)
		ob.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		var current_starter_roster_idx = GameState.starters[role_idx]
		var starter_player = GameState.RosterData.ROSTER[current_starter_roster_idx]
		
		for roster_idx in GameState.candidates_for(role_idx):
			var candidate = GameState.RosterData.ROSTER[roster_idx]
			var stamina = GameState.player_stamina.get(roster_idx, 100.0)
			var energy_icon = "🔋" if stamina >= 75.0 else ("🪫" if stamina >= 50.0 else "⚠️")
			var trait_str = GameState.trait_name(candidate["trait"])
			
			var item_text = ""
			if roster_idx == current_starter_roster_idx:
				item_text = "★ [TITULAR] %s %s %d%% │ %s │ ATQ: %d/%d/%d │ DEF: %d/%d/%d" % [
					candidate["name"], energy_icon, int(stamina), trait_str,
					candidate["PAS"], candidate["DRI"], candidate["SHO"],
					candidate["INT"], candidate["TAC"], candidate["BLQ"]
				]
			else:
				var diff_pas = _format_diff(candidate["PAS"] - starter_player["PAS"])
				var diff_dri = _format_diff(candidate["DRI"] - starter_player["DRI"])
				var diff_sho = _format_diff(candidate["SHO"] - starter_player["SHO"])
				var diff_int = _format_diff(candidate["INT"] - starter_player["INT"])
				var diff_tac = _format_diff(candidate["TAC"] - starter_player["TAC"])
				var diff_blq = _format_diff(candidate["BLQ"] - starter_player["BLQ"])
				
				item_text = "🔄 %s %s %d%% │ %s │ PAS %d%s DRI %d%s SHO %d%s │ DEF %d%s %d%s %d%s" % [
					candidate["name"], energy_icon, int(stamina), trait_str,
					candidate["PAS"], diff_pas,
					candidate["DRI"], diff_dri,
					candidate["SHO"], diff_sho,
					candidate["INT"], diff_int,
					candidate["TAC"], diff_tac,
					candidate["BLQ"], diff_blq
				]
			
			ob.add_item(item_text)
			ob.set_item_metadata(ob.item_count - 1, roster_idx)
			
		for i in range(ob.item_count):
			if ob.get_item_metadata(i) == GameState.starters[role_idx]:
				ob.select(i)
				break


func _format_diff(diff: int) -> String:
	if diff > 0:
		return "(+%d)" % diff
	elif diff < 0:
		return "(%d)" % diff
	else:
		return "(=)"


func _on_option_changed():
	lineup_confirmed = false
	start_button.disabled = true
	update_ui()


func _confirm_lineup():
	var option_buttons = [zag_option, vol_option, mei_option, ca_option]
	var new_starters = []
	for ob in option_buttons:
		new_starters.append(ob.get_item_metadata(ob.get_selected()))
		
	GameState.set_lineup(new_starters)
	lineup_confirmed = true
	start_button.disabled = false
	lineup_panel.visible = false
	
	# Restaura a visibilidade do resumo dos titulares ao fechar
	if squad_summary_label:
		squad_summary_label.visible = true
	
	_populate_lineup_options()
	update_ui()


func update_ui():
	stage_label.text = "FASE %d DE %d" % [GameState.campaign_stage, GameState.MAX_CAMPAIGN_STAGE]

	var enemy_team = GameState.current_opponent_team()
	enemy_label.text = "⚔️ Desafio Atual: %s" % enemy_team["name"]

	stage_dots_label.text = _build_campaign_track_text()
	squad_summary_label.text = _squad_summary_formatted()

	if lineup_confirmed:
		hint_label.text = "✅ Escalação Pronta!"
		hint_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		hint_label.text = "⚠️ Clique em 'Confirmar Escalação' para salvar suas trocas."
		hint_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))


func _squad_summary_formatted() -> String:
	var lines = []
	lines.append("📋 TITULARES ESCALADOS (Nível do Time: %d)" % GameState.level)
	lines.append("")
	
	for i in range(GameState.squad.size()):
		var p = GameState.squad[i]
		var roster_idx = GameState.starters[i]
		var stamina = GameState.player_stamina.get(roster_idx, 100.0)
		var energy_icon = "🔋" if stamina >= 75.0 else ("🪫" if stamina >= 50.0 else "⚠️")
		var trait_str = GameState.trait_name(p["trait"])
		
		lines.append("• [%s] %s %s (%d%%)   │   %s   │   ATQ: %d/%d/%d   │   DEF: %d/%d/%d" % [
			p["role"], p["name"], energy_icon, int(stamina), trait_str,
			p["PAS"], p["DRI"], p["SHO"],
			p["INT"], p["TAC"], p["BLQ"]
		])
		
	return "\n".join(lines)


# Toggle Inteligente: Oculta o resumo enquanto altera a escalação!
func _on_lineup_pressed():
	lineup_panel.visible = not lineup_panel.visible
	if squad_summary_label:
		squad_summary_label.visible = not lineup_panel.visible


func _on_start_pressed():
	if not lineup_confirmed:
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _add_press_feedback(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.06)
	)
	btn.button_up.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
