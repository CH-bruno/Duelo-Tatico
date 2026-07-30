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
var slide_button: Button
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

	_setup_slide_button()
	_setup_ui_styles()


func _setup_slide_button() -> void:
	if defense_container:
		if defense_container.has_node("SlideButton"):
			slide_button = defense_container.get_node("SlideButton")
		else:
			slide_button = Button.new()
			slide_button.name = "SlideButton"
			defense_container.add_child(slide_button)
			
			slide_button.pressed.connect(func(): GameState.defend("SLIDE"))
			UIUtils.add_press_feedback(slide_button)


func _setup_ui_styles() -> void:
	if options_button:
		options_button.text = "⚙ Opções"
		options_button.theme_type_variation = "GhostButton"
		options_button.custom_minimum_size = Vector2(90, 30)
		options_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if zone_label:
		zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zone_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		zone_label.add_theme_font_size_override("font_size", 12)

		var header_box = StyleBoxFlat.new()
		header_box.bg_color = AppTheme.PANEL
		header_box.border_color = AppTheme.GOLD.darkened(0.3)
		header_box.set_border_width_all(1)
		header_box.set_corner_radius_all(6)
		header_box.set_content_margin_all(6)
		zone_label.add_theme_stylebox_override("normal", header_box)

	if log_label:
		log_label.custom_minimum_size = Vector2(0, 110)
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
	var half_text = "1º Tempo" if GameState.first_half else "2º Tempo"

	# 1. TÍTULO E PLACAR DA BARRA SUPERIOR
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		zone_label.text = "⏱ %s (%d/30)  │  ⚽ Fase %d/%d  │  📍 %s  │  Você %d × %d Rival" % [
			half_text, GameState.round_num,
			GameState.campaign_stage, GameState.MAX_CAMPAIGN_STAGE,
			zone_name, GameState.goals, GameState.ai_goals
		]
	else:
		zone_label.text = "⏱ %s (%d/30)  │  🏆 Desafio: %dV  │  📍 %s  │  Você %d × %d Rival" % [
			half_text, GameState.round_num,
			GameState.challenge_wins,
			zone_name, GameState.goals, GameState.ai_goals
		]

	# 2. CARDS DE JOGADORES
	var attacker: Dictionary
	var defender: Dictionary

	if has_player_ball:
		attacker = GameState.active_player()
		defender = Matchups.opponent_marker_for_player(GameState, attacker)
	else:
		attacker = GameState.ai_active_player()
		defender = Matchups.player_defender_for_ai(GameState, attacker)

	var att_ejected = " 🟥 [EXPULSO]" if attacker.get("is_ejected", false) else ""
	var def_ejected = " 🟥 [EXPULSO]" if defender.get("is_ejected", false) else ""

	stats_label.text = (
		"⚽ COM A BOLA: %s (%s)%s  │   PAS %d   DRI %d   SHO %d\n" % [
			attacker.get("name", "---"), attacker.get("role", "---"), att_ejected,
			attacker.get("PAS", 0), attacker.get("DRI", 0), attacker.get("SHO", 0)
		] +
		"🛡 DEFENDENDO: %s (%s)%s  │   INT %d   TAC %d   BLQ %d" % [
			defender.get("name", "---"), defender.get("role", "---"), def_ejected,
			defender.get("INT", 0), defender.get("TAC", 0), defender.get("BLQ", 0)
		]
	)

	# 🛑 VERIFICAÇÃO DE FIM DE PARTIDA: Oculta todos os painéis de controle
	if GameState.match_over:
		attack_container.visible = false
		pass_container.visible = false
		defense_container.visible = false
		
		var can_next = (
			GameState.game_mode == GameState.GameMode.CAMPAIGN
			and GameState.goals > GameState.ai_goals
			and GameState.campaign_stage < GameState.MAX_CAMPAIGN_STAGE
		)
		next_match.visible = can_next
		_render_logs()
		return

	# 3. TURNO E BOTÕES DE DEFESA / ATAQUE
	var is_defending = GameState.turn_state == GameState.TurnState.PLAYER_DEFENSE
	var def_is_ejected = defender.get("is_ejected", false)

	attack_container.visible = not is_defending
	pass_container.visible = not is_defending
	defense_container.visible = is_defending

	# 🛑 SE O DEFENSOR NESSA ZONA ESTIVER EXPULSO:
	if is_defending and def_is_ejected:
		intercept_button.visible = false
		tackle_button.visible = false
		block_button.visible = false
		if slide_button: slide_button.visible = false
		
		GameState.push_log("⚠️ Zona desprotegida (%s expulso)! O rival avança sem marcação." % defender.get("name", "Jogador"))
		AIOpponent._move_succeeds()
		_render_logs()
		return

	if is_defending:
		var int_chance = GameState.defense_chance("INTERCEPT")
		var tac_chance = GameState.defense_chance("TACKLE")
		var blq_chance = GameState.defense_chance("BLOCK")
		var slide_chance = GameState.defense_chance("SLIDE")

		var def_role = defender.get("role", "")
		var is_defensive_role = def_role in ["ZAG", "VOL"]

		intercept_button.visible = true
		tackle_button.visible = true
		intercept_button.text = "Interceptação (%d%%)" % int_chance
		tackle_button.text = "Desarme (%d%%)" % tac_chance

		# 🛡 BLOQUEIO: Visível e ativo apenas para ZAG e VOL
		block_button.visible = is_defensive_role
		block_button.disabled = not is_defensive_role
		block_button.text = "Bloqueio (%d%%)" % blq_chance

		intercept_button.modulate = color_for_chance(int_chance)
		tackle_button.modulate = color_for_chance(tac_chance)
		block_button.modulate = color_for_chance(blq_chance)

		if slide_button:
			slide_button.visible = true
			slide_button.text = "🦵 Carrinho ⚠ (%d%%)" % slide_chance
			slide_button.modulate = AppTheme.DANGER

	var in_box = zone == GameState.ZONES.size() - 1
	var in_final_third = zone == 2
	var active_role = attacker.get("role", "")
	var is_ca = active_role == "CA"
	var att_is_ejected = attacker.get("is_ejected", false)

	sho_button.visible = is_ca
	sho_button.disabled = not (in_box and is_ca) or att_is_ejected

	long_shot_button.visible = in_final_third
	long_shot_button.disabled = not in_final_third or att_is_ejected

	dri_button.disabled = att_is_ejected
	feint_button.disabled = att_is_ejected

	var dri_chance = MatchEngine.chance_for(GameState, "DRI")
	var feint_chance = MatchEngine.feint_chance(GameState)
	var sho_chance = MatchEngine.chance_for(GameState, "SHO") if (in_box and is_ca) else 0
	var long_shot_chance = MatchEngine.long_shot_chance(GameState) if in_final_third else 0

	dri_button.text = "Drible (%d%%)" % dri_chance
	feint_button.text = "Finta (%d%%)" % feint_chance
	sho_button.text = "Chute (%d%%)" % sho_chance
	long_shot_button.text = "Chute de Longe (%d%%)" % long_shot_chance

	dri_button.modulate = color_for_chance(dri_chance)
	feint_button.modulate = color_for_chance(feint_chance)
	sho_button.modulate = color_for_chance(sho_chance) if in_box else Color.WHITE
	long_shot_button.modulate = color_for_chance(long_shot_chance) if in_final_third else Color.WHITE

	rebuild_pass_buttons()
	next_match.visible = false

	# 4. LOG DE NARRAÇÃO
	_render_logs()


func _render_logs() -> void:
	var formatted_logs: Array[String] = []
	var logs = GameState.log_messages.slice(0, 5)

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
		
		if teammate.get("is_ejected", false):
			continue

		var pass_chance = MatchEngine.pass_chance_to(GameState, i)
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


func _update_player_card(card_node: Control, player_data: Dictionary, _is_active: bool) -> void:
	var name_label = card_node.get_node_or_null("NameLabel")
	var role_label = card_node.get_node_or_null("RoleLabel")
	
	var is_ejected = player_data.get("is_ejected", false)

	if is_ejected:
		card_node.modulate = Color(0.3, 0.3, 0.3, 0.6)
		if name_label:
			name_label.text = "🟥 %s [EXPULSO]" % player_data.get("name", "Jogador")
			name_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	else:
		card_node.modulate = Color(1, 1, 1, 1)
		if name_label:
			name_label.text = player_data.get("name", "Jogador")
			name_label.remove_theme_color_override("font_color")

	if role_label:
		role_label.text = player_data.get("role", "")
