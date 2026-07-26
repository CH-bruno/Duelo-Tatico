class_name MatchUI
extends Node
# MatchUI.gd — Responsável pela montagem e atualização dos elementos da interface.

const AppTheme = preload("res://scripts/AppTheme.gd")
const UIUtils = preload("res://scripts/UIUtils.gd")

var zone_label: Label
var stats_label: Label
var log_label: Label
var pass_container: HBoxContainer
var dri_button: Button
var feint_button: Button
var sho_button: Button
var long_shot_button: Button
var next_match: Button
var options_button: Button
var defense_container: HBoxContainer
var intercept_button: Button
var tackle_button: Button
var block_button: Button
var attack_container: HBoxContainer


func setup(nodes: Dictionary) -> void:
	zone_label = nodes["zone_label"]
	stats_label = nodes["stats_label"]
	log_label = nodes["log_label"]
	pass_container = nodes["pass_container"]
	dri_button = nodes["dri_button"]
	feint_button = nodes["feint_button"]
	sho_button = nodes["sho_button"]
	long_shot_button = nodes["long_shot_button"]
	next_match = nodes["next_match"]
	options_button = nodes["options_button"]
	defense_container = nodes["defense_container"]
	intercept_button = nodes["intercept_button"]
	tackle_button = nodes["tackle_button"]
	block_button = nodes["block_button"]
	attack_container = nodes["attack_container"]

	_setup_ui_styles()


func _setup_ui_styles() -> void:
	if options_button:
		options_button.text = "⚙️ Opções"
		options_button.theme_type_variation = "GhostButton"
		options_button.custom_minimum_size = Vector2(110, 30)
		options_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if log_label:
		log_label.custom_minimum_size = Vector2(0, 95)
		log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var log_box = StyleBoxFlat.new()
		log_box.bg_color = AppTheme.PANEL
		log_box.border_color = AppTheme.GOLD.darkened(0.2)
		log_box.set_border_width_all(1)
		log_box.set_corner_radius_all(8)
		log_box.set_content_margin_all(10)

		log_label.add_theme_stylebox_override("normal", log_box)
		log_label.add_theme_color_override("font_color", AppTheme.TEXT_COLOR)


func refresh() -> void:
	var has_player_ball = GameState.possession == GameState.Possession.PLAYER
	var raw_zone = GameState.zone_idx if has_player_ball else GameState.ai_zone_idx
	var zone = clampi(raw_zone, 0, GameState.ZONES.size() - 1)
	var zone_name = GameState.ZONES[zone]

	# 1. TÍTULO E PLACAR SUPERIOR
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		zone_label.text = "Rodada %d/%d  │  Fase %d/%d  │  Zona: %s  │  Você %d × %d Adversário" % [
			GameState.round_num, GameState.MAX_ROUNDS,
			GameState.campaign_stage, GameState.MAX_CAMPAIGN_STAGE,
			zone_name, GameState.goals, GameState.ai_goals
		]
	else:
		zone_label.text = "Desafio (%d vitória(s))  │  Rodada %d/%d  │  Zona: %s  │  Você %d × %d Adversário" % [
			GameState.challenge_wins, GameState.round_num, GameState.MAX_ROUNDS,
			zone_name, GameState.goals, GameState.ai_goals
		]

	# 2. CARDS DE JOGADORES (Ataque vs Defesa)
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

	# 3. TURNO E BOTÕES
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

	rebuild_pass_buttons()

	var can_next_match = (
		GameState.game_mode == GameState.GameMode.CAMPAIGN
		and GameState.match_over
		and GameState.goals > GameState.ai_goals
	)
	next_match.visible = can_next_match

	# 4. LOG DE NARRAÇÃO
	var formatted_logs: Array[String] = []
	var logs = GameState.log_messages.slice(0, 4)

	for i in range(logs.size()):
		if i == 0:
			formatted_logs.append("▶ %s" % logs[i])
		else:
			formatted_logs.append("  ↳ %s" % logs[i])

	if formatted_logs.is_empty():
		log_label.text = "🎙 Partida em andamento..."
	else:
		log_label.text = "\n".join(formatted_logs)


func rebuild_pass_buttons() -> void:
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
		UIUtils.add_press_feedback(btn)


func color_for_chance(chance_pct: int) -> Color:
	var t = clampf(chance_pct / 100.0, 0.0, 1.0)
	return AppTheme.DANGER.lerp(AppTheme.SUCCESS, t)
