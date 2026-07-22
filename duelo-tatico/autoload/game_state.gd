extends Node
# Autoload (singleton) que orquestra o jogo.

signal state_changed

const Narration = preload("res://scripts/Narration.gd")
const RosterData = preload("res://scripts/RosterData.gd")
const Rules = preload("res://scripts/Rules.gd")
const OpponentTeams = preload("res://scripts/OpponentTeams.gd")

const ZONES = ["Campo Próprio", "Meio-Campo", "Terço Final", "Grande Área"]

const MAX_CAMPAIGN_STAGE = 5

var starters = [0, 2, 4, 6]
var squad = []

var zone_idx = 0
var active_idx = 0

var level = 1
var xp = 0
var xp_to_next = 20

var goals = 0
var ai_goals = 0
var turnovers = 0
var streak = 0

const MAX_ROUNDS = 30
var round_num = 0
var match_over = false

var campaign_stage = 1

var challenge_wins = 0
var challenge_best = 0

var momentum_bonus = 0

var log_messages = []

enum GameMode { CAMPAIGN, CHALLENGE }
var game_mode = GameMode.CAMPAIGN

enum Possession { PLAYER, AI }
var possession = Possession.PLAYER

enum TurnState { PLAYER_ATTACK, PLAYER_DEFENSE }
var turn_state = TurnState.PLAYER_ATTACK

enum AIMove { PASS, DRIBBLE, LONG_SHOT, SHOT }
var ai_next_move = AIMove.PASS

# ai_zone_idx segue a MESMA convenção do seu zone_idx: 0 = saída de bola
# (ZAG deles), 3 = finalização (CA deles). ai_active_idx é sempre igual
# a ai_zone_idx — sem espelhar. O espelhamento (3 - zona) só é usado
# quando é preciso saber quem do OUTRO time está numa zona.
var ai_zone_idx = 0
var ai_active_idx = 0
var ai_momentum = 0


func _ready():
	_apply_lineup()
	push_log("Apito inicial. A bola está com o %s." % active_player()["name"])
	SFX.play_whistle()


# ---------- Elenco / escalação ----------

func candidates_for(role_idx: int) -> Array:
	return RosterData.candidates_for(role_idx)


func trait_name(trait_id: String) -> String:
	return RosterData.trait_name(trait_id)


func trait_bonus(action: String) -> int:
	return RosterData.trait_bonus(active_player(), action)


func set_lineup(new_starters: Array) -> void:
	if new_starters.size() != RosterData.ROLES.size():
		return
	starters = new_starters.duplicate()
	_apply_lineup()
	state_changed.emit()


func _apply_lineup() -> void:
	var growth_levels = level - 1
	squad = []
	for idx in starters:
		var p = RosterData.ROSTER[idx].duplicate()
		p["PAS"] = min(95, p["PAS"] + 2 * growth_levels)
		p["DRI"] = min(95, p["DRI"] + 2 * growth_levels)
		p["SHO"] = min(95, p["SHO"] + 3 * growth_levels)
		p["INT"] = min(95, p["INT"] + 2 * growth_levels)
		p["TAC"] = min(95, p["TAC"] + 2 * growth_levels)
		p["BLQ"] = min(95, p["BLQ"] + 2 * growth_levels)
		squad.append(p)


func active_player() -> Dictionary:
	return squad[active_idx]


func player_in_zone(zone: int) -> Dictionary:
	return squad[zone]


func player_gets_ball() -> void:
	possession = Possession.PLAYER
	turn_state = TurnState.PLAYER_ATTACK

	zone_idx = 0
	active_idx = 0

	ai_zone_idx = 0
	ai_active_idx = 0
	ai_momentum = 0

	streak = 0
	momentum_bonus = 0


func current_opponent_team() -> Dictionary:
	if game_mode == GameMode.CHALLENGE:
		return OpponentTeams.team_for_challenge(challenge_wins)
	return OpponentTeams.team_for_stage(campaign_stage)


func opponent_team_name() -> String:
	return current_opponent_team()["name"]


