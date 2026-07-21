extends Node
# Autoload (singleton) que orquestra o jogo. Dados fixos do elenco viraram
# RosterData.gd e as fórmulas de chance viraram Rules.gd — esse arquivo
# agora só guarda o ESTADO (o que está acontecendo agora) e o FLUXO
# (o que acontece quando o quê).

signal state_changed

const Narration = preload("res://scripts/Narration.gd")
const RosterData = preload("res://scripts/RosterData.gd")
const Rules = preload("res://scripts/Rules.gd")
const OpponentTeams = preload("res://scripts/OpponentTeams.gd")

const ZONES = ["Campo Próprio", "Meio-Campo", "Terço Final", "Grande Área"]

const MAX_CAMPAIGN_STAGE = 5

# Índices do RosterData.ROSTER escalados como titulares, na mesma ordem de RosterData.ROLES.
var starters = [0, 2, 4, 6]

# squad é montado a partir do RosterData.ROSTER + starters — ver _apply_lineup().
# squad[0] = zona 0 (Campo Próprio), squad[1] = zona 1, etc.
var squad = []

# active_idx sempre é igual a zone_idx: o jogador com a bola É o dono da zona atual.
var zone_idx = 0
var active_idx = 0

var level = 1
var xp = 0
var xp_to_next = 20

var goals = 0
var ai_goals = 0
var turnovers = 0
var streak = 0

const MAX_ROUNDS = 15
var round_num = 0
var match_over = false

var campaign_stage = 1

# Modo Desafio: sobrevivência sem limite de fases — sobe a cada vitória.
var challenge_wins = 0
var challenge_best = 0  # recorde da sessão; não zera no "Nova Partida"

var momentum_bonus = 0

var log_messages = []

enum GameMode {
	CAMPAIGN,
	CHALLENGE
}
var game_mode = GameMode.CAMPAIGN

enum Possession {
	PLAYER,
	AI
}
var possession = Possession.PLAYER

enum TurnState {
	PLAYER_ATTACK,
	PLAYER_DEFENSE
}
var turn_state = TurnState.PLAYER_ATTACK

enum AIMove {
	PASS,
	DRIBBLE,
	LONG_SHOT,
	SHOT
}
var ai_next_move = AIMove.PASS

var ai_zone_idx = 0
var ai_active_idx = 0
var ai_momentum = 0


func _ready():
	_apply_lineup()
	push_log("Apito inicial. A bola está com o %s." % active_player()["name"])
	SFX.play_whistle()


# ---------- Elenco / escalação (delega dados pro RosterData) ----------

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
	# Monta o squad a partir do RosterData.ROSTER, aplicando o crescimento
	# por nível que o time já acumulou — trocar o titular não zera a
	# evolução do time.
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
	return current_opponent_team()["squad"][ai_active_idx]


# ---------- Dificuldade e chances (delega contas pro Rules) ----------

func difficulty_stage() -> int:
	# No Desafio, a dificuldade sobe com as vitórias em sequência, sem teto.
	# Na Campanha, sobe com a fase (que tem teto em MAX_CAMPAIGN_STAGE).
	if game_mode == GameMode.CHALLENGE:
		return challenge_wins + 1
	return campaign_stage


func opponent_difficulty_for(zone: int) -> int:
	return Rules.opponent_difficulty_for(zone, level, difficulty_stage())


func opponent_difficulty() -> int:
	return opponent_difficulty_for(zone_idx)


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
	if stat_name == "DRI":
		tb = trait_bonus("DRI")
	elif stat_name == "SHO":
		tb = trait_bonus("SHO")
	return Rules.success_chance(active_player()[stat_name], opponent_difficulty(), momentum_bonus, tb)


func feint_chance() -> int:
	# Finta: mistura Drible e Chute. Base mais dura que o drible normal
	# (por isso soma 8 na dificuldade), mas o prêmio (momentum) é maior.
	var stat_avg = (active_player()["DRI"] + active_player()["SHO"]) / 2.0
	var tb = trait_bonus("FEINT")
	return Rules.success_chance(stat_avg, opponent_difficulty() + 8, momentum_bonus, tb, 5, 90)


