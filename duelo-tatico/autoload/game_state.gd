extends Node
# Autoload (singleton) que guarda o estado do jogo inteiro.

signal state_changed

const Narration = preload("res://scripts/Narration.gd")

const ZONES = ["Campo Próprio", "Meio-Campo", "Terço Final", "Grande Área"]

const ROLES = ["ZAG", "VOL", "MEI", "CA"]

const MAX_CAMPAIGN_STAGE = 5
# Elenco completo: 2 candidatos por posição, cada um com um perfil diferente.
var roster = [
	{
		"name": "Rocha",
		"role": "ZAG",
		"trait": "PAREDE",
		"PAS": 55,
		"DRI": 40,
		"SHO": 25,
		"DEF": 65
	},
	{
		"name": "Muralha",
		"role": "ZAG",
		"trait": "INTERCEPTADOR",
		"PAS": 42,
		"DRI": 30,
		"SHO": 18,
		"DEF": 78
	},
	{
		"name": "Diego",
		"role": "VOL",
		"trait": "LADRÃO_DE_BOLA",
		"PAS": 62,
		"DRI": 50,
		"SHO": 35,
		"DEF": 55
	},
	{
		"name": "Kauê",
		"role": "VOL",
		"trait": "INCANSÁVEL",
		"PAS": 52,
		"DRI": 45,
		"SHO": 28,
		"DEF": 68
	},
	{
		"name": "Armando",
		"role": "MEI",
		"trait": "DRIBLADOR",
		"PAS": 58,
		"DRI": 60,
		"SHO": 48,
		"DEF": 35
	},
	{
		"name": "Rafinha",
		"role": "MEI",
		"trait": "ARMADOR",
		"PAS": 70,
		"DRI": 52,
		"SHO": 38,
		"DEF": 25
	},
	{
		"name": "Nunes",
		"role": "CA",
		"trait": "FINALIZADOR",
		"PAS": 40,
		"DRI": 50,
		"SHO": 65,
		"DEF": 25
	},
	{
		"name": "Fominha",
		"role": "CA",
		"trait": "ATIRADOR",
		"PAS": 28,
		"DRI": 38,
		"SHO": 78,
		"DEF": 12
	},
]

# Índices do roster escalados como titulares, na mesma ordem de ROLES.
var starters = [0, 2, 4, 6]

# squad é montado a partir do roster + starters — ver _apply_lineup().
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

func _ready():
	_apply_lineup()
	push_log("Apito inicial. A bola está com o %s." % active_player()["name"])
	SFX.play_whistle()


func candidates_for(role_idx: int) -> Array:
	# Retorna os índices do roster que jogam na posição de ROLES[role_idx].
	var role = ROLES[role_idx]
	var result = []
	for i in range(roster.size()):
		if roster[i]["role"] == role:
			result.append(i)
	return result


func set_lineup(new_starters: Array) -> void:
	if new_starters.size() != ROLES.size():
		return
	starters = new_starters.duplicate()
	_apply_lineup()
	state_changed.emit()


func _apply_lineup() -> void:
	# Monta o squad a partir do roster, aplicando o crescimento por nível
	# que o time já acumulou — trocar o titular não zera a evolução do time.
	var growth_levels = level - 1
	squad = []
	for idx in starters:
		var p = roster[idx].duplicate()
		p["PAS"] = min(95, p["PAS"] + 2 * growth_levels)
		p["DRI"] = min(95, p["DRI"] + 2 * growth_levels)
		p["SHO"] = min(95, p["SHO"] + 3 * growth_levels)
		p["DEF"] = min(95, p["DEF"] + 2 * growth_levels)
		squad.append(p)


func active_player() -> Dictionary:
	return squad[active_idx]


func trait_name(trait_id: String) -> String:
	match trait_id:
		"PAREDE":
			return "Parede (+Defesa)"
		"INTERCEPTADOR":
			return "Interceptador (+Recuperação)"
		"LADRÃO_DE_BOLA":
			return "Ladrão de Bola (+Recuperação)"
		"INCANSÁVEL":
			return "Incansável (Pressão pós-perda)"
		"ARMADOR":
			return "Armador (+Passe)"
		"DRIBLADOR":
			return "Driblador (+Drible/Finta)"
		"FINALIZADOR":
			return "Finalizador (+Chute)"
		"ATIRADOR":
			return "Atirador (+Chute de Longe)"
		_:
			return trait_id