func ai_active_player() -> Dictionary:
	# Acesso direto — igual seu active_player(). ai_zone_idx e
	# ai_active_idx significam a mesma coisa, sem espelhar.
	return current_opponent_team()["squad"][ai_active_idx]


func opponent_player_at(zone: int) -> Dictionary:
	return current_opponent_team()["squad"][zone]

# ---------- Quem marca quem (espelhado: zona i marcada pela zona 3-i) ----------

func attacker_for_zone(zone: int) -> int:
	return 3 - zone

func defender_for_attacker() -> int:
	# Índice no SEU squad que marca o jogador adversário ativo agora.
	return attacker_for_zone(ai_zone_idx)

func ai_active_column() -> int:
	# A coluna física onde a bola da IA está agora — espelhada, porque
	# o time dela ataca na direção oposta no mesmo campo.
	return attacker_for_zone(ai_zone_idx)
	
func team_player_at_column(column: int, mine: bool) -> Dictionary:
	# Função única pra UI: dado uma coluna do campo, devolve quem do seu
	# time ou do adversário fisicamente ocupa ela — sem o chamador
	# precisar saber nada sobre espelhamento.
	if mine:
		return squad[column]
	return opponent_player_at(attacker_for_zone(column))


func _opponent_marker_for(my_zone: int) -> Dictionary:
	return current_opponent_team()["squad"][attacker_for_zone(my_zone)]


# ---------- Dificuldade e chances ----------

func difficulty_stage() -> int:
	if game_mode == GameMode.CHALLENGE:
		return challenge_wins + 1
	return campaign_stage


func _difficulty_bonus() -> int:
	if game_mode == GameMode.CHALLENGE:
		return challenge_wins * 2
	return 0


func ai_attack_strength() -> int:
	var p = ai_active_player()
	var stat = 0

	match ai_next_move:
		AIMove.PASS:
			stat = p["PAS"]
		AIMove.DRIBBLE:
			stat = p["DRI"]
		AIMove.LONG_SHOT:
			stat = p["SHO"] + 5
		AIMove.SHOT:
			stat = p["SHO"]

	return stat + (difficulty_stage() - 1) * 2


func chance_for(stat_name: String) -> int:
	var tb = 0
	var marker_stat = ""
	if stat_name == "DRI":
		tb = trait_bonus("DRI")
		marker_stat = "TAC"
	elif stat_name == "SHO":
		tb = trait_bonus("SHO")
		marker_stat = "BLQ"

	var marker = _opponent_marker_for(zone_idx)
	var difficulty = marker[marker_stat] + _difficulty_bonus()
	return Rules.success_chance(active_player()[stat_name], difficulty, momentum_bonus, tb)


func feint_chance() -> int:
	var stat_avg = (active_player()["DRI"] + active_player()["SHO"]) / 2.0
	var marker = _opponent_marker_for(zone_idx)
	var marker_avg = (marker["TAC"] + marker["BLQ"]) / 2.0
	var tb = trait_bonus("FEINT")
	return Rules.success_chance(stat_avg, marker_avg + 8 + _difficulty_bonus(), momentum_bonus, tb, 5, 90)


func long_shot_chance() -> int:
	var marker = _opponent_marker_for(zone_idx)
	var tb = trait_bonus("LONG_SHO")
	return Rules.success_chance(active_player()["SHO"], marker["BLQ"] + 20 + _difficulty_bonus(), momentum_bonus, tb, 5, 85)


func pass_chance_to(target_idx: int) -> int:
	var distance = abs(target_idx - zone_idx)
	var adjacent_bonus = 14 if distance == 1 else 0
	var distance_penalty = max(0, distance - 1) * 15
	var momentum_effect = (momentum_bonus * 1.5) if distance >= 2 else float(momentum_bonus)

	var marker = _opponent_marker_for(target_idx)
	var tb = trait_bonus("PASS")
	var effective_difficulty = marker["INT"] + distance_penalty - adjacent_bonus + _difficulty_bonus()
	return Rules.success_chance(active_player()["PAS"], effective_difficulty, momentum_effect, tb)


# ---------- Ações do jogador ----------

