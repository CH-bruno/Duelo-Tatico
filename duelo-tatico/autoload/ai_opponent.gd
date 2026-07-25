extends Node
# Autoload — cérebro do adversário: qual jogada ele escolhe e a
# resolução do sistema de defesa (Interceptação/Desarme/Bloqueio).
#
# Os índices de zona da IA (ai_zone_idx, ai_active_idx, ai_next_move,
# ai_momentum) continuam morando no GameState — são estado compartilhado
# da partida. Aqui só ficam as DECISÕES sobre esse estado. O enum
# AIMove também fica no GameState (é lá que a variável ai_next_move é
# declarada), então usamos GameState.AIMove.X em vez de duplicar o enum.

const Narration = preload("res://scripts/Narration.gd")
const RosterData = preload("res://scripts/RosterData.gd")


func attack_strength() -> int:
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


func gets_ball(player_zone: int = 0) -> void:
	# player_zone: a zona SUA onde a bola foi perdida — o jogador da IA
	# que fisicamente ocupa essa coluna (espelhado) é quem assume.
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


func take_turn() -> void:
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


func _choose_move() -> void:
	GameState.ai_active_idx = GameState.ai_zone_idx
	var player = GameState.ai_active_player()

	match player["role"]:
		"ZAG":
			GameState.ai_next_move = GameState.AIMove.PASS
		"VOL":
			GameState.ai_next_move = GameState.AIMove.PASS if randi() % 100 < 75 else GameState.AIMove.DRIBBLE
		"MEI":
			var r = randi() % 100
			if r < 35:
				GameState.ai_next_move = GameState.AIMove.PASS
			elif r < 80:
				GameState.ai_next_move = GameState.AIMove.DRIBBLE
			else:
				GameState.ai_next_move = GameState.AIMove.LONG_SHOT
		"CA":
			GameState.ai_next_move = GameState.AIMove.SHOT if GameState.ai_zone_idx >= 2 else GameState.AIMove.DRIBBLE


func resolve_shot(bonus: int = 0) -> void:
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

	# Sempre reinicia com você, independente do resultado.
	GameState._kickoff(true)
	GameState.ai_momentum = 0


func reset_possession(reason: String, start_zone: int = 0) -> void:
	GameState.turnovers += 1
	if reason != "":
		GameState.push_log(reason)
	SFX.play_turnover()
	gets_ball(start_zone)
	take_turn()


func defense_chance(action: String) -> int:
	var defender_idx = GameState.defender_for_attacker()
	var matches = _matches_move(action, GameState.ai_next_move)
	var effectiveness = defense_effectiveness(action, defender_idx)

	if not matches:
		effectiveness = int(effectiveness * 0.5)

	return clampi(round(50 + (effectiveness - attack_strength()) * 0.6), 8, 92)


func defend(action: String) -> void:
	if GameState.turn_state != GameState.TurnState.PLAYER_DEFENSE:
		return

	var chance = defense_chance(action)
	var success = randi_range(1, 100) <= chance
	var defender_idx = GameState.defender_for_attacker()

	if success:
		match action:
			"INTERCEPT": Stats.interceptions += 1
			"TACKLE": Stats.tackles += 1
			"BLOCK": Stats.blocks += 1
		GameState.push_log("Sua defesa (%s) funcionou! (%d%% de chance)" % [_label(action), chance])
		SFX.play_music("res://audio/pass.mp3")
		GameState.recover_possession(defender_idx)
	else:
		GameState.push_log("A defesa (%s) não foi suficiente (%d%% de chance)." % [_label(action), chance])
		SFX.play_music("res://audio/pass.mp3")
		_move_succeeds()

	GameState._advance_round()
	GameState.state_changed.emit()


func _matches_move(defense_type: String, move) -> bool:
	match defense_type:
		"INTERCEPT":
			return move == GameState.AIMove.PASS
		"TACKLE":
			return move == GameState.AIMove.DRIBBLE
		"BLOCK":
			return move == GameState.AIMove.SHOT or move == GameState.AIMove.LONG_SHOT
	return false


func _label(defense_type: String) -> String:
	match defense_type:
		"INTERCEPT": return "Interceptação"
		"TACKLE": return "Desarme"
		"BLOCK": return "Bloqueio"
	return defense_type


func defense_effectiveness(defense_type: String, defender_idx: int) -> int:
	return _stat_for(GameState.squad[defender_idx], defense_type)


func _stat_for(player: Dictionary, defense_type: String) -> int:
	var base = 0
	match defense_type:
		"INTERCEPT":
			base = player["INT"]
		"TACKLE":
			base = player["TAC"]
		"BLOCK":
			base = player["BLQ"]
	return base + RosterData.trait_bonus(player, defense_type)


func _move_succeeds() -> void:
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
