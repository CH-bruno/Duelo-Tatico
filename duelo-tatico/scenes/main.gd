extends Control
# Script da cena principal do jogo.
# Conecta as ações ao GameState, gerencia o turno e atualiza a UI.

@onready var zone_label: Label = $VBoxContainer/ZoneLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var pass_container: HBoxContainer = $VBoxContainer/PassContainer
@onready var dri_button: Button = $VBoxContainer/HBoxContainer/DriButton
@onready var feint_button: Button = $VBoxContainer/HBoxContainer/FeintButton
@onready var sho_button: Button = $VBoxContainer/HBoxContainer/ShoButton
@onready var long_shot_button: Button = $VBoxContainer/HBoxContainer/LongShotButton
@onready var next_match: Button = $VBoxContainer/NextMatchButton
@onready var options_button: Button = $VBoxContainer/OptionsButton
@onready var goal_flash: ColorRect = $GoalFlash
@onready var defense_container: HBoxContainer = $VBoxContainer/DefenseContainer
@onready var intercept_button: Button = $VBoxContainer/DefenseContainer/InterceptButton
@onready var tackle_button: Button = $VBoxContainer/DefenseContainer/TackleButton
@onready var block_button: Button = $VBoxContainer/DefenseContainer/BlockButton
@onready var attack_container: HBoxContainer = $VBoxContainer/HBoxContainer

const AppTheme = preload("res://scripts/AppTheme.gd")
const OptionsMenuScene = preload("res://scenes/OptionsMenu.tscn")
const MatchStatsScene = preload("res://scenes/MatchStats.tscn")

var _last_goals = 0
var _last_ai_goals = 0
var stats_opened := false


func _ready():
	theme = AppTheme.build()
	SFX.play_music("res://audio/music_match.mp3")
	SFX.play_whistle() # Toca o apito inicial do jogo
	
	GameState.state_changed.connect(refresh_ui)

	dri_button.pressed.connect(func(): GameState.attempt("DRI"))
	feint_button.pressed.connect(func(): GameState.attempt("FEINT"))
	sho_button.pressed.connect(func(): GameState.attempt("SHO"))
	long_shot_button.pressed.connect(func(): GameState.attempt("LONG_SHO"))
	next_match.pressed.connect(_on_next_match_pressed)
	options_button.pressed.connect(_on_options_pressed)

	intercept_button.pressed.connect(func(): GameState.defend("INTERCEPT"))
	tackle_button.pressed.connect(func(): GameState.defend("TACKLE"))
	block_button.pressed.connect(func(): GameState.defend("BLOCK"))

	for btn in [dri_button, feint_button, sho_button, long_shot_button, next_match, options_button, intercept_button, tackle_button, block_button]:
		_add_press_feedback(btn)

	goal_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	goal_flash.modulate.a = 0.0
	goal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_ui_styles()

	_last_goals = GameState.goals
	_last_ai_goals = GameState.ai_goals

	refresh_ui()


# Ajustes de estilo aplicados diretamente via código para não precisar mexer no editor
func _setup_ui_styles():
	if options_button:
		options_button.text = "⚙️ Opções"
		options_button.theme_type_variation = "GhostButton"
		options_button.custom_minimum_size = Vector2(110, 30)
		options_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# 2. Painel do Log AUMENTADO com visual de caixa de narração
	if log_label:
		log_label.custom_minimum_size = Vector2(0, 100) # 👈 Altura ajustada para 4 linhas
		log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		var log_box = StyleBoxFlat.new()
		log_box.bg_color = Color(0.06, 0.10, 0.07, 0.92) # Verde escuro
		log_box.border_color = Color(0.85, 0.65, 0.25, 0.6) # Dourado sutil
		log_box.set_border_width_all(1)
		log_box.set_corner_radius_all(8)
		log_box.set_content_margin_all(10)
		
		log_label.add_theme_stylebox_override("normal", log_box)
		log_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.90))