func attempt(action: String, target_idx: int = -1) -> void:
	if match_over:
		return
	if possession != Possession.PLAYER:
		return

	var passer = active_player()
	var target = {}

	if action == "PASS":
		if target_idx < 0 or target_idx >= squad.size() or target_idx == active_idx:
			return
		target = squad[target_idx]

	if action == "SHO":
		var succ_chance = chance_for("SHO")
		var success = randi_range(1,100) <= succ_chance

		if success:
			goals += 1
			streak += 1
			grant_xp(15)
			push_log(Narration.GOAL_CALL.pick_random())
			push_log(Narration.GOAL.pick_random() % [passer["name"], passer["role"]])
			SFX.play_goal()
			# SEMPRE reinicia no ZAG adversário
			SFX.play_goal()
			_kickoff(false)
			momentum_bonus = 0

		else:
			grant_xp(2)
			push_log(Narration.GOAL_FAIL.pick_random() % [passer["name"], passer["role"]])
			# SEMPRE reinicia no ZAG adversário
			_kickoff(false)
			momentum_bonus = 0

		momentum_bonus = 0

	elif action == "DRI":
		var succ_chance = chance_for("DRI")
		var success = randi_range(1,100) <= succ_chance

		if success:
			grant_xp(6)
			streak += 1

			push_log(
				Narration.DRIBBLE.pick_random() %
				[passer["name"], passer["role"]]
			)

			SFX.play_pass_success()

			# NÃO muda de zona.
			# Apenas melhora a jogada seguinte.

			momentum_bonus = 22

		else:
			grant_xp(1)

			push_log(
				Narration.DRIBBLE_FAIL.pick_random() %
				[passer["name"], passer["role"]]
			)

			SFX.play_turnover()

			_reset_possession("", zone_idx)

			momentum_bonus = 0
	elif action == "FEINT":
		var succ_chance = feint_chance()
		var success = randi_range(1, 100) <= succ_chance
		if success:
			grant_xp(9)
			streak += 1
			push_log(Narration.FEINT.pick_random() % [passer["name"], passer["role"]])
			SFX.play_pass_success()
			momentum_bonus = 30
		else:
			grant_xp(1)
			turnovers += 1
			SFX.play_turnover()
			# Finta errada é sempre perigosa: contra-ataque nasce onde a finta aconteceu.
			_reset_possession(Narration.FEINT_FAIL.pick_random() %[passer["name"], passer["role"]],zone_idx)
			momentum_bonus = 0

	elif action == "LONG_SHO":
		var succ_chance = long_shot_chance()
		var success = randi_range(1,100) <= succ_chance

		if success:
			goals += 1
			streak += 1
			grant_xp(20)
			push_log(Narration.GOAL_CALL.pick_random())
			push_log(Narration.LONG_GOAL.pick_random() % [passer["name"], passer["role"]])
			SFX.play_goal()
			# SEMPRE reinicia no ZAG adversário
			_kickoff(false)
			momentum_bonus = 0

		else:
			grant_xp(2)
			push_log(Narration.LONG_GOAL_FAIL.pick_random() % [passer["name"], passer["role"]])
			# SEMPRE reinicia no ZAG adversário
			_kickoff(false)
			momentum_bonus = 0

		momentum_bonus = 0

	else:  # PASS
		var succ_chance = pass_chance_to(target_idx)
		var success = randi_range(1, 100) <= succ_chance
		if success:
			grant_xp(4)
			streak += 1
			push_log(Narration.PASS_SUCCESS.pick_random() % [passer["name"], passer["role"], target["name"], target["role"]])
			SFX.play_pass_success()
			zone_idx = target_idx
			active_idx = target_idx
			momentum_bonus = 8
		else:
			grant_xp(1)
			# Passe interceptado: recuperado na zona de destino, não na de origem.
			_reset_possession(Narration.PASS_FAIL.pick_random() % [passer["name"], passer["role"], target["name"], target["role"]], target_idx)
			momentum_bonus = 0

	_advance_round()
	state_changed.emit()