func trait_bonus(action: String) -> int:
	var player_trait = active_player()["trait"]

	match player_trait:
		"ARMADOR":
			if action == "PASS":
				return 8

		"DRIBLADOR":
			if action == "DRI" or action == "FEINT":
				return 8

		"FINALIZADOR":
			if action == "SHO":
				return 8

		"ATIRADOR":
			if action == "LONG_SHO":
				return 10

	return 0


func difficulty_stage() -> int:
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		return challenge_wins + 1
	return campaign_stage


func opponent_difficulty_for(zone: int) -> int:
	var base_by_zone = [25, 35, 45, 55]
	var value = base_by_zone[zone] + int(level * 1.0) + (difficulty_stage() - 1) * 4
	return min(92, value)


func opponent_difficulty() -> int:
	return opponent_difficulty_for(zone_idx)


func ai_attack_strength() -> int:
	return min(88, 25 + int(level * 0.8) + (difficulty_stage() - 1) * 3)


func chance_for(stat_name: String) -> int:
	var diff = active_player()[stat_name] - opponent_difficulty() + momentum_bonus

	if stat_name == "DRI":
		diff += trait_bonus("DRI")
	elif stat_name == "SHO":
		diff += trait_bonus("SHO")

	var pct = 50 + diff * 0.6
	return clampi(round(pct), 8, 92)


func feint_chance() -> int:
	# Finta: mistura Drible e Chute (habilidade + confiança pra ir pra cima do marcador).
	# Base mais dura que o drible normal, mas o prêmio (momentum) é bem maior.
	var stat_avg = (active_player()["DRI"] + active_player()["SHO"]) / 2.0
	var diff = stat_avg - opponent_difficulty() - 8 + momentum_bonus
	diff += trait_bonus("FEINT")
	var pct = 50 + diff * 0.6
	return clampi(round(pct), 5, 90)


func long_shot_chance() -> int:
	# Chute de longe: só faz sentido na Terço Final, com penalidade fixa pela distância do gol.
	var diff = active_player()["SHO"] - opponent_difficulty() - 20 + momentum_bonus
	diff += trait_bonus("LONG_SHO")
	var pct = 50 + diff * 0.6
	return clampi(round(pct), 5, 85)


func pass_chance_to(target_idx: int) -> int:
	var distance = abs(target_idx - zone_idx)

	var adjacent_bonus = 14 if distance == 1 else 0
	var distance_penalty = max(0, distance - 1) * 15
	var momentum_effect = (momentum_bonus * 1.5) if distance >= 2 else float(momentum_bonus)

	var target_difficulty = opponent_difficulty_for(target_idx)

	var diff = active_player()["PAS"] - target_difficulty
	diff -= distance_penalty
	diff += adjacent_bonus
	diff += momentum_effect
	diff += trait_bonus("PASS")

	var pct = 50 + diff * 0.6
	return clampi(round(pct), 8, 92)


func attempt(action: String, target_idx: int = -1) -> void:
	if match_over:
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

			# GOAL espera 1 argumento (%s do autor do gol)
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

			# DRIBBLE espera 1 argumento (%s do driblador)
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

			# FEINT espera 1 argumento (%s do driblador)
			push_log(Narration.FEINT.pick_random() % [passer_name])
			SFX.play_pass_success()

			momentum_bonus = 30
		else:
			grant_xp(1)
			_kickoff()
			turnovers += 1
			push_log("A finta de %s não enganou ninguém — bola perdida na hora! (%d%% de chance)." % [passer_name, succ_chance])
			SFX.play_turnover()
			_resolve_ai_shot()  # finta errada é sempre perigosa, sem chance de "escapar"
			momentum_bonus = 0

	elif action == "LONG_SHO":
		var succ_chance = long_shot_chance()
		var success = randi_range(1, 100) <= succ_chance
		if success:
			goals += 1
			streak += 1
			grant_xp(20)

			# LONG_GOAL espera 1 argumento (%s do autor do gol)
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

			# PASS_SUCCESS espera 2 argumentos (autor e receptor)
			push_log(Narration.PASS_SUCCESS.pick_random() % [passer_name, target_name])
			SFX.play_pass_success()

			zone_idx = target_idx
			active_idx = target_idx
			momentum_bonus = 8
		else:
			grant_xp(1)

			# PASS_FAIL espera 2 argumentos (autor e receptor pretendido)
			_reset_possession(Narration.PASS_FAIL.pick_random() % [passer_name, target_name])

			momentum_bonus = 0

	_advance_round()
	state_changed.emit()


