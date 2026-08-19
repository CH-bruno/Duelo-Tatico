class_name MatchEngine
extends Node
# MatchEngine.gd — Motor principal de ações, resolução de probabilidade e controle de rodadas.

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
	
	gs.push_log("%s (%s) encheu o pé e finalizou para o gol!" % [passer.get("name", "Jogador"), passer.get("role", "")])
	
	# 🛡️ CAMADA 1: precisa superar a marcação
	var succ_chance = chance_for(gs, "SHO")
	var success = randi_range(1, 100) <= succ_chance

	gs.consume_action_stamina(active_roster_idx, "SHO", success)

	if not success:
		gs.grant_xp(2)
		var marker = Matchups.opponent_marker_for_player(gs, passer)
		gs.push_log(Narration.BLOCK_SUCCESS.pick_random() % [marker.get("name", "Adversário"), marker.get("role", "DEF")])
	else:
		# ⚠️ A marcação foi superada — antes de ir pro goleiro, credita a falha do marcador
		var marker = Matchups.opponent_marker_for_player(gs, passer)
		gs.push_log(Narration.BLOCK_FAIL.pick_random() % [marker.get("name", "Adversário"), marker.get("role", "DEF")])

		# 🥅 CAMADA 2: superou a marcação — agora é o goleiro da IA
		var save_chance = goalkeeper_save_chance(gs, true, false)
		var gk_saved = randi_range(1, 100) <= save_chance

		if gk_saved:
			Stats.shot_on_target()
			gs.grant_xp(4)
			gs.push_log(gk_save_narration(save_chance) % [gs.current_opponent_team().get("goalkeeper", {}).get("name", "o goleiro")])
			SFX.play_defense_fail()
		else:
			Stats.shot_on_target()
			gs.goals += 1
			gs.streak += 1
			gs.grant_xp(15)
			gs.push_log(Narration.GK_BEATEN.pick_random() % [gs.current_opponent_team().get("goalkeeper", {}).get("name", "o goleiro")])
			gs.push_log(Narration.GOAL_CALL.pick_random())
			gs.push_log(Narration.GOAL.pick_random() % [passer["name"], passer["role"]])
			SFX.play_goal()

	kickoff(gs, false)
	gs.momentum_bonus = 0


static func _do_long_shot(gs: Node) -> void:
	var active_roster_idx = gs.starters[gs.active_idx]
	var passer = gs.active_player()
	Stats.long_shot_attempt()
	
	gs.push_log("%s (%s) soltou uma bomba de longe!" % [passer.get("name", "Jogador"), passer.get("role", "")])
	
	# 🛡️ CAMADA 1: precisa superar a marcação
	var succ_chance = long_shot_chance(gs)
	var success = randi_range(1, 100) <= succ_chance

	gs.consume_action_stamina(active_roster_idx, "LONG_SHO", success)

	if not success:
		gs.grant_xp(2)
		var marker = Matchups.opponent_marker_for_player(gs, passer)
		gs.push_log(Narration.BLOCK_SUCCESS.pick_random() % [marker.get("name", "Adversário"), marker.get("role", "DEF")])
	else:
		# ⚠️ A marcação foi superada — antes de ir pro goleiro, credita a falha do marcador
		var marker = Matchups.opponent_marker_for_player(gs, passer)
		gs.push_log(Narration.BLOCK_FAIL.pick_random() % [marker.get("name", "Adversário"), marker.get("role", "DEF")])

		# 🥅 CAMADA 2: superou a marcação — agora é o goleiro da IA
		var save_chance = goalkeeper_save_chance(gs, true, true)
		var gk_saved = randi_range(1, 100) <= save_chance

		if gk_saved:
			Stats.long_shot_on_target()
			gs.grant_xp(5)
			gs.push_log(gk_save_narration(save_chance) % [gs.current_opponent_team().get("goalkeeper", {}).get("name", "o goleiro")])
			SFX.play_defense_fail()
		else:
			Stats.long_shot_on_target()
			gs.goals += 1
			gs.streak += 1
			gs.grant_xp(20)
			gs.push_log(Narration.GK_BEATEN.pick_random() % [gs.current_opponent_team().get("goalkeeper", {}).get("name", "o goleiro")])
			gs.push_log(Narration.GOAL_CALL.pick_random())
			gs.push_log(Narration.LONG_GOAL.pick_random() % [passer["name"], passer["role"]])
			SFX.play_goal()

	kickoff(gs, false)
	gs.momentum_bonus = 0


