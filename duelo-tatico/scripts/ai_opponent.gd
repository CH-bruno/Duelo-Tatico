class_name AIOpponent
extends Node
# AIOpponent.gd — Cérebro do adversário e resolução de ações defensivas.

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

	var opp_squad = GameState.current_opponent_team().get("squad", [])
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
		match starter.get("role", ""):
			"ZAG": GameState.push_log(Narration.ZAG_RECOVERY.pick_random() % [starter.get("name", "Jogador"), starter.get("role", "ZAG")])
			"VOL": GameState.push_log(Narration.VOL_RECOVERY.pick_random() % [starter.get("name", "Jogador"), starter.get("role", "VOL")])
			"MEI": GameState.push_log(Narration.MEI_RECOVERY.pick_random() % [starter.get("name", "Jogador"), starter.get("role", "MEI")])
			"CA": GameState.push_log(Narration.CA_RECOVERY.pick_random() % [starter.get("name", "Jogador"), starter.get("role", "CA")])


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

	var diff = attack - block_value
	var chance = clampi(int(round(50 + diff * 0.6)) + bonus, 8, 92)

	if randi_range(1, 100) <= chance:
		GameState.ai_goals += 1
		var scorer = GameState.ai_active_player()
		GameState.push_log(Narration.GOAL_CALL.pick_random())
		GameState.push_log(Narration.GOAL.pick_random() % [scorer.get("name", "Jogador"), scorer.get("role", "")])
		SFX.play_goal()
	else:
		GameState.grant_xp(3)
		GameState.push_log("Seu goleiro fez a defesa!")

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
		# 🦵 CARRINHO PONDERADO: 70% Desarme (TAC vs DRI) + 30% Interceptação (INT vs PAS)
		var tac = float(_stat_for(defender_dict, "TACKLE"))
		var int_stat = float(_stat_for(defender_dict, "INTERCEPT"))
		var dri = float(attacker_dict.get("DRI", 50))
		var pas = float(attacker_dict.get("PAS", 50))

		var tac_diff = tac - dri
		var int_diff = int_stat - pas
		var weighted_diff = (tac_diff * 0.70) + (int_diff * 0.30)

		# BÔNUS FIXO: +5% de bônus base
		var slide_base_bonus = 5
		
		return clampi(int(round(65 + weighted_diff * 1.3)) + slide_base_bonus, 20, 92)

	# Lógica para INTERCEPT, TACKLE e BLOCK
	var matches = _matches_move(action, GameState.ai_next_move)
	var effectiveness = float(_stat_for(defender_dict, action))

	if not matches:
		effectiveness = effectiveness * 0.5

	return clampi(int(round(50 + (effectiveness - attack_strength()) * 0.6)), 8, 92)


static func defend(action: String) -> void:
	if GameState.turn_state != GameState.TurnState.PLAYER_DEFENSE:
		return

	var defender_dict = GameState.active_defender()
	var defender_slot = Matchups.player_slot_for_role(GameState, defender_dict.get("role", "ZAG"))
	var defender_roster_idx = GameState.starters[defender_slot] if defender_slot < GameState.starters.size() else GameState.starters[0]

	var chance = defense_chance(action)
	var success = randi_range(1, 100) <= chance

	GameState.consume_action_stamina(defender_roster_idx, action, success, true)

	var def_name = defender_dict.get("name", "Jogador")
	var def_role = defender_dict.get("role", "DEF")

	if success:
		match action:
			"SLIDE":
				Stats.tackle()
				Stats.interception()
				SFX.play_tackle()
				GameState.push_log(Narration.SLIDE_SUCCESS.pick_random() % [def_name, def_role])
			"INTERCEPT":
				Stats.interception()
				SFX.play_intercept()
				GameState.push_log(Narration.INTERCEPT_SUCCESS.pick_random() % [def_name, def_role])
			"TACKLE":
				Stats.tackle()
				SFX.play_tackle()
				GameState.push_log(Narration.TACKLE_SUCCESS.pick_random() % [def_name, def_role])
			"BLOCK":
				Stats.block()
				SFX.play_block()
				GameState.push_log(Narration.BLOCK_SUCCESS.pick_random() % [def_name, def_role])

		GameState.recover_possession(defender_slot)

	else:
		GameState.push_log(Narration.DEFENSE_BYPASSED.pick_random() % [def_name, def_role])
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
			var opp_squad = GameState.current_opponent_team().get("squad", [])
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

			GameState.push_log("Passe de %s (%s) para %s (%s)." % [
				passer.get("name", "Jogador"), passer.get("role", ""), 
				receiver.get("name", "Companheiro"), receiver.get("role", "")
			])
			
			take_turn()

		GameState.AIMove.DRIBBLE:
			var dribbler = GameState.ai_active_player()
			GameState.push_log("%s (%s) passou pelo marcador." % [dribbler.get("name", "Jogador"), dribbler.get("role", "")])
			GameState.ai_momentum += 20
			take_turn()

		GameState.AIMove.LONG_SHOT, GameState.AIMove.SHOT:
			resolve_shot()
			
	MatchEngine.advance_round(GameState)
