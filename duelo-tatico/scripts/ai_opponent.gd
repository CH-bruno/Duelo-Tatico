class_name AIOpponent
extends Node
# AIOpponent.gd — Cérebro do adversário e resolução de ações defensivas.

static func attack_strength() -> int:
	var p = GameState.ai_active_player()
	var stat = 0

	match GameState.ai_next_move:
		GameState.AIMove.PASS:
			stat = p["PAS"]
		GameState.AIMove.DRIBBLE:
			stat = p["DRI"]
		GameState.AIMove.LONG_SHOT:
			stat = p["SHO"] + 5
		GameState.AIMove.SHOT:
			stat = p["SHO"]

	return stat + (GameState.difficulty_stage() - 1) * 2


static func gets_ball(player_zone: int = 0) -> void:
	GameState.possession = GameState.Possession.AI
	GameState.turn_state = GameState.TurnState.PLAYER_DEFENSE

	GameState.ai_zone_idx = GameState.attacker_for_zone(player_zone)
	GameState.ai_active_idx = GameState.ai_zone_idx
	GameState.ai_momentum = 0

	var starter = GameState.ai_active_player()
	match starter["role"]:
		"ZAG":
			GameState.push_log(Narration.ZAG_RECOVERY.pick_random() % [starter["name"], starter["role"]])
		"VOL":
			GameState.push_log(Narration.VOL_RECOVERY.pick_random() % [starter["name"], starter["role"]])
		"MEI":
			GameState.push_log(Narration.MEI_RECOVERY.pick_random() % [starter["name"], starter["role"]])
		"CA":
			GameState.push_log(Narration.CA_RECOVERY.pick_random() % [starter["name"], starter["role"]])


static func take_turn() -> void:
	if GameState.possession != GameState.Possession.AI:
		return

	GameState.turn_state = GameState.TurnState.PLAYER_DEFENSE
	_choose_move()

	var p = GameState.ai_active_player()
	match GameState.ai_next_move:
		GameState.AIMove.PASS:
			GameState.push_log("%s (%s) procura um companheiro para o passe." % [p["name"], p["role"]])
		GameState.AIMove.DRIBBLE:
			GameState.push_log("%s (%s) parte para o drible!" % [p["name"], p["role"]])
		GameState.AIMove.LONG_SHOT:
			GameState.push_log("%s (%s) prepara um chute de longe!" % [p["name"], p["role"]])
		GameState.AIMove.SHOT:
			GameState.push_log("%s (%s) ficou cara a cara com o gol!" % [p["name"], p["role"]])

	GameState.state_changed.emit()


static func _choose_move() -> void:
	GameState.ai_active_idx = GameState.ai_zone_idx
	var player = GameState.ai_active_player()

	# Postura Tática da IA no 2º Tempo
	var ai_losing = GameState.ai_goals < GameState.goals
	var ai_winning = GameState.ai_goals > GameState.goals

	match player["role"]:
		"ZAG":
			if ai_losing and not GameState.first_half and randi() % 100 < 35:
				GameState.ai_next_move = GameState.AIMove.DRIBBLE
			else:
				GameState.ai_next_move = GameState.AIMove.PASS

		"VOL":
			if ai_winning:
				GameState.ai_next_move = GameState.AIMove.PASS
			else:
				GameState.ai_next_move = GameState.AIMove.PASS if randi() % 100 < 65 else GameState.AIMove.DRIBBLE

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
			if GameState.ai_zone_idx >= 1 and ai_losing:
				GameState.ai_next_move = GameState.AIMove.SHOT
			else:
				GameState.ai_next_move = GameState.AIMove.SHOT if GameState.ai_zone_idx >= 2 else GameState.AIMove.DRIBBLE


static func resolve_shot(bonus: int = 0) -> void:
	var attack = attack_strength() + GameState.ai_momentum
	var defender_idx = GameState.defender_for_attacker()
	var block_value = defense_effectiveness("BLOCK", defender_idx)

	var diff = attack - block_value
	var chance = clampi(round(50 + diff * 0.6) + bonus, 8, 92)

	if randi_range(1, 100) <= chance:
		GameState.ai_goals += 1
		var scorer = GameState.ai_active_player()
		GameState.push_log(Narration.GOAL_CALL.pick_random())
		GameState.push_log(Narration.GOAL.pick_random() % [scorer["name"], scorer["role"]])
		SFX.play_goal()
	else:
		GameState.grant_xp(3)
		GameState.push_log("Seu goleiro fez a defesa!")

	MatchEngine.kickoff(GameState, true)
	GameState.ai_momentum = 0


