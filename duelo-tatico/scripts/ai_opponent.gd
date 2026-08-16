class_name AIOpponent
extends Node
# AIOpponent.gd — Cérebro do adversário e resolução de ações defensivas.

# 🎯 Função utilitária para formatar mensagens da Narration sem estourar o erro de formato de argumentos
static func _format_narration(template: String, args: Array) -> String:
	var expected_count = template.count("%s")
	if args.size() == expected_count:
		return template % args
	elif args.size() > expected_count:
		return template % args.slice(0, expected_count)
	else:
		# Se faltar argumentos na lista, preenche com placeholders vazios
		var safe_args = args.duplicate()
		while safe_args.size() < expected_count:
			safe_args.append("")
		return template % safe_args


static func attack_strength() -> int:
	var p = GameState.ai_active_player()
	var stat = 0

	match GameState.ai_next_move:
		GameState.AIMove.PASS:
			stat = p.get("PAS", 50)
		GameState.AIMove.DRIBBLE:
			stat = p.get("DRI", 50)
		GameState.AIMove.LONG_SHOT:
			stat = p.get("SHO", 50) + 5
		GameState.AIMove.SHOT:
			stat = p.get("SHO", 50)

	return stat + (GameState.difficulty_stage() - 1) * 2


static func gets_ball(start_zone: int = 3, is_recovery: bool = false) -> void:
	GameState.possession = GameState.Possession.AI
	GameState.turn_state = GameState.TurnState.PLAYER_DEFENSE

	var opp_squad = GameState.opponent_squad
	var target_zone = clampi(start_zone, 0, max(0, opp_squad.size() - 1))

	# VALIDAÇÃO DE JOGADOR EXPULSO:
	if opp_squad.size() > target_zone and opp_squad[target_zone].get("is_ejected", false):
		for i in range(opp_squad.size()):
			if not opp_squad[i].get("is_ejected", false):
				target_zone = i
				break

	GameState.ai_zone_idx = target_zone
	GameState.ai_active_idx = target_zone
	GameState.ai_momentum = 0

	if is_recovery:
		var starter = GameState.ai_active_player()
		var s_name = starter.get("name", "Jogador")
		var s_role = starter.get("role", "")
		match s_role:
			"ZAG": GameState.push_log(_format_narration(Narration.ZAG_RECOVERY.pick_random(), [s_name, s_role]))
			"VOL": GameState.push_log(_format_narration(Narration.VOL_RECOVERY.pick_random(), [s_name, s_role]))
			"MEI": GameState.push_log(_format_narration(Narration.MEI_RECOVERY.pick_random(), [s_name, s_role]))
			"CA": GameState.push_log(_format_narration(Narration.CA_RECOVERY.pick_random(), [s_name, s_role]))


static func take_turn() -> void:
	# 🛑 Não processa turno da IA se o jogo acabou
	if GameState.match_over or GameState.possession != GameState.Possession.AI:
		return

	GameState.turn_state = GameState.TurnState.PLAYER_DEFENSE
	_choose_move()

	var p = GameState.ai_active_player()
	match GameState.ai_next_move:
		GameState.AIMove.PASS:
			GameState.push_log("%s (%s) procura um companheiro para o passe." % [p.get("name", "Jogador"), p.get("role", "")])
		GameState.AIMove.DRIBBLE:
			GameState.push_log("%s (%s) parte para o drible!" % [p.get("name", "Jogador"), p.get("role", "")])
		GameState.AIMove.LONG_SHOT:
			GameState.push_log("%s (%s) prepara um chute de longe!" % [p.get("name", "Jogador"), p.get("role", "")])
		GameState.AIMove.SHOT:
			GameState.push_log("%s (%s) ficou cara a cara com o gol!" % [p.get("name", "Jogador"), p.get("role", "")])

	GameState.state_changed.emit()