func recover_possession(defender_idx: int) -> void:
	possession = Possession.PLAYER
	turn_state = TurnState.PLAYER_ATTACK

	active_idx = defender_idx
	zone_idx = defender_idx

	ai_zone_idx = 0
	ai_active_idx = 0
	ai_momentum = 0

	streak = 0
	momentum_bonus = 0

	var defender = squad[defender_idx]
	match defender["role"]:
		"ZAG":
			push_log(Narration.ZAG_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"VOL":
			push_log(Narration.VOL_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"MEI":
			push_log(Narration.MEI_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"CA":
			push_log(Narration.CA_RECOVERY.pick_random() % [defender["name"], defender["role"]])


func _kickoff(start_with_player: bool = true) -> void:

	if start_with_player:
		player_gets_ball()

		var p = active_player()
		push_log("Reinício de jogo. A posse da bola está com %s (%s)." %
			[p["name"], p["role"]])

	else:
		possession = Possession.AI
		turn_state = TurnState.PLAYER_DEFENSE

		ai_zone_idx = 0
		ai_active_idx = 0
		ai_momentum = 0

		var p = ai_active_player()
		push_log("Reinício de jogo. A posse da bola está com %s (%s)." %
			[p["name"], p["role"]])

		ai_turn()

	state_changed.emit()
	
func _advance_round() -> void:
	round_num += 1
	if round_num >= MAX_ROUNDS:
		match_over = true
		SFX.play_whistle()
		if goals > ai_goals:
			push_log("Vitória por %d × %d!" % [goals, ai_goals])
			if campaign_stage >= MAX_CAMPAIGN_STAGE:
				push_log("PARABÉNS! Você venceu a Grande Final e completou a Campanha!")
				push_log("Clique em 'Menu' ou 'Nova Partida' para recomeçar.")
			else:
				push_log("Clique em 'Próxima Partida' para continuar a campanha.")
		elif goals < ai_goals:
			push_log("Derrota por %d × %d." % [goals, ai_goals])
			push_log("Sua campanha terminou. Clique em 'Nova Partida' para recomeçar.")
		else:
			push_log("Empate em %d × %d." % [goals, ai_goals])
			push_log("Sua campanha terminou. Clique em 'Nova Partida' para recomeçar.")


# ---------- IA / defesa ----------

func ai_active_player_zone() -> int:
	return ai_zone_idx


func ai_gets_ball(player_zone: int = 0) -> void:
	possession = Possession.AI
	turn_state = TurnState.PLAYER_DEFENSE

	# jogador da IA que realmente ocupa esta coluna
	ai_zone_idx = attacker_for_zone(player_zone)
	ai_active_idx = ai_zone_idx
	ai_momentum = 0

	var starter = ai_active_player()

	match starter["role"]:
		"ZAG":
			push_log(Narration.ZAG_RECOVERY.pick_random() % [starter["name"], starter["role"]])
		"VOL":
			push_log(Narration.VOL_RECOVERY.pick_random() % [starter["name"], starter["role"]])
		"MEI":
			push_log(Narration.MEI_RECOVERY.pick_random() % [starter["name"], starter["role"]])
		"CA":
			push_log(Narration.CA_RECOVERY.pick_random() % [starter["name"], starter["role"]])
			
func ai_turn() -> void:
	if possession != Possession.AI:
		return

	turn_state = TurnState.PLAYER_DEFENSE
	_choose_ai_move()

	var p = ai_active_player()
	match ai_next_move:
		AIMove.PASS:
			push_log("%s (%s) procura um companheiro para o passe." % [p["name"], p["role"]])
		AIMove.DRIBBLE:
			push_log("%s (%s) parte para o drible!" % [p["name"], p["role"]])
		AIMove.LONG_SHOT:
			push_log("%s (%s) prepara um chute de longe!" % [p["name"], p["role"]])
		AIMove.SHOT:
			push_log("%s (%s) ficou cara a cara com o gol!" % [p["name"], p["role"]])

	state_changed.emit()


func _choose_ai_move() -> void:
	ai_active_idx = ai_zone_idx
	var player = ai_active_player()

	match player["role"]:
		"ZAG":
			ai_next_move = AIMove.PASS
		"VOL":
			ai_next_move = AIMove.PASS if randi() % 100 < 75 else AIMove.DRIBBLE
		"MEI":
			var r = randi() % 100
			if r < 35:
				ai_next_move = AIMove.PASS
			elif r < 80:
				ai_next_move = AIMove.DRIBBLE
			else:
				ai_next_move = AIMove.LONG_SHOT
		"CA":
			ai_next_move = AIMove.SHOT if ai_zone_idx >= 2 else AIMove.DRIBBLE


func _resolve_ai_shot(bonus: int = 0) -> void:
	var attack = ai_attack_strength() + ai_momentum

	var defender_idx = defender_for_attacker()
	var block_value = _defense_effectiveness("BLOCK", defender_idx)

	var diff = attack - block_value
	var chance = clampi(round(50 + diff * 0.6) + bonus, 8, 92)

	if randi_range(1,100) <= chance:
		ai_goals += 1
		var scorer = ai_active_player()
		push_log(Narration.GOAL_CALL.pick_random())
		push_log(Narration.GOAL.pick_random() %[scorer["name"], scorer["role"]])
		SFX.play_goal()

	else:
		grant_xp(3)
		push_log("Seu goleiro fez a defesa!")

	# SEMPRE reinicia no seu ZAG
	_kickoff(true)
	ai_momentum = 0


func _reset_possession(reason: String, ai_start_zone: int = 0) -> void:
	turnovers += 1
	if reason != "":
		push_log(reason)
	SFX.play_turnover()
	ai_gets_ball(ai_start_zone)
	ai_turn()


func defense_chance(action: String) -> int:
	var defender_idx = defender_for_attacker()
	var matches = _defense_matches_move(action, ai_next_move)
	var effectiveness = _defense_effectiveness(action, defender_idx)

	if not matches:
		effectiveness = int(effectiveness * 0.5)

	return clampi(round(50 + (effectiveness - ai_attack_strength()) * 0.6), 8, 92)


func defend(action: String) -> void:
	if turn_state != TurnState.PLAYER_DEFENSE:
		return

	var chance = defense_chance(action)
	var success = randi_range(1, 100) <= chance
	var defender_idx = defender_for_attacker()

	if success:
		push_log("Sua defesa (%s) funcionou! (%d%% de chance)" % [_defense_label(action), chance])
		recover_possession(defender_idx)
	else:
		push_log("A defesa (%s) não foi suficiente (%d%% de chance)." % [_defense_label(action), chance])
		_ai_move_succeeds()

	_advance_round()
	state_changed.emit()


func _defense_matches_move(defense_type: String, move) -> bool:
	match defense_type:
		"INTERCEPT":
			return move == AIMove.PASS
		"TACKLE":
			return move == AIMove.DRIBBLE
		"BLOCK":
			return move == AIMove.SHOT or move == AIMove.LONG_SHOT
	return false


func _defense_label(defense_type: String) -> String:
	match defense_type:
		"INTERCEPT": return "Interceptação"
		"TACKLE": return "Desarme"
		"BLOCK": return "Bloqueio"
	return defense_type


func _defense_effectiveness(defense_type: String, defender_idx: int) -> int:
	return _stat_for_defense(squad[defender_idx], defense_type)


func _stat_for_defense(player: Dictionary, defense_type: String) -> int:
	var base = 0
	match defense_type:
		"INTERCEPT":
			base = player["INT"]
		"TACKLE":
			base = player["TAC"]
		"BLOCK":
			base = player["BLQ"]
	return base + RosterData.trait_bonus(player, defense_type)


func _ai_move_succeeds() -> void:
	match ai_next_move:
		AIMove.PASS:
			var passer = ai_active_player()
			var next_zone = clampi(ai_zone_idx + 1, 0, ZONES.size() - 1)
			var receiver = current_opponent_team()["squad"][next_zone]

			ai_zone_idx = next_zone
			ai_active_idx = ai_zone_idx

			push_log("Passe de %s (%s) para %s (%s)." % [passer["name"], passer["role"], receiver["name"], receiver["role"]])
			ai_turn()

		AIMove.DRIBBLE:
			var dribbler = ai_active_player()
			push_log("%s (%s) passou pelo marcador." %[dribbler["name"],dribbler["role"]])
			ai_momentum += 20
			ai_turn()
			
		AIMove.LONG_SHOT, AIMove.SHOT:
			_resolve_ai_shot()


# ---------- XP / progressão ----------

func grant_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(xp_to_next * 1.35))
		for player in squad:
			match player["role"]:
				"ZAG":
					player["PAS"] = min(95, player["PAS"] + 1)
					player["DRI"] = min(95, player["DRI"] + 1)
					player["SHO"] = min(95, player["SHO"] + 1)
					player["INT"] = min(95, player["INT"] + 2)
					player["TAC"] = min(95, player["TAC"] + 2)
					player["BLQ"] = min(95, player["BLQ"] + 3)
				"VOL":
					player["PAS"] = min(95, player["PAS"] + 2)
					player["DRI"] = min(95, player["DRI"] + 2)
					player["SHO"] = min(95, player["SHO"] + 1)
					player["INT"] = min(95, player["INT"] + 2)
					player["TAC"] = min(95, player["TAC"] + 3)
					player["BLQ"] = min(95, player["BLQ"] + 1)
				"MEI":
					player["PAS"] = min(95, player["PAS"] + 3)
					player["DRI"] = min(95, player["DRI"] + 2)
					player["SHO"] = min(95, player["SHO"] + 2)
					player["INT"] = min(95, player["INT"] + 1)
					player["TAC"] = min(95, player["TAC"] + 1)
					player["BLQ"] = min(95, player["BLQ"] + 1)
				"CA":
					player["PAS"] = min(95, player["PAS"] + 1)
					player["DRI"] = min(95, player["DRI"] + 2)
					player["SHO"] = min(95, player["SHO"] + 3)
					player["INT"] = min(95, player["INT"] + 1)
					player["TAC"] = min(95, player["TAC"] + 1)
					player["BLQ"] = min(95, player["BLQ"] + 1)


func push_log(text: String) -> void:
	log_messages.push_front(text)
	if log_messages.size() > 6:
		log_messages.resize(6)


func _log_ai(text: String) -> void:
	push_log("(Adversário) %s" % text)


# ---------- Fluxo entre partidas ----------

func next_match() -> void:
	if not match_over or goals <= ai_goals:
		return
	if campaign_stage >= MAX_CAMPAIGN_STAGE:
		return

	campaign_stage += 1
	log_messages.clear()
	possession = Possession.PLAYER
	_kickoff()
	goals = 0
	ai_goals = 0
	turnovers = 0
	round_num = 0
	match_over = false
	momentum_bonus = 0

	push_log("Fase %d iniciada!" % campaign_stage)
	push_log("A bola está com o %s." % active_player()["name"])
	SFX.play_whistle()
	state_changed.emit()


func next_challenge_round() -> void:
	if not match_over or goals <= ai_goals:
		return

	challenge_wins += 1
	challenge_best = max(challenge_best, challenge_wins)
	log_messages.clear()
	possession = Possession.PLAYER

	_kickoff()
	goals = 0
	ai_goals = 0
	turnovers = 0
	round_num = 0
	match_over = false
	momentum_bonus = 0

	push_log("Sobrevivência: %d vitória(s) seguida(s)! O adversário fica mais forte." % challenge_wins)
	SFX.play_whistle()
	state_changed.emit()


func reset_game() -> void:
	level = 1
	xp = 0
	xp_to_next = 20
	starters = [0, 2, 4, 6]
	_apply_lineup()
	possession = Possession.PLAYER
	_kickoff()
	goals = 0
	ai_goals = 0
	turnovers = 0
	round_num = 0
	match_over = false
	momentum_bonus = 0
	campaign_stage = 1
	challenge_wins = 0
	log_messages = []
	push_log("Nova partida iniciada. A bola está com o %s." % active_player()["name"])
	state_changed.emit()
