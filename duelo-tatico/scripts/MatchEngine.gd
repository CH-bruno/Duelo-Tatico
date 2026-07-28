class_name MatchEngine
extends Node

# ---------- Ações do Jogador ----------

static func attempt(gs: Node, action: String, target_idx: int = -1) -> void:
	if gs.match_over or gs.possession != gs.Possession.PLAYER:
		return

	match action:
		"SHO":
			_do_shot(gs)
		"DRI":
			_do_dribble(gs)
		"FEINT":
			_do_feint(gs)
		"LONG_SHO":
			_do_long_shot(gs)
		"PASS":
			_do_pass(gs, target_idx)
		_:
			return

	advance_round(gs)
	gs.state_changed.emit()


static func _do_shot(gs: Node) -> void:
	var active_roster_idx = gs.starters[gs.active_idx]
	var passer = gs.active_player()
	Stats.shot()
	
	var succ_chance = chance_for(gs, "SHO")
	var success = randi_range(1, 100) <= succ_chance

	# Consumo de stamina proporcional ao tipo de ação e resultado
	gs.consume_action_stamina(active_roster_idx, "SHO", success)

	if success:
		Stats.shot_on_target()
		gs.goals += 1
		gs.streak += 1
		gs.grant_xp(15)
		gs.push_log(Narration.GOAL_CALL.pick_random())
		gs.push_log(Narration.GOAL.pick_random() % [passer["name"], passer["role"]])
		SFX.play_goal()
	else:
		gs.grant_xp(2)
		gs.push_log(Narration.GOAL_FAIL.pick_random() % [passer["name"], passer["role"]])

	kickoff(gs, false)
	gs.momentum_bonus = 0


static func _do_dribble(gs: Node) -> void:
	var active_roster_idx = gs.starters[gs.active_idx]
	var passer = gs.active_player()
	Stats.dribble_attempt()
	
	var succ_chance = chance_for(gs, "DRI")
	var success = randi_range(1, 100) <= succ_chance

	# Consumo de stamina proporcional ao tipo de ação e resultado
	gs.consume_action_stamina(active_roster_idx, "DRI", success)

	if success:
		Stats.dribble_success()
		gs.grant_xp(6)
		gs.streak += 1
		gs.push_log(Narration.DRIBBLE.pick_random() % [passer["name"], passer["role"]])
		SFX.play_dribble()
		gs.momentum_bonus = 22
	else:
		gs.grant_xp(1)
		gs.push_log(Narration.DRIBBLE_FAIL.pick_random() % [passer["name"], passer["role"]])
		SFX.play_turnover()
		Referee.check_foul(gs)
		AIOpponent.reset_possession("", gs.zone_idx)
		gs.momentum_bonus = 0


static func _do_feint(gs: Node) -> void:
	var active_roster_idx = gs.starters[gs.active_idx]
	var passer = gs.active_player()
	Stats.feint_attempt()
	
	var succ_chance = feint_chance(gs)
	var success = randi_range(1, 100) <= succ_chance

	# Consumo de stamina proporcional ao tipo de ação e resultado
	gs.consume_action_stamina(active_roster_idx, "FEINT", success)

	if success:
		Stats.feint_success()
		gs.grant_xp(9)
		gs.streak += 1
		gs.push_log(Narration.FEINT.pick_random() % [passer["name"], passer["role"]])
		SFX.play_pass_success()
		gs.momentum_bonus = 30
	else:
		gs.grant_xp(1)
		Referee.check_foul(gs)
		AIOpponent.reset_possession(Narration.FEINT_FAIL.pick_random() % [passer["name"], passer["role"]], gs.zone_idx)
		gs.momentum_bonus = 0


static func _do_long_shot(gs: Node) -> void:
	var active_roster_idx = gs.starters[gs.active_idx]
	var passer = gs.active_player()
	Stats.long_shot_attempt()
	
	var succ_chance = long_shot_chance(gs)
	var success = randi_range(1, 100) <= succ_chance

	# Consumo de stamina proporcional ao tipo de ação e resultado
	gs.consume_action_stamina(active_roster_idx, "LONG_SHO", success)

	if success:
		Stats.long_shot_on_target()
		gs.goals += 1
		gs.streak += 1
		gs.grant_xp(20)
		gs.push_log(Narration.GOAL_CALL.pick_random())
		gs.push_log(Narration.LONG_GOAL.pick_random() % [passer["name"], passer["role"]])
		SFX.play_goal()
	else:
		gs.grant_xp(2)
		gs.push_log(Narration.LONG_GOAL_FAIL.pick_random() % [passer["name"], passer["role"]])

	kickoff(gs, false)
	gs.momentum_bonus = 0


static func _do_pass(gs: Node, target_idx: int) -> void:
	if target_idx < 0 or target_idx >= gs.squad.size() or target_idx == gs.active_idx:
		return
		
	var active_roster_idx = gs.starters[gs.active_idx]
	var passer = gs.active_player()
	var target = gs.squad[target_idx]
	
	Stats.pass_attempt()
	var succ_chance = pass_chance_to(gs, target_idx)
	var success = randi_range(1, 100) <= succ_chance

	# Consumo de stamina proporcional ao tipo de ação e resultado
	gs.consume_action_stamina(active_roster_idx, "PASS", success)

	if success:
		Stats.pass_completed()
		gs.grant_xp(4)
		gs.streak += 1
		gs.push_log(Narration.PASS_SUCCESS.pick_random() % [passer["name"], passer["role"], target["name"], target["role"]])
		SFX.play_pass_success()
		gs.zone_idx = target_idx
		gs.active_idx = target_idx
		gs.momentum_bonus = 8
	else:
		gs.grant_xp(1)
		AIOpponent.reset_possession(Narration.PASS_FAIL.pick_random() % [passer["name"], passer["role"], target["name"], target["role"]], target_idx)
		gs.momentum_bonus = 0