static func _choose_move() -> void:
	GameState.ai_active_idx = GameState.ai_zone_idx
	var player = GameState.ai_active_player()

	var ai_losing = GameState.ai_goals < GameState.goals
	var ai_winning = GameState.ai_goals > GameState.goals

	match player.get("role", ""):
		"ZAG":
			GameState.ai_next_move = GameState.AIMove.PASS

		"VOL":
			if ai_winning:
				GameState.ai_next_move = GameState.AIMove.PASS
			else:
				GameState.ai_next_move = GameState.AIMove.PASS if randi() % 100 < 80 else GameState.AIMove.DRIBBLE

		"MEI":
			var r = randi() % 100
			if ai_losing and not GameState.first_half:
				if r < 20: GameState.ai_next_move = GameState.AIMove.PASS
				elif r < 60: GameState.ai_next_move = GameState.AIMove.DRIBBLE
				else: GameState.ai_next_move = GameState.AIMove.LONG_SHOT
			else:
				if r < 35: GameState.ai_next_move = GameState.AIMove.PASS
				elif r < 80: GameState.ai_next_move = GameState.AIMove.DRIBBLE
				else: GameState.ai_next_move = GameState.AIMove.LONG_SHOT

		"CA":
			if GameState.ai_zone_idx == 0:
				GameState.ai_next_move = GameState.AIMove.SHOT
			else:
				GameState.ai_next_move = GameState.AIMove.SHOT if randi() % 100 < 50 else GameState.AIMove.DRIBBLE


static func resolve_shot(bonus: int = 0) -> void:
	var attack = attack_strength() + GameState.ai_momentum
	var defender_dict = GameState.active_defender()
	var block_value = _stat_for(defender_dict, "BLOCK")
	var is_long = GameState.ai_next_move == GameState.AIMove.LONG_SHOT

	var diff = attack - block_value
	var block_chance = clampi(int(round(50 + diff * 0.6)) + bonus, 8, 92)

	# 🛡️ CAMADA 1: o marcador tenta bloquear o chute
	if randi_range(1, 100) > block_chance:
		GameState.grant_xp(3)
		GameState.push_log(_format_narration(Narration.BLOCK_SUCCESS.pick_random(), [defender_dict.get("name", "Jogador"), defender_dict.get("role", "DEF")]))
	else:
		# ⚠️ Seu marcador foi superado — credita a falha antes de ir pro goleiro
		GameState.push_log(_format_narration(Narration.BLOCK_FAIL.pick_random(), [defender_dict.get("name", "Jogador"), defender_dict.get("role", "DEF")]))

		# 🥅 CAMADA 2: passou da marcação — agora é o SEU goleiro
		var save_chance = MatchEngine.goalkeeper_save_chance(GameState, false, is_long)
		var gk_saved = randi_range(1, 100) <= save_chance
		var gk = GameState.active_goalkeeper()

		GameState.consume_gk_action_stamina("SAVE_LONG" if is_long else "SAVE", gk_saved)

		if gk_saved:
			GameState.grant_xp(4)
			GameState.push_log(_format_narration(MatchEngine.gk_save_narration(save_chance), [gk.get("name", "Goleiro")]))
		else:
			GameState.ai_goals += 1
			var scorer = GameState.ai_active_player()
			GameState.push_log(_format_narration(Narration.GK_BEATEN.pick_random(), [gk.get("name", "Goleiro")]))
			GameState.push_log(Narration.GOAL_CALL.pick_random())
			GameState.push_log(_format_narration(Narration.GOAL.pick_random(), [scorer.get("name", "Jogador"), scorer.get("role", "")]))
			SFX.play_goal()

	MatchEngine.kickoff(GameState, true)
	GameState.ai_momentum = 0


static func reset_possession(reason: String, start_zone: int = 3) -> void:
	GameState.turnovers += 1
	
	if reason != "":
		GameState.push_log(reason)
		
	SFX.play_turnover()
	gets_ball(start_zone, true)
	take_turn()


