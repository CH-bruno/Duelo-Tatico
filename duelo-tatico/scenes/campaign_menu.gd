extends Control

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

# controla se o jogador confirmou o time
var lineup_confirmed = false


func _ready():
	theme = AppTheme.build()
	back_button.theme_type_variation = "GhostButton"  # ação secundária

	lineup_confirmed = false
	start_button.disabled = true
	update_ui()
	lineup_panel.visible = false
	_populate_lineup_options()

	lineup_button.pressed.connect(_on_lineup_pressed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	confirm_lineup_button.pressed.connect(_confirm_lineup)


func _populate_lineup_options():
	var option_buttons = [zag_option, vol_option, mei_option, ca_option]
	for role_idx in range(option_buttons.size()):
		var ob = option_buttons[role_idx]
		ob.clear()
		for roster_idx in GameState.candidates_for(role_idx):
			var player = GameState.roster[roster_idx]
			ob.add_item(
				"%s | %s | PAS %d DRI %d SHO %d DEF %d"
				% [
					player["name"],
					GameState.trait_name(player["trait"]),
					player["PAS"],
					player["DRI"],
					player["SHO"],
					player["DEF"]
				]
			)
			ob.set_item_metadata(ob.item_count - 1, roster_idx)
		for i in range(ob.item_count):
			if ob.get_item_metadata(i) == GameState.starters[role_idx]:
				ob.select(i)
				break


func _confirm_lineup():
	var option_buttons = [zag_option, vol_option, mei_option, ca_option]
	var new_starters = []
	for ob in option_buttons:
		new_starters.append(ob.get_item_metadata(ob.get_selected()))
	GameState.set_lineup(new_starters)
	lineup_confirmed = true
	start_button.disabled = false
	lineup_panel.visible = false
	update_ui()


func update_ui():
	stage_label.text = "Fase %d/%d" % [GameState.campaign_stage, GameState.MAX_CAMPAIGN_STAGE]

	match GameState.campaign_stage:
		1: enemy_label.text = "Adversário: Time de Bairro"
		2: enemy_label.text = "Adversário: Time Regional"
		3: enemy_label.text = "Adversário: Time Estadual"
		4: enemy_label.text = "Adversário: Time Nacional"
		5: enemy_label.text = "Adversário: Grande Final"

	stage_dots_label.text = _stage_dots()
	squad_summary_label.text = _squad_summary()
	hint_label.visible = not lineup_confirmed


func _stage_dots() -> String:
	# ● fase já vencida | ◉ fase atual | ○ fase futura — dá noção de progresso na campanha.
	var dots = ""
	for i in range(1, GameState.MAX_CAMPAIGN_STAGE + 1):
		if i < GameState.campaign_stage:
			dots += "●  "
		elif i == GameState.campaign_stage:
			dots += "◉  "
		else:
			dots += "○  "
	return dots


func _squad_summary() -> String:
	var parts = []
	for p in GameState.squad:
		parts.append("%s (%s)" % [p["name"], p["role"]])
	return "Titulares: " + " · ".join(parts)


func _on_lineup_pressed():
	lineup_panel.visible = not lineup_panel.visible


func _on_start_pressed():
	if not lineup_confirmed:
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