# ---------- Controle de Posse e Transições ----------

static func player_gets_ball(gs: Node) -> void:
	gs.possession = gs.Possession.PLAYER
	gs.turn_state = gs.TurnState.PLAYER_ATTACK

	gs.zone_idx = 0
	gs.active_idx = 0

	gs.ai_zone_idx = 0
	gs.ai_active_idx = 0
	gs.ai_momentum = 0

	gs.streak = 0
	gs.momentum_bonus = 0


static func recover_possession(gs: Node, defender_idx: int) -> void:
	gs.possession = gs.Possession.PLAYER
	gs.turn_state = gs.TurnState.PLAYER_ATTACK

	gs.active_idx = defender_idx
	gs.zone_idx = defender_idx

	gs.ai_zone_idx = 0
	gs.ai_active_idx = 0
	gs.ai_momentum = 0

	gs.streak = 0
	gs.momentum_bonus = 0

	var defender = gs.squad[defender_idx]
	match defender["role"]:
		"ZAG": gs.push_log(Narration.ZAG_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"VOL": gs.push_log(Narration.VOL_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"MEI": gs.push_log(Narration.MEI_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"CA":  gs.push_log(Narration.CA_RECOVERY.pick_random() % [defender["name"], defender["role"]])


# ---------- Cálculos de Probabilidade ----------

static func chance_for(gs: Node, stat_name: String) -> int:
	var tb = 0
	var marker_stat = ""
	if stat_name == "DRI":
		tb = gs.trait_bonus("DRI")
		marker_stat = "TAC"
	elif stat_name == "SHO":
		tb = gs.trait_bonus("SHO")
		marker_stat = "BLQ"

	var marker = gs._opponent_marker_for(gs.zone_idx)
	var difficulty = marker[marker_stat] + gs._difficulty_bonus()
	return Rules.success_chance(gs.active_player()[stat_name], difficulty, gs.momentum_bonus, tb)


static func feint_chance(gs: Node) -> int:
	var stat_avg = (gs.active_player()["DRI"] + gs.active_player()["SHO"]) / 2.0
	var marker = gs._opponent_marker_for(gs.zone_idx)
	var marker_avg = (marker["TAC"] + marker["BLQ"]) / 2.0
	var tb = gs.trait_bonus("FEINT")
	return Rules.success_chance(stat_avg, marker_avg + 8 + gs._difficulty_bonus(), gs.momentum_bonus, tb, 5, 90)


static func long_shot_chance(gs: Node) -> int:
	var marker = gs._opponent_marker_for(gs.zone_idx)
	var tb = gs.trait_bonus("LONG_SHO")
	return Rules.success_chance(gs.active_player()["SHO"], marker["BLQ"] + 20 + gs._difficulty_bonus(), gs.momentum_bonus, tb, 5, 85)


static func pass_chance_to(gs: Node, target_idx: int) -> int:
	var distance = abs(target_idx - gs.zone_idx)
	var adjacent_bonus = 14 if distance == 1 else 0
	var distance_penalty = max(0, distance - 1) * 15
	var momentum_effect = (gs.momentum_bonus * 1.5) if distance >= 2 else float(gs.momentum_bonus)

	var marker = gs._opponent_marker_for(target_idx)
	var tb = gs.trait_bonus("PASS")
	var effective_difficulty = marker["INT"] + distance_penalty - adjacent_bonus + gs._difficulty_bonus()
	return Rules.success_chance(gs.active_player()["PAS"], effective_difficulty, momentum_effect, tb)


# ---------- Controle de Rodada ----------

static func kickoff(gs: Node, start_with_player: bool = true) -> void:
	if start_with_player:
		player_gets_ball(gs)
		var p = gs.active_player()
		gs.push_log("Reinício de jogo. A posse da bola está com %s (%s)." % [p["name"], p["role"]])
	else:
		gs.possession = gs.Possession.AI
		gs.turn_state = gs.TurnState.PLAYER_DEFENSE
		gs.ai_zone_idx = 0
		gs.ai_active_idx = 0
		gs.ai_momentum = 0
		var p = gs.ai_active_player()
		gs.push_log("Reinício de jogo. A posse da bola está com %s (%s)." % [p["name"], p["role"]])
		AIOpponent.take_turn()

	gs.state_changed.emit()


static func advance_round(gs: Node) -> void:
	gs.round_num += 1

	# Desgaste passivo por posição a cada rodada
	gs.consume_round_stamina()

	# Gatilho do Intervalo (Rodada 15)
	if gs.round_num == gs.MAX_ROUNDS / 2 and gs.first_half:
		gs.first_half = false
		MatchFlow.half_time(gs)
		return

	# Fim de Jogo (Rodada 30)
	if gs.round_num >= gs.MAX_ROUNDS:
		gs.match_over = true
		SFX.play_whistle()
		
		Progression.process_pending_xp(gs)
		
		if gs.goals > gs.ai_goals:
			gs.push_log("Vitória por %d × %d!" % [gs.goals, gs.ai_goals])
			if gs.campaign_stage >= gs.MAX_CAMPAIGN_STAGE:
				gs.push_log("PARABÉNS! Você venceu a Grande Final e completou a Campanha!")
			else:
				gs.push_log("Clique em 'Próxima Partida' para continuar a campanha.")
		elif gs.goals < gs.ai_goals:
			gs.push_log("Derrota por %d × %d." % [gs.goals, gs.ai_goals])
		else:
			gs.push_log("Empate em %d × %d." % [gs.goals, gs.ai_goals])