static func defense_chance(action: String) -> int:
	var defender_dict = GameState.active_defender()
	var attacker_dict = GameState.ai_active_player()

	if action == "SLIDE":
		var tac = float(_stat_for(defender_dict, "TACKLE"))
		var int_stat = float(_stat_for(defender_dict, "INTERCEPT"))
		var dri = float(attacker_dict.get("DRI", 50))
		var pas = float(attacker_dict.get("PAS", 50))

		var tac_diff = tac - dri
		var int_diff = int_stat - pas
		var weighted_diff = (tac_diff * 0.70) + (int_diff * 0.30)
		var slide_base_bonus = 5
		
		return clampi(int(round(65 + weighted_diff * 1.3)) + slide_base_bonus, 20, 92)

	var matches = _matches_move(action, GameState.ai_next_move)
	var effectiveness = float(_stat_for(defender_dict, action))

	if not matches:
		effectiveness = effectiveness * 0.5

	return clampi(int(round(50 + (effectiveness - attack_strength()) * 0.6)), 8, 92)


static func defend(action: String) -> void:
	if GameState.turn_state != GameState.TurnState.PLAYER_DEFENSE or GameState.match_over:
		return

	var defender_dict = GameState.active_defender()
	var defender_slot = Matchups.player_slot_for_role(GameState, defender_dict.get("role", "ZAG"))
	var defender_roster_idx = GameState.starters[defender_slot] if defender_slot < GameState.starters.size() else GameState.starters[0]

	var chance = defense_chance(action)
	var success = randi_range(1, 100) <= chance

	GameState.consume_action_stamina(defender_roster_idx, action, success, true)

	var def_name = defender_dict.get("name", "Jogador")
	var def_role = defender_dict.get("role", "DEF")
	var att_player = GameState.ai_active_player()
	var att_name = att_player.get("name", "Atacante")
	var att_role = att_player.get("role", "")

	if success:
		# ✅ BOLA LIMPA / SUCESSO: ZERO CHANCE DE FALTA OU PÊNALTI
		match action:
			"SLIDE":
				Stats.tackle()
				Stats.interception()
				SFX.play_tackle()
				GameState.push_log(_format_narration(Narration.SLIDE_SUCCESS.pick_random(), [def_name, def_role, att_name, att_role]))
			"INTERCEPT":
				Stats.interception()
				SFX.play_intercept()
				GameState.push_log(_format_narration(Narration.INTERCEPT_SUCCESS.pick_random(), [def_name, def_role, att_name, att_role]))
			"TACKLE":
				Stats.tackle()
				SFX.play_tackle()
				GameState.push_log(_format_narration(Narration.TACKLE_SUCCESS.pick_random(), [def_name, def_role, att_name, att_role]))
			"BLOCK":
				Stats.block()
				SFX.play_block()
				GameState.push_log(_format_narration(Narration.BLOCK_SUCCESS.pick_random(), [def_name, def_role, att_name, att_role]))

		# Recupera a posse da bola para o jogador
		GameState.recover_possession(defender_slot)
		MatchEngine.advance_round(GameState)

	else:
		# ❌ FALHA NA AÇÃO DEFENSIVA: Define o contexto da falta por tipo de ação
		var foul_context = "SLIDE_MISS_FOUL"
		match action:
			"SLIDE": foul_context = "SLIDE_MISS_FOUL"
			"TACKLE": foul_context = "TACKLE_MISS_FOUL"
			"BLOCK": foul_context = "BLOCK_MISS_FOUL"
			"INTERCEPT": foul_context = "INTERCEPT_MISS_FOUL"
		
		# Avalia a infração (Passa 'true' porque foi a sua defesa que cometeu a ação)
		var decision = Referee.evaluate_foul(GameState, foul_context, true)
		
		if decision == Referee.Decision.PENALTY:
			# 🚨 PÊNALTI CONTRA O JOGADOR (Falta no CA da IA dentro da sua área)
			Referee.process_cards(GameState, defender_roster_idx, defender_dict, action == "SLIDE")

			# 🟥 Se essa expulsão decretou WO, o jogo já acabou — não cobra o pênalti
			if GameState.match_over:
				GameState.state_changed.emit()
				return

			PenaltyEngine.start_penalty(GameState, false)
			return
		elif decision == Referee.Decision.FOUL:
			# ⚠️ FALTA COMUM DA SUA DEFESA (Fora da área — contra VOL, MEI ou ZAG da IA)
			Referee.process_cards(GameState, defender_roster_idx, defender_dict, action == "SLIDE")
			
			if action == "SLIDE":
				GameState.push_log(_format_narration(Narration.FOUL_SLIDE.pick_random(), [def_name, def_role, att_name, att_role]))
			else:
				GameState.push_log(_format_narration(Narration.FOUL_COMMITTED.pick_random(), [def_name, def_role, att_name, att_role]))

			# 🟥 Se essa expulsão decretou WO, o jogo já acabou — não segue o lance
			if GameState.match_over:
				GameState.state_changed.emit()
				return

			_move_succeeds()
			return
		else:
			# ❌ Superado no lance (Sem falta / Drible limpo da IA)
			GameState.push_log(_format_narration(Narration.DEFENSE_BYPASSED.pick_random(), [def_name, def_role, att_name, att_role]))
			SFX.play_defense_fail()
			_move_succeeds()

	GameState.state_changed.emit()
	