static func _do_dribble(gs: Node) -> void:
	var active_roster_idx = gs.starters[gs.active_idx]
	var passer = gs.active_player()
	Stats.dribble_attempt()
	
	var succ_chance = chance_for(gs, "DRI")
	var success = randi_range(1, 100) <= succ_chance

	gs.consume_action_stamina(active_roster_idx, "DRI", success)

	if success:
		# ✅ DRIBLE BEM SUCEDIDO: O seu atacante supera a marcação!
		Stats.dribble_success()
		gs.grant_xp(6)
		gs.streak += 1
		gs.push_log(Narration.DRIBBLE_SUCCESS.pick_random() % [passer["name"], passer["role"]])
		SFX.play_dribble()
		gs.momentum_bonus = 22
	else:
		var marker = Matchups.opponent_marker_for_player(gs, passer)
		var marker_slot = Matchups.ai_slot_for_role(gs, marker.get("role", "ZAG"))

		# 🎯 Avalia se o zagueiro da IA cometeu falta tentando parar o drible
		var decision = Referee.evaluate_foul(gs, "DRIBBLE_FOUL", false)

		if decision == Referee.Decision.PENALTY:
			# 🚨 FALTA DA IA DENTRO DA PRÓPRIA ÁREA -> PÊNALTI A SEU FAVOR
			gs.grant_xp(1)
			Referee.process_cards(gs, marker_slot, marker, false, false)
			gs.push_log(Narration.FOUL_COMMITTED.pick_random() % [marker.get("name", "Adversário"), marker.get("role", "DEF")])

			# 🟥 Se essa expulsão decretou WO, o jogo já acabou — não cobra o pênalti
			if gs.match_over:
				return

			PenaltyEngine.start_penalty(gs, true)

		elif decision == Referee.Decision.FOUL:
			# ⚠️ FALTA COMUM DA IA: a vantagem fica com quem foi driblado —
			# o lance segue e o drible é considerado bem-sucedido
			gs.grant_xp(5)
			Referee.process_cards(gs, marker_slot, marker, false, false)
			gs.push_log(Narration.FOUL_COMMITTED.pick_random() % [marker.get("name", "Adversário"), marker.get("role", "DEF")])

			# 🟥 Se essa expulsão decretou WO, o jogo já acabou — não segue o lance
			if gs.match_over:
				return

			Stats.dribble_success()
			gs.streak += 1
			SFX.play_dribble()
			gs.momentum_bonus = 22

		else:
			# ❌ TENTATIVA DE DRIBLE FALHOU (desarme limpo, sem falta):
			# O atacante tentou o drible e foi desarmado limpo pelo zagueiro da IA
			gs.grant_xp(1)
			SFX.play_turnover()

			var fail_msg = Narration.TACKLE_SUCCESS.pick_random() % [marker.get("name", "Adversário"), marker.get("role", "DEF")]

			# Transfere a posse de bola para a IA no local do desarme (SEM PÊNALTI E SEM FALTA)
			AIOpponent.reset_possession(fail_msg, marker_slot)
			gs.momentum_bonus = 0
		
static func _do_feint(gs: Node) -> void:
	var active_roster_idx = gs.starters[gs.active_idx]
	var passer = gs.active_player()
	Stats.feint_attempt()
	
	var succ_chance = feint_chance(gs)
	var success = randi_range(1, 100) <= succ_chance

	gs.consume_action_stamina(active_roster_idx, "FEINT", success)

	if success:
		Stats.feint_success()
		gs.grant_xp(9)
		gs.streak += 1
		gs.push_log(Narration.FEINT_SUCCESS.pick_random() % [passer["name"], passer["role"]])
		SFX.play_pass_success()
		gs.momentum_bonus = 30
	else:
		gs.grant_xp(1)
		
		# 🎯 Defensor adversário não cai na finta e desabilita a jogada
		var marker = Matchups.opponent_marker_for_player(gs, passer)
		var marker_slot = Matchups.ai_slot_for_role(gs, marker.get("role", "ZAG"))
		var fail_msg = Narration.TACKLE_SUCCESS.pick_random() % [marker.get("name", "Adversário"), marker.get("role", "DEF")]
		
		AIOpponent.reset_possession(fail_msg, marker_slot)
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
		
		# 🎯 Interceptação do marcador adversário
		var interceptor = Matchups.opponent_marker_for_player(gs, target)
		var interceptor_slot = Matchups.ai_slot_for_role(gs, interceptor.get("role", "ZAG"))
		var fail_msg = Narration.INTERCEPT_SUCCESS.pick_random() % [interceptor.get("name", "Adversário"), interceptor.get("role", "DEF")]
		
		SFX.play_turnover()
		gs.momentum_bonus = 0
		
		AIOpponent.reset_possession(fail_msg, interceptor_slot)