func long_shot_chance() -> int:
	# Só faz sentido na Terço Final; soma 20 na dificuldade pela distância do gol.
	var tb = trait_bonus("LONG_SHO")
	return Rules.success_chance(active_player()["SHO"], opponent_difficulty() + 20, momentum_bonus, tb, 5, 85)


func pass_chance_to(target_idx: int) -> int:
	var distance = abs(target_idx - zone_idx)
	var adjacent_bonus = 14 if distance == 1 else 0
	var distance_penalty = max(0, distance - 1) * 15
	var momentum_effect = (momentum_bonus * 1.5) if distance >= 2 else float(momentum_bonus)
	var target_difficulty = opponent_difficulty_for(target_idx)
	var tb = trait_bonus("PASS")

	# distance_penalty/adjacent_bonus entram como parte da "dificuldade efetiva"
	var effective_difficulty = target_difficulty + distance_penalty - adjacent_bonus
	return Rules.success_chance(active_player()["PAS"], effective_difficulty, momentum_effect, tb)


# ---------- Ações do jogador ----------

func attempt(action: String, target_idx: int = -1) -> void:
	if match_over:
		return

	if possession != Possession.PLAYER:
		return

	var passer_name = active_player()["name"]
	var target_name = ""

	if action == "PASS":
		if target_idx < 0 or target_idx >= squad.size() or target_idx == active_idx:
			return
		target_name = squad[target_idx]["name"]

	if action == "SHO":
		var succ_chance = chance_for("SHO")
		var success = randi_range(1, 100) <= succ_chance
		if success:
			goals += 1
			streak += 1
			grant_xp(15)
			push_log(Narration.GOAL.pick_random() % [passer_name])
			SFX.play_goal()
			_kickoff()
			ai_turn()
		else:
			grant_xp(2)
			_reset_possession("Chute de %s travado (%d%% de chance)." % [passer_name, succ_chance])
		momentum_bonus = 0

	elif action == "DRI":
		var succ_chance = chance_for("DRI")
		var success = randi_range(1, 100) <= succ_chance
		if success:
			grant_xp(6)
			streak += 1
			push_log(Narration.DRIBBLE.pick_random() % [passer_name])
			SFX.play_pass_success()
			momentum_bonus = 22
		else:
			grant_xp(1)
			_reset_possession("%s perdeu a bola no drible (%d%% de chance)." % [passer_name, succ_chance])
			momentum_bonus = 0

	elif action == "FEINT":
		var succ_chance = feint_chance()
		var success = randi_range(1, 100) <= succ_chance
		if success:
			grant_xp(9)
			streak += 1
			push_log(Narration.FEINT.pick_random() % [passer_name])
			SFX.play_pass_success()
			momentum_bonus = 30
		else:
			grant_xp(1)
			_kickoff()
			turnovers += 1
			push_log("A finta de %s não enganou ninguém — bola perdida na hora! (%d%% de chance)." % [passer_name, succ_chance])
			SFX.play_turnover()
			_resolve_ai_shot()
			momentum_bonus = 0

	elif action == "LONG_SHO":
		var succ_chance = long_shot_chance()
		var success = randi_range(1, 100) <= succ_chance
		if success:
			goals += 1
			streak += 1
			grant_xp(20)
			push_log(Narration.LONG_GOAL.pick_random() % [passer_name])
			SFX.play_goal()
			_kickoff()
			ai_turn()
		else:
			grant_xp(2)
			_reset_possession("Chute de longe de %s foi pra fora (%d%% de chance)." % [passer_name, succ_chance])
		momentum_bonus = 0

	else:  # PASS
		var succ_chance = pass_chance_to(target_idx)
		var success = randi_range(1, 100) <= succ_chance
		if success:
			grant_xp(4)
			streak += 1
			push_log(Narration.PASS_SUCCESS.pick_random() % [passer_name, target_name])
			SFX.play_pass_success()
			zone_idx = target_idx
			active_idx = target_idx
			momentum_bonus = 8
		else:
			grant_xp(1)
			_reset_possession(Narration.PASS_FAIL.pick_random() % [passer_name, target_name])
			momentum_bonus = 0

	_advance_round()
	state_changed.emit()