static func _matches_move(defense_type: String, move) -> bool:
	match defense_type:
		"INTERCEPT":
			return move == GameState.AIMove.PASS
		"TACKLE":
			return move == GameState.AIMove.DRIBBLE
		"BLOCK":
			return move == GameState.AIMove.SHOT or move == GameState.AIMove.LONG_SHOT
	return false


static func _label(defense_type: String) -> String:
	match defense_type:
		"SLIDE": return "Carrinho"
		"INTERCEPT": return "Interceptação"
		"TACKLE": return "Desarme"
		"BLOCK": return "Bloqueio"
	return defense_type


static func _stat_for(player: Dictionary, defense_type: String) -> int:
	var base = 0
	match defense_type:
		"INTERCEPT":
			base = player.get("INT", 50)
		"TACKLE":
			base = player.get("TAC", 50)
		"BLOCK":
			base = player.get("BLQ", 50)
		"SLIDE":
			base = int((player.get("TAC", 50) * 0.7) + (player.get("INT", 50) * 0.3))
	return base + RosterData.trait_bonus(player, defense_type)


static func _move_succeeds() -> void:
	# 🛑 Interrompe avanço automático da IA no fim do jogo
	if GameState.match_over:
		return

	match GameState.ai_next_move:
		GameState.AIMove.PASS:
			var passer = GameState.ai_active_player()
			var opp_squad = GameState.opponent_squad
			var current_idx = GameState.ai_active_idx

			var valid_targets: Array[int] = []
			for i in range(opp_squad.size()):
				if i != current_idx and not opp_squad[i].get("is_ejected", false):
					valid_targets.append(i)

			var next_idx = current_idx
			if not valid_targets.is_empty():
				var forward_target = current_idx - 1
				if forward_target in valid_targets:
					next_idx = forward_target
				else:
					next_idx = valid_targets.pick_random()

			var receiver = opp_squad[clampi(next_idx, 0, opp_squad.size() - 1)]

			GameState.ai_zone_idx = next_idx
			GameState.ai_active_idx = next_idx

			GameState.push_log(_format_narration(Narration.PASS_SUCCESS.pick_random(), [
				passer.get("name", "Jogador"), passer.get("role", ""), 
				receiver.get("name", "Companheiro"), receiver.get("role", "")
			]))
			
			take_turn()

		GameState.AIMove.DRIBBLE:
			var dribbler = GameState.ai_active_player()
			GameState.push_log(_format_narration(Narration.DRIBBLE_SUCCESS.pick_random(), [dribbler.get("name", "Jogador"), dribbler.get("role", "")]))
			GameState.ai_momentum += 20
			take_turn()

		GameState.AIMove.LONG_SHOT, GameState.AIMove.SHOT:
			resolve_shot()
			
	MatchEngine.advance_round(GameState)