func refresh_ui():
	var has_player_ball = GameState.possession == GameState.Possession.PLAYER

	var raw_zone = GameState.zone_idx if has_player_ball else GameState.ai_zone_idx
	var zone = clampi(raw_zone, 0, GameState.ZONES.size() - 1)
	var zone_name = GameState.ZONES[zone]

	# 1. TÍTULO E PLACAR SUPERIOR
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		zone_label.text = "Rodada %d/%d  │  Fase %d/%d  │  Zona: %s  │  Você %d × %d Adversário" % [
			GameState.round_num,
			GameState.MAX_ROUNDS,
			GameState.campaign_stage,
			GameState.MAX_CAMPAIGN_STAGE,
			zone_name,
			GameState.goals,
			GameState.ai_goals
		]
	else:
		zone_label.text = "Desafio (%d vitória(s))  │  Rodada %d/%d  │  Zona: %s  │  Você %d × %d Adversário" % [
			GameState.challenge_wins,
			GameState.round_num,
			GameState.MAX_ROUNDS,
			zone_name,
			GameState.goals,
			GameState.ai_goals
		]

	# 2. ATRIBUTOS DE ATAQUE E DEFESA SEPARADOS
	var attacker: Dictionary
	var defender: Dictionary

	if has_player_ball:
		attacker = GameState.active_player()
		match attacker["role"]:
			"ZAG": defender = GameState.current_opponent_team()["squad"][3]
			"VOL": defender = GameState.current_opponent_team()["squad"][2]
			"MEI": defender = GameState.current_opponent_team()["squad"][1]
			"CA":  defender = GameState.current_opponent_team()["squad"][0]
	else:
		attacker = GameState.ai_active_player()
		defender = GameState.squad[GameState.defender_for_attacker()]

	stats_label.text = (
		"⚽ COM A BOLA: %s (%s)   │   PAS %d   DRI %d   SHO %d\n" % [
			attacker["name"], attacker["role"], attacker["PAS"], attacker["DRI"], attacker["SHO"]
		] +
		"🛡 DEFENDENDO: %s (%s)   │   INT %d   TAC %d   BLQ %d" % [
			defender["name"], defender["role"], defender["INT"], defender["TAC"], defender["BLQ"]
		]
	)

	# 3. CONTROLE DE TURNO (Ataque vs Defesa)
	var is_defending = GameState.turn_state == GameState.TurnState.PLAYER_DEFENSE and not GameState.match_over

	attack_container.visible = not is_defending
	pass_container.visible = not is_defending
	defense_container.visible = is_defending

	if is_defending:
		var int_chance = GameState.defense_chance("INTERCEPT")
		var tac_chance = GameState.defense_chance("TACKLE")
		var blq_chance = GameState.defense_chance("BLOCK")

		intercept_button.text = "Interceptação (%d%%)" % int_chance
		tackle_button.text = "Desarme (%d%%)" % tac_chance
		block_button.text = "Bloqueio (%d%%)" % blq_chance

		intercept_button.modulate = color_for_chance(int_chance)
		tackle_button.modulate = color_for_chance(tac_chance)
		block_button.modulate = color_for_chance(blq_chance)

	# 4. CHANCES E HABILITAÇÃO DOS BOTÕES
	var in_box = zone == GameState.ZONES.size() - 1
	var in_final_third = zone == 2

	sho_button.disabled = not in_box or GameState.match_over
	dri_button.disabled = GameState.match_over
	feint_button.disabled = GameState.match_over
	long_shot_button.disabled = not in_final_third or GameState.match_over
	long_shot_button.visible = in_final_third

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

	var can_next_match = (
		GameState.game_mode == GameState.GameMode.CAMPAIGN
		and GameState.match_over
		and GameState.goals > GameState.ai_goals
	)	
	next_match.visible = can_next_match


# 5. LOG DE NARRAÇÃO (Estruturado em Ordem Cronológica)
	var formatted_logs: Array[String] = []
	var logs = GameState.log_messages.slice(0, 4) # Pega até os 4 eventos mais recentes

	for i in range(logs.size()):
		if i == 0:
			# A jogada que ACABOU de acontecer (Destaque principal)
			formatted_logs.append("▶ %s" % logs[i])
		else:
			# Jogadas anteriores em ordem
			formatted_logs.append("  ↳ %s" % logs[i])

	if formatted_logs.is_empty():
		log_label.text = "🎙 Partida em andamento..."
	else:
		log_label.text = "\n".join(formatted_logs)
		
	# Efeitos visuais de gol
	if GameState.goals > _last_goals:
		_flash_goal(Color(1, 0.85, 0.3, 1))
	elif GameState.ai_goals > _last_ai_goals:
		_flash_goal(Color(0.9, 0.3, 0.3, 1))

	_last_goals = GameState.goals
	_last_ai_goals = GameState.ai_goals

	# Painel de estatísticas ao final da partida
	if GameState.match_over and not stats_opened:
		stats_opened = true
		show_match_stats()


func show_match_stats():
	var stats_overlay = MatchStatsScene.instantiate()
	add_child(stats_overlay)


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
		var target_idx = i
		btn.pressed.connect(func(): GameState.attempt("PASS", target_idx))
		pass_container.add_child(btn)
		_add_press_feedback(btn)


func color_for_chance(chance_pct: int) -> Color:
	var t = clampf(chance_pct / 100.0, 0.0, 1.0)
	return Color(1.0, 0.3, 0.3).lerp(Color(0.4, 1.0, 0.4), t)


func _flash_goal(color: Color) -> void:
	goal_flash.color = color
	goal_flash.modulate.a = 0.55
	var tween = create_tween()
	tween.tween_property(goal_flash, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _add_press_feedback(btn: Button) -> void:
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
	stats_opened = false
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		GameState.next_match()
		get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")
	else:
		GameState.next_challenge_round()


func _on_options_pressed():
	if has_node("OptionsMenu"):
		return

	var menu = OptionsMenuScene.instantiate()
	menu.name = "OptionsMenu"
	add_child(menu)