static func reset_possession(reason: String, start_zone: int = 0) -> void:
	GameState.turnovers += 1
	if reason != "":
		GameState.push_log(reason)
	SFX.play_turnover()
	gets_ball(start_zone)
	take_turn()


static func defense_chance(action: String) -> int:
	var defender_idx = GameState.defender_for_attacker()
	var matches = _matches_move(action, GameState.ai_next_move)
	var effectiveness = defense_effectiveness(action, defender_idx)

	if not matches:
		effectiveness = int(effectiveness * 0.5)

	return clampi(round(50 + (effectiveness - attack_strength()) * 0.6), 8, 92)


static func defend(action: String) -> void:
	if GameState.turn_state != GameState.TurnState.PLAYER_DEFENSE:
		return

	var defender_idx = GameState.defender_for_attacker()
	var defender_roster_idx = GameState.starters[defender_idx]

	var chance = defense_chance(action)
	var success = randi_range(1, 100) <= chance

	# Consumo pós-ação defensiva
	GameState.consume_action_stamina(defender_roster_idx, action, success, true)

	if success:
		match action:
			"INTERCEPT":
				Stats.interception()
				SFX.play_intercept()
			"TACKLE":
				Stats.tackle()
				SFX.play_tackle()
			"BLOCK":
				Stats.block()
				SFX.play_block()

		GameState.push_log("Sua defesa (%s) funcionou! (%d%% de chance)" % [_label(action), chance])
		GameState.recover_possession(defender_idx)

	else:
		GameState.push_log("A defesa (%s) não foi suficiente (%d%% de chance)." % [_label(action), chance])
		SFX.play_defense_fail()
		_move_succeeds()

	MatchEngine.advance_round(GameState)
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
		"INTERCEPT": return "Interceptação"
		"TACKLE": return "Desarme"
		"BLOCK": return "Bloqueio"
	return defense_type


static func defense_effectiveness(defense_type: String, defender_idx: int) -> int:
	return _stat_for(GameState.squad[defender_idx], defense_type)


static func _stat_for(player: Dictionary, defense_type: String) -> int:
	var base = 0
	match defense_type:
		"INTERCEPT":
			base = player["INT"]
		"TACKLE":
			base = player["TAC"]
		"BLOCK":
			base = player["BLQ"]
	return base + RosterData.trait_bonus(player, defense_type)


static func _move_succeeds() -> void:
	match GameState.ai_next_move:
		GameState.AIMove.PASS:
			var passer = GameState.ai_active_player()
			var next_zone = clampi(GameState.ai_zone_idx + 1, 0, GameState.ZONES.size() - 1)
			var receiver = GameState.current_opponent_team()["squad"][next_zone]

			GameState.ai_zone_idx = next_zone
			GameState.ai_active_idx = GameState.ai_zone_idx

			GameState.push_log("Passe de %s (%s) para %s (%s)." % [passer["name"], passer["role"], receiver["name"], receiver["role"]])
			take_turn()

		GameState.AIMove.DRIBBLE:
			var dribbler = GameState.ai_active_player()
			GameState.push_log("%s (%s) passou pelo marcador." % [dribbler["name"], dribbler["role"]])
			GameState.ai_momentum += 20
			take_turn()

		GameState.AIMove.LONG_SHOT, GameState.AIMove.SHOT:
			resolve_shot()

static func check_ai_substitutions() -> void:
	var team = GameState.current_opponent_team()
	var squad = team["squad"]

	# A IA tem até 2 substituições por jogo
	if not team.has("subs_left"):
		team["subs_left"] = 2

	if team["subs_left"] <= 0:
		return

	for i in range(squad.size()):
		var p = squad[i]
		# Se a stamina do jogador do time rival baixar de 45%
		var st = p.get("stamina", 100.0)
		if st < 45.0:
			team["subs_left"] -= 1
			p["stamina"] = 100.0 # Reserva entra com energia renovada
			GameState.push_log("🔄 O adversário substituiu %s (%s) por fôlego novo!" % [p["name"], p["role"]])
			break
