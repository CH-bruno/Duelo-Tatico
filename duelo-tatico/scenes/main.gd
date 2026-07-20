extends Control
# Script da cena principal. Conecta os botões ao GameState
# e atualiza os textos toda vez que o estado muda.

@onready var zone_label: Label = $VBoxContainer/ZoneLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var pass_container: HBoxContainer = $VBoxContainer/PassContainer
@onready var dri_button: Button = $VBoxContainer/HBoxContainer/DriButton
@onready var feint_button: Button = $VBoxContainer/HBoxContainer/FeintButton
@onready var sho_button: Button = $VBoxContainer/HBoxContainer/ShoButton
@onready var long_shot_button: Button = $VBoxContainer/HBoxContainer/LongShotButton
@onready var pas_bar: ProgressBar = $VBoxContainer/PasBar
@onready var dri_bar: ProgressBar = $VBoxContainer/DriBar
@onready var sho_bar: ProgressBar = $VBoxContainer/ShoBar
@onready var def_bar: ProgressBar = $VBoxContainer/DefBar
@onready var reset_button: Button = $VBoxContainer/ResetButton
@onready var next_match: Button = $VBoxContainer/NextMatchButton
@onready var menu_button: Button = $VBoxContainer/MenuButton
@onready var goal_flash: ColorRect = $GoalFlash
@onready var defense_container = $VBoxContainer/DefenseContainer
@onready var intercept_button = $VBoxContainer/DefenseContainer/InterceptButton
@onready var tackle_button = $VBoxContainer/DefenseContainer/TackleButton
@onready var cover_button = $VBoxContainer/DefenseContainer/CoverButton

const AppTheme = preload("res://scripts/AppTheme.gd")

var _last_goals = 0
var _last_ai_goals = 0


func _ready():
	theme = AppTheme.build()
	GameState.state_changed.connect(refresh_ui)

	dri_button.pressed.connect(func(): GameState.attempt("DRI"))
	feint_button.pressed.connect(func(): GameState.attempt("FEINT"))
	sho_button.pressed.connect(func(): GameState.attempt("SHO"))
	long_shot_button.pressed.connect(func(): GameState.attempt("LONG_SHO"))
	reset_button.pressed.connect(_on_new_game_pressed)
	next_match.pressed.connect(_on_next_match_pressed)
	menu_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/start_screen.tscn"))
	menu_button.theme_type_variation = "GhostButton"
	intercept_button.pressed.connect(func():GameState.defend("INTERCEPT"))
	tackle_button.pressed.connect(func():GameState.defend("TACKLE"))
	cover_button.pressed.connect(func():GameState.defend("COVER"))

	for btn in [dri_button, feint_button, sho_button, long_shot_button, reset_button, next_match, menu_button]:
		_add_press_feedback(btn)

	goal_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	goal_flash.modulate.a = 0.0
	goal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_last_goals = GameState.goals
	_last_ai_goals = GameState.ai_goals

	refresh_ui()