func defender_for_attacker() -> int:

	match current_opponent_team()["squad"][ai_active_idx]["role"]:

		"ZAG":
			return 3

		"VOL":
			return 2

		"MEI":
			return 1

		"CA":
			return 0

	return 0

func recover_possession(defender_idx:int):

	possession = Possession.PLAYER
	turn_state = TurnState.PLAYER_ATTACK

	active_idx = defender_idx
	zone_idx = defender_idx

	ai_zone_idx = 0
	ai_active_idx = 0
	ai_momentum = 0

	streak = 0
	momentum_bonus = 0

	match squad[defender_idx]["role"]:
		"ZAG":
			push_log(Narration.ZAG_RECOVERY.pick_random() % squad[defender_idx]["name"])
		"VOL":
			push_log(Narration.VOL_RECOVERY.pick_random() % squad[defender_idx]["name"])
		"MEI":
			push_log(Narration.MEI_RECOVERY.pick_random() % squad[defender_idx]["name"])
		"CA":
			push_log(Narration.CA_RECOVERY.pick_random() % squad[defender_idx]["name"])


func _kickoff():
	player_gets_ball()


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


func ai_gets_ball() -> void:
	possession = Possession.AI
	turn_state = TurnState.PLAYER_DEFENSE

	ai_zone_idx = 0
	ai_active_idx = 0
	ai_momentum = 0

	push_log("O adversário iniciou o ataque.")


func ai_turn() -> void:
	if possession != Possession.AI:
		return

	turn_state = TurnState.PLAYER_DEFENSE
	_choose_ai_move()

	match ai_next_move:
		AIMove.PASS:
			push_log("O adversário procura um companheiro para o passe.")
		AIMove.DRIBBLE:
			push_log("O atacante parte para o drible!")
		AIMove.LONG_SHOT:
			push_log("O adversário prepara um chute de longe!")
		AIMove.SHOT:
			push_log("O atacante ficou cara a cara com o gol!")

	state_changed.emit()


func _choose_ai_move() -> void:

	ai_active_idx = ai_zone_idx
	var player = ai_active_player()

	match player["role"]:

		"ZAG":
			ai_next_move = AIMove.PASS

		"VOL":
			if randi() % 100 < 75:
				ai_next_move = AIMove.PASS
			else:
				ai_next_move = AIMove.DRIBBLE

		"MEI":
			var r = randi() % 100

			if r < 35:
				ai_next_move = AIMove.PASS
			elif r < 80:
				ai_next_move = AIMove.DRIBBLE
			else:
				ai_next_move = AIMove.LONG_SHOT

		"CA":
			if ai_zone_idx >= 2:
				ai_next_move = AIMove.SHOT
			else:
				ai_next_move = AIMove.DRIBBLE


func _resolve_ai_shot(bonus: int = 0) -> void:
	var attack = ai_attack_strength()

	var defender_idx = defender_for_attacker()
	var block_value = _defense_effectiveness("BLOCK", defender_idx)

	var diff = attack - block_value
	var chance = clampi(round(50 + diff * 0.6) + bonus, 8, 92)

	if randi_range(1, 100) <= chance:
		ai_goals += 1
		push_log("Contra-ataque! O adversário marcou (%d%% de chance)." % chance)
		SFX.play_turnover()
		_kickoff()
	else:
		grant_xp(3)
		recover_possession(defender_idx)


func _reset_possession(reason: String) -> void:
	turnovers += 1
	push_log(reason)
	SFX.play_turnover()
	ai_gets_ball()
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


func _defense_effectiveness(defense_type:String, defender_idx:int) -> int:
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

		AIMove.PASS, AIMove.DRIBBLE:
			ai_zone_idx += 1
			ai_active_idx = ai_zone_idx
			push_log("%s avançou com a jogada." % ai_active_player()["name"])
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


# ---------- Fluxo entre partidas ----------

func next_match() -> void:
	if not match_over or goals <= ai_goals:
		return

	# TRAVA DE SEGURANÇA: impede o avanço além da fase 5
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
