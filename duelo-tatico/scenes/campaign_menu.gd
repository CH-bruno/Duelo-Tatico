extends Control
# CampaignMenu.gd — Menu de Campanha Integrado com a Prancha Tática e AppTheme.

const AppTheme = preload("res://scripts/AppTheme.gd")
const UIUtils = preload("res://scripts/UIUtils.gd")

@onready var stage_label: Label = $VBoxContainer/StageLabel
@onready var enemy_label: Label = $VBoxContainer/EnemyLabel
@onready var stage_dots_label: Label = $VBoxContainer/StageDotsLabel
@onready var squad_summary_label: Label = $VBoxContainer/SquadSummaryLabel

@onready var lineup_button: Button = $VBoxContainer/LineupButton
@onready var start_button: Button = $VBoxContainer/StartMatchButton
@onready var back_button: Button = $VBoxContainer/BackButton


func _ready():
	theme = AppTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_create_background()
	_setup_visuals()
	update_ui()

	# Conexões
	lineup_button.pressed.connect(_on_lineup_pressed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _create_background():
	if not has_node("CustomBackground"):
		var bg = ColorRect.new()
		bg.name = "CustomBackground"
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.color = AppTheme.BACKGROUND
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		move_child(bg, 0)


func _setup_visuals():
	var main_vbox = $VBoxContainer
	if main_vbox:
		main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		main_vbox.add_theme_constant_override("separation", 10)

	if stage_label:
		stage_label.add_theme_color_override("font_color", AppTheme.GOLD)
		stage_label.add_theme_font_size_override("font_size", 18)
		stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if enemy_label:
		enemy_label.add_theme_color_override("font_color", AppTheme.TEXT_COLOR)
		enemy_label.add_theme_font_size_override("font_size", 14)
		enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if stage_dots_label:
		stage_dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var track_box = StyleBoxFlat.new()
		track_box.bg_color = AppTheme.BACKGROUND
		track_box.border_color = AppTheme.GOLD.darkened(0.2)
		track_box.set_border_width_all(1)
		track_box.set_corner_radius_all(6)
		track_box.set_content_margin_all(8)
		stage_dots_label.add_theme_stylebox_override("normal", track_box)

	if squad_summary_label:
		squad_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var card_box = StyleBoxFlat.new()
		card_box.bg_color = AppTheme.PANEL
		card_box.border_color = AppTheme.GOLD
		card_box.set_border_width_all(1)
		card_box.set_corner_radius_all(8)
		card_box.set_content_margin_all(12)
		squad_summary_label.add_theme_stylebox_override("normal", card_box)

	var buttons = [lineup_button, start_button, back_button]
	for btn in buttons:
		if btn:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.custom_minimum_size = AppTheme.BUTTON_SIZE_DEFAULT
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			UIUtils.add_press_feedback(btn)

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

	return "   ➔   ".join(track_parts)


func update_ui():
	stage_label.text = "FASE %d DE %d" % [GameState.campaign_stage, GameState.MAX_CAMPAIGN_STAGE]

	var enemy_team = GameState.current_opponent_team()
	enemy_label.text = "⚔️ Desafio Atual: %s" % enemy_team["name"]

	stage_dots_label.text = _build_campaign_track_text()
	squad_summary_label.text = _squad_summary_formatted()


func _squad_summary_formatted() -> String:
	var lines = []
	lines.append("📋 TITULARES ESCALADOS (Nível do Time: %d)" % GameState.level)
	lines.append("")
	
	for i in range(GameState.squad.size()):
		var p = GameState.squad[i]
		var roster_idx = GameState.starters[i]
		var stamina = GameState.get_stamina(roster_idx)
		var energy_icon = "🔋" if stamina >= 75.0 else ("🪫" if stamina >= 50.0 else "⚠️")
		var trait_str = GameState.trait_name(p["trait"])
		
		lines.append("• [%s] %s %s (%d%%)   │   %s   │   ATQ: %d/%d/%d   │   DEF: %d/%d/%d" % [
			p["role"], p["name"], energy_icon, int(stamina), trait_str,
			p["PAS"], p["DRI"], p["SHO"],
			p["INT"], p["TAC"], p["BLQ"]
		])
		
	return "\n".join(lines)


# ---------- NAVEGAÇÃO DE CENAS ----------

func _on_lineup_pressed():
	get_tree().change_scene_to_file("res://scenes/lineup_menu.tscn")


func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