static func player_gets_ball(gs: Node, target_slot: int = 0) -> void:
	gs.possession = gs.Possession.PLAYER
	gs.turn_state = gs.TurnState.PLAYER_ATTACK

	var active_slot = target_slot
	if active_slot < gs.squad.size() and gs.squad[active_slot].get("is_ejected", false):
		for i in range(gs.squad.size()):
			if not gs.squad[i].get("is_ejected", false):
				active_slot = i
				break

	gs.zone_idx = active_slot
	gs.active_idx = active_slot


static func recover_possession(gs: Node, defender_idx: int) -> void:
	gs.possession = gs.Possession.PLAYER
	gs.turn_state = gs.TurnState.PLAYER_ATTACK

	gs.active_idx = clampi(defender_idx, 0, gs.squad.size() - 1)
	gs.zone_idx = gs.active_idx

	gs.ai_zone_idx = 0
	gs.ai_active_idx = 0
	gs.ai_momentum = 0

	gs.streak = 0
	gs.momentum_bonus = 0

	var defender = gs.squad[gs.active_idx]
	match defender.get("role", ""):
		"ZAG": gs.push_log(Narration.ZAG_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"VOL": gs.push_log(Narration.VOL_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"MEI": gs.push_log(Narration.MEI_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"CA": gs.push_log(Narration.CA_RECOVERY.pick_random() % [defender["name"], defender["role"]])


static func chance_for(gs: Node, stat_name: String) -> int:
	var tb = 0
	var marker_stat = ""
	if stat_name == "DRI":
		tb = gs.trait_bonus("DRI")
		marker_stat = "TAC"
	elif stat_name == "SHO":
		tb = gs.trait_bonus("SHO")
		marker_stat = "BLQ"

	var marker = Matchups.opponent_marker_for_player(gs, gs.active_player())

	# 🟥 Zona desprotegida: marcador da IA expulso, ataque passa livre
	if marker.get("is_ejected", false):
		return 100

	var difficulty = marker.get(marker_stat, 50) + gs._difficulty_bonus()
	return Rules.success_chance(gs.active_player().get(stat_name, 50), difficulty, gs.momentum_bonus, tb)


static func feint_chance(gs: Node) -> int:
	var p = gs.active_player()
	var marker = Matchups.opponent_marker_for_player(gs, p)

	if marker.get("is_ejected", false):
		return 100

	var stat_avg = (p.get("DRI", 50) + p.get("SHO", 50)) / 2.0
	var marker_avg = (marker.get("TAC", 50) + marker.get("BLQ", 50)) / 2.0
	var tb = gs.trait_bonus("FEINT")
	return Rules.success_chance(stat_avg, marker_avg + 8 + gs._difficulty_bonus(), gs.momentum_bonus, tb, 5, 90)


static func long_shot_chance(gs: Node) -> int:
	var marker = Matchups.opponent_marker_for_player(gs, gs.active_player())

	if marker.get("is_ejected", false):
		return 100

	var tb = gs.trait_bonus("LONG_SHO")
	return Rules.success_chance(gs.active_player().get("SHO", 50), marker.get("BLQ", 50) + 20 + gs._difficulty_bonus(), gs.momentum_bonus, tb, 5, 85)


static func pass_chance_to(gs: Node, target_idx: int) -> int:
	var target = gs.squad[target_idx]
	var marker = Matchups.opponent_marker_for_player(gs, target)

	if marker.get("is_ejected", false):
		return 100

	var distance = abs(target_idx - gs.zone_idx)
	var adjacent_bonus = 14 if distance == 1 else 0
	var distance_penalty = max(0, distance - 1) * 15
	var momentum_effect = (gs.momentum_bonus * 1.5) if distance >= 2 else float(gs.momentum_bonus)

	var tb = gs.trait_bonus("PASS")
	var effective_difficulty = marker.get("INT", 50) + distance_penalty - adjacent_bonus + gs._difficulty_bonus()
	return Rules.success_chance(gs.active_player().get("PAS", 50), effective_difficulty, momentum_effect, tb)


# ==============================================================================
# 🧤 GOLEIRO (Camada 2 de finalização — só entra depois que o chute supera a marcação)
# ==============================================================================

# is_player_shooting: true = você chuta contra o goleiro da IA;
# false = a IA chuta contra o SEU goleiro titular.
static func goalkeeper_save_chance(gs: Node, is_player_shooting: bool, is_long_shot: bool) -> int:
	var shooter = gs.active_player() if is_player_shooting else gs.ai_active_player()
	var sho_stat = float(shooter.get("SHO", 50))

	var gk = gs.current_opponent_team().get("goalkeeper", {}) if is_player_shooting else gs.active_goalkeeper()
	var save_action = "SAVE_LONG" if is_long_shot else "SAVE"
	var tb = float(RosterData.trait_bonus(gk, save_action))

	# Chute de longe testa mais o Posicionamento; chute de dentro da
	# área testa mais os Reflexos. Defesa Geral sempre pesa um pouco.
	# Mesma fórmula pros dois lados — o goleiro da IA agora tem
	# atributos reais, igual o seu, em vez de uma força genérica.
	var gk_stat: float
	if is_long_shot:
		gk_stat = gk.get("POS", 50) * 0.55 + gk.get("REF", 50) * 0.25 + gk.get("DEF", 50) * 0.20
	else:
		gk_stat = gk.get("REF", 50) * 0.55 + gk.get("DEF", 50) * 0.25 + gk.get("POS", 50) * 0.20

	return Rules.success_chance(gk_stat, sho_stat, 0, tb, 8, 88)


# Escolhe entre defesa "normal" e "milagre" conforme a chance de defesa era baixa
static func gk_save_narration(save_chance: int) -> String:
	if save_chance < 35:
		return Narration.GK_MIRACLE_SAVE.pick_random()
	return Narration.GK_SAVE.pick_random()


static func kickoff(gs: Node, start_with_player: bool = true) -> void:
	if start_with_player:
		player_gets_ball(gs)
		var p = gs.active_player()
		var msg = ""
		
		if gs.round_num == 0:
			msg = "Saída de bola! 1º Tempo começa com %s (%s)." % [p.get("name", "Jogador"), p.get("role", "")]
		else:
			msg = "Reinício de jogo. A posse da bola está com %s (%s)." % [p.get("name", "Jogador"), p.get("role", "")]

		if gs.log_messages.is_empty() or gs.log_messages[0] != msg:
			gs.push_log(msg)

	else:
		var opp_squad = gs.opponent_squad
		var zag_zone = 3
		for i in range(opp_squad.size()):
			if opp_squad[i].get("role", "") == "ZAG":
				zag_zone = i
				break

		AIOpponent.gets_ball(zag_zone)
		var p = gs.ai_active_player()
		var msg = ""
		
		if gs.round_num == (gs.MAX_ROUNDS / 2) or gs.round_num == 0:
			msg = "Saída de bola do 2º Tempo! O adversário começa jogando com %s (%s)." % [p.get("name", "Adversário"), p.get("role", "")]
		else:
			msg = "Reinício de jogo. A posse da bola está com %s (%s)." % [p.get("name", "Adversário"), p.get("role", "")]

		if gs.log_messages.is_empty() or gs.log_messages[0] != msg:
			gs.push_log(msg)
			
		AIOpponent.take_turn()

	gs.state_changed.emit()


static func advance_round(gs: Node) -> void:
	if gs.match_over:
		return

	gs.round_num += 1
	gs.consume_round_stamina()

	if gs.round_num == int(gs.MAX_ROUNDS / 2.0) and gs.first_half:
		gs.first_half = false
		MatchFlow.half_time(gs)
		return

	if gs.round_num >= gs.MAX_ROUNDS:
		gs.round_num = gs.MAX_ROUNDS

		# ⚽🆚⚽ Empate no apito final -> disputa de pênaltis, em vez de só
		# terminar empatado. match_over só vira true quando a disputa acabar
		# (GameState._finish_shootout()), então a tela de estatísticas não
		# abre no meio da disputa.
		if gs.goals == gs.ai_goals:
			gs.push_log("🔔 Fim de jogo! Empate em %d × %d — vai pra disputa de pênaltis!" % [gs.goals, gs.ai_goals])
			SFX.play_whistle()
			gs.start_shootout()
			return

		gs.match_over = true
		SFX.play_whistle()
		
		Progression.process_pending_xp(gs)
		
		if gs.goals > gs.ai_goals:
			gs.push_log("Vitória por %d × %d!" % [gs.goals, gs.ai_goals])
			if gs.game_mode == GameState.GameMode.CAMPAIGN:
				if gs.campaign_stage >= gs.MAX_CAMPAIGN_STAGE:
					gs.push_log("PARABÉNS! Você venceu a Grande Final!")
				else:
					gs.push_log("Clique em 'Próxima Partida' para continuar a campanha.")
			else:
				gs.push_log("Clique em 'Próximo Desafio' para avançar.")
		else:
			gs.push_log("Derrota por %d × %d." % [gs.goals, gs.ai_goals])
			
		gs.state_changed.emit()