func refresh_ui():
	var p = GameState.active_player()
	var zone_name = ""

	if GameState.possession == GameState.Possession.PLAYER:
		zone_name = GameState.ZONES[GameState.zone_idx]
	else:
		zone_name = "Ataque IA - %s" % GameState.ZONES[GameState.ai_zone_idx]

	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		zone_label.text = "Rodada %d/%d | Fase %d/%d | Zona: %s | Você %d × %d Adversário" % [
			GameState.round_num,
			GameState.MAX_ROUNDS,
			GameState.campaign_stage,
			GameState.MAX_CAMPAIGN_STAGE,
			zone_name,
			GameState.goals,
			GameState.ai_goals
		]
	else:
		zone_label.text = "Desafio | Sequência: %d (recorde: %d) | Rodada %d/%d | Zona: %s | Você %d × %d Adversário" % [
			GameState.challenge_wins,
			GameState.challenge_best,
			GameState.round_num,
			GameState.MAX_ROUNDS,
			zone_name,
			GameState.goals,
			GameState.ai_goals
		]

	if GameState.turn_state == GameState.TurnState.PLAYER_ATTACK:

		stats_label.text = "Com a bola: %s (%s)   PAS %d  DRI %d  SHO %d  DEF %d   |   Nível %d   XP %d/%d" % [
			p["name"],
			p["role"],
			p["PAS"],
			p["DRI"],
			p["SHO"],
			p["DEF"],
			GameState.level,
			GameState.xp,
			GameState.xp_to_next
		]

	else:

		var action_name = ""

		match GameState.ai_next_move:
			GameState.AIMove.PASS:
				action_name = "Passe"

			GameState.AIMove.DRIBBLE:
				action_name = "Drible"

			GameState.AIMove.LONG_SHOT:
				action_name = "Chute de Longe"

			GameState.AIMove.SHOT:
				action_name = "Finalização"

		stats_label.text = "Ataque adversário | Zona: %s | Próxima ação: %s" % [
			GameState.ZONES[GameState.ai_zone_idx],
			action_name
		]

	# ------------------------------
	# DAQUI PARA BAIXO É FORA DO IF
	# ------------------------------

	_animate_bar(pas_bar, p["PAS"])
	_animate_bar(dri_bar, p["DRI"])
	_animate_bar(sho_bar, p["SHO"])
	_animate_bar(def_bar, p["DEF"])

	var in_box = GameState.zone_idx == GameState.ZONES.size() - 1
	var in_final_third = GameState.zone_idx == 2

	sho_button.disabled = not in_box or GameState.match_over
	dri_button.disabled = GameState.match_over
	feint_button.disabled = GameState.match_over
	long_shot_button.disabled = not in_final_third or GameState.match_over

	var dri_chance = GameState.chance_for("DRI")
	var feint_chance = GameState.feint_chance()
	var sho_chance = GameState.chance_for("SHO") if in_box else 0
	var long_shot_chance = GameState.long_shot_chance() if in_final_third else 0

	dri_button.text = "Drible (%d%%)" % dri_chance
	feint_button.text = "Finta (%d%%)" % feint_chance
	sho_button.text = "Chute (%d%%)" % sho_chance
	long_shot_button.text = "Chute de Longe (%d%%)" % long_shot_chance

	dri_button.modulate = color_for_chance(dri_chance)
	feint_button.modulate = color_for_chance(feint_chance)
	sho_button.modulate = color_for_chance(sho_chance) if in_box else Color.WHITE
	long_shot_button.modulate = color_for_chance(long_shot_chance) if in_final_third else Color.WHITE

	_rebuild_pass_buttons()

	var can_next_match = GameState.match_over and GameState.goals > GameState.ai_goals
	next_match.visible = can_next_match

	log_label.text = "\n".join(GameState.log_messages)

	if GameState.goals > _last_goals:
		_flash_goal(Color(1, 0.85, 0.3, 1))
	elif GameState.ai_goals > _last_ai_goals:
		_flash_goal(Color(0.9, 0.3, 0.3, 1))

	_last_goals = GameState.goals
	_last_ai_goals = GameState.ai_goals

	var attacking = GameState.turn_state == GameState.TurnState.PLAYER_ATTACK
	var defending = GameState.turn_state == GameState.TurnState.PLAYER_DEFENSE

	# Ataque
	dri_button.visible = attacking
	feint_button.visible = attacking
	sho_button.visible = attacking
	long_shot_button.visible = attacking and in_final_third
	pass_container.visible = attacking

	# Defesa
	defense_container.visible = defending
func _rebuild_pass_buttons():
	for child in pass_container.get_children():
		child.queue_free()

	if GameState.match_over:
		return

	for i in range(GameState.squad.size()):
		if i == GameState.active_idx:
			continue
		var teammate = GameState.squad[i]
		var pass_chance = GameState.pass_chance_to(i)
		var btn = Button.new()
		btn.text = "Passar p/ %s (%d%%)" % [teammate["name"], pass_chance]
		btn.modulate = color_for_chance(pass_chance)
		var target_idx = i  # cópia local — evita o problema de "closure" pegando o valor errado
		btn.pressed.connect(func(): GameState.attempt("PASS", target_idx))
		pass_container.add_child(btn)
		_add_press_feedback(btn)


func color_for_chance(chance_pct: int) -> Color:
	var t = clampf(chance_pct / 100.0, 0.0, 1.0)
	return Color(1.0, 0.3, 0.3).lerp(Color(0.4, 1.0, 0.4), t)


func _animate_bar(bar: ProgressBar, new_value: float) -> void:
	# Anima o valor da barra suavemente, em vez de pular direto pro número novo.
	var tween = create_tween()
	tween.tween_property(bar, "value", new_value, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _flash_goal(color: Color) -> void:
	goal_flash.color = color
	goal_flash.modulate.a = 0.55
	var tween = create_tween()
	tween.tween_property(goal_flash, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _add_press_feedback(btn: Button) -> void:
	# Faz o botão "encolher" ao ser pressionado e voltar ao soltar — dá feedback tátil.
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
	)
	btn.button_up.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


func _on_next_match_pressed():
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		GameState.next_match()
		get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")
	else:
		GameState.next_challenge_round()  # Desafio: continua na mesma tela, sem escalação


func _on_new_game_pressed():
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		GameState.reset_game()
		get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")
	else:
		GameState.reset_game()  # Desafio: reinicia a sequência ali mesmo
