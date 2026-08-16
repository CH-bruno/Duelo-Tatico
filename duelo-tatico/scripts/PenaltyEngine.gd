class_name PenaltyEngine
extends RefCounted
# PenaltyEngine.gd — Processa a cobrança de pênalti de forma isolada.

static func execute_penalty(gs: Node, is_player_kicker: bool) -> void:
	gs.push_log(Narration.PENALTY_CALL.pick_random())

	var kicker_dict: Dictionary
	if is_player_kicker:
		kicker_dict = gs.active_player()
	else:
		kicker_dict = gs.ai_active_player()

	var k_name = kicker_dict.get("name", "Jogador")
	var k_role = kicker_dict.get("role", "")
	var sho_stat = float(kicker_dict.get("SHO", 50))
	var trait_bonus = float(RosterData.trait_bonus(kicker_dict, "SHO"))

	# 🥅 Goleiro que está defendendo a cobrança
	var gk_stat := 50.0
	if is_player_kicker:
		# Você cobra: quem defende é o goleiro do time adversário (atributos reais)
		var ai_gk = gs.current_opponent_team().get("goalkeeper", {})
		gk_stat = ai_gk.get("REF", 50) * 0.6 + ai_gk.get("POS", 50) * 0.4
	else:
		# A IA cobra: quem defende é o SEU goleiro titular
		var gk = gs.active_goalkeeper()
		gk_stat = gk.get("REF", 50) * 0.6 + gk.get("POS", 50) * 0.4

	# Chance de converter: base 75% + atributos do cobrador, reduzida pelo goleiro
	var convert_chance = clampi(int(round(75 + (sho_stat - 50) * 0.4 + trait_bonus - (gk_stat - 50) * 0.5)), 40, 95)
	var success = randi_range(1, 100) <= convert_chance

	# 🧤 Consome energia do SEU goleiro sempre que ele é quem está defendendo
	if not is_player_kicker:
		gs.consume_gk_action_stamina("SAVE", not success)

	if success:
		if is_player_kicker:
			gs.goals += 1
			Stats.shot_on_target()
			Stats.add_goal(gs.active_idx)
		else:
			gs.ai_goals += 1
		
		# 🎯 Log de gol de pênalti usando Narration.PENALTY_GOAL
		gs.push_log(AIOpponent._format_narration(Narration.PENALTY_GOAL.pick_random(), [k_name, k_role]))
		SFX.play_goal()
	else:
		# 🎯 Log de pênalti perdido/defendido
		if not is_player_kicker:
			var gk = gs.active_goalkeeper()
			gs.push_log(AIOpponent._format_narration(MatchEngine.gk_save_narration(100 - convert_chance), [gk.get("name", "o goleiro")]))
		else:
			gs.push_log(AIOpponent._format_narration(Narration.PENALTY_FAIL.pick_random(), [k_name, k_role]))
			
		SFX.play_defense_fail()

	# Recomeço após o pênalti: bola vai para quem sofreu a cobrança
	MatchEngine.kickoff(gs, not is_player_kicker)