func recover_possession() -> void:
	var zag_def = squad[0]["DEF"]
	var vol_def = squad[1]["DEF"]

	if squad[0]["trait"] == "INTERCEPTADOR":
		zag_def += 12

	if squad[1]["trait"] == "LADRÃO_DE_BOLA":
		vol_def += 12

	var total = zag_def + vol_def
	var roll = randi_range(1, total)

	if roll <= zag_def:
		# Zagueiro recuperou (ZAG_RECOVERY espera 1 argumento)
		zone_idx = 0
		active_idx = 0
		push_log(Narration.ZAG_RECOVERY.pick_random() % [squad[0]["name"]])
	else:
		# Volante recuperou (VOL_RECOVERY espera 1 argumento)
		zone_idx = 1
		active_idx = 1
		push_log(Narration.VOL_RECOVERY.pick_random() % [squad[1]["name"]])

	streak = 0


func _kickoff():
	zone_idx = 0
	active_idx = 0
	streak = 0
	momentum_bonus = 0


func _advance_round() -> void:
	round_num += 1
	if round_num >= MAX_ROUNDS:
		match_over = true
		SFX.play_whistle()
		if goals > ai_goals:
			push_log("Vitória por %d × %d!" % [goals, ai_goals])
			push_log("Clique em 'Próxima Partida' para continuar a campanha.")
		elif goals < ai_goals:
			push_log("Derrota por %d × %d." % [goals, ai_goals])
			push_log("Sua campanha terminou. Clique em 'Novo Jogo' para recomeçar.")
		else:
			push_log("Empate em %d × %d." % [goals, ai_goals])
			push_log("Sua campanha terminou. Clique em 'Novo Jogo' para recomeçar.")


func ai_turn() -> void:
	var breakaway_chance = 25

	if randi_range(1, 100) > breakaway_chance:
		recover_possession()
		return

	_resolve_ai_shot()


func _resolve_ai_shot() -> void:
	var attack = ai_attack_strength()

	# Zag e Volante podem defender
	var zag = squad[0]["DEF"]
	if squad[0]["trait"] == "PAREDE":
		zag += 8
	var vol = squad[1]["DEF"]
	if squad[1]["trait"] == "LADRÃO_DE_BOLA":
		vol += 5
	var def_value = round(zag * 0.7 + vol * 0.3)

	var diff = attack - def_value
	var chance = clampi(round(50 + diff * 0.6), 8, 92)

	if randi_range(1, 100) <= chance:
		ai_goals += 1
		push_log("Contra-ataque! O adversário marcou (%d%% de chance)." % chance)
		SFX.play_turnover()
	else:
		grant_xp(3)
		push_log("%s e %s seguraram o contra-ataque (%d%% de chance)." %
		[
			squad[0]["name"],
			squad[1]["name"],
			chance
		])

		recover_possession()


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
					player["DEF"] = min(95, player["DEF"] + 3)

				"VOL":
					player["PAS"] = min(95, player["PAS"] + 2)
					player["DRI"] = min(95, player["DRI"] + 2)
					player["SHO"] = min(95, player["SHO"] + 1)
					player["DEF"] = min(95, player["DEF"] + 2)

				"MEI":
					player["PAS"] = min(95, player["PAS"] + 3)
					player["DRI"] = min(95, player["DRI"] + 2)
					player["SHO"] = min(95, player["SHO"] + 2)
					player["DEF"] = min(95, player["DEF"] + 1)

				"CA":
					player["PAS"] = min(95, player["PAS"] + 1)
					player["DRI"] = min(95, player["DRI"] + 2)
					player["SHO"] = min(95, player["SHO"] + 3)
					player["DEF"] = min(95, player["DEF"] + 1)


func _reset_possession(reason: String) -> void:
	_kickoff()
	turnovers += 1
	push_log(reason)
	SFX.play_turnover()
	ai_turn()


func push_log(text: String) -> void:
	log_messages.push_front(text)
	if log_messages.size() > 6:
		log_messages.resize(6)


func next_match() -> void:
	if not match_over or goals <= ai_goals:
		return

	campaign_stage += 1
	log_messages.clear()

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
	# Sem teto: continua enquanto você vencer. Quebra a sequência só na derrota/empate.
	if not match_over or goals <= ai_goals:
		return

	challenge_wins += 1
	challenge_best = max(challenge_best, challenge_wins)
	log_messages.clear()

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
	_kickoff()
	goals = 0
	ai_goals = 0
	turnovers = 0
	round_num = 0
	match_over = false
	momentum_bonus = 0
	campaign_stage = 1
	challenge_wins = 0  # o recorde (challenge_best) continua — é o high score da sessão
	log_messages = []
	push_log("Novo jogo. A bola está com o %s." % active_player()["name"])
	state_changed.emit()
