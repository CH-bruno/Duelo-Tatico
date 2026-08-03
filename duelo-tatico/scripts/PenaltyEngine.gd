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
	
	# Chance de converter o pênalti (Base 75% + atributos do cobrador)
	var convert_chance = clampi(int(round(75 + (sho_stat - 50) * 0.4 + trait_bonus)), 50, 95)
	var success = randi_range(1, 100) <= convert_chance

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
		# 🎯 Log de pênalti perdido
		# Se você tiver a constante PENALTY_MISSED no seu Narration.gd ela será usada, senão usa a frase padrão
		if "PENALTY_MISSED" in Narration:
			gs.push_log(AIOpponent._format_narration(Narration.PENALTY_FAIL.pick_random(), [k_name, k_role]))
		else:
			gs.push_log("❌ PERDEU O PÊNALTI! O chute de %s (%s) foi para fora ou defendido!" % [k_name, k_role])
			
		SFX.play_defense_fail()

	# Recomeço após o pênalti: bola vai para quem sofreu a cobrança
	MatchEngine.kickoff(gs, not is_player_kicker)
