extends Node
# Autoload (singleton) que orquestra o jogo: guarda o ESTADO da partida
# e o FLUXO (o que acontece quando o quê). Dados fixos do elenco vivem
# em RosterData.gd, fórmulas de chance em Rules.gd, decisões da IA e
# defesa em AIOpponent.gd, estatísticas de resumo em Stats.gd.

signal state_changed

const Narration = preload("res://scripts/Narration.gd")
const RosterData = preload("res://scripts/RosterData.gd")
const Rules = preload("res://scripts/Rules.gd")
const OpponentTeams = preload("res://scripts/OpponentTeams.gd")

const ZONES = ["Campo Próprio", "Meio-Campo", "Terço Final", "Grande Área"]
const MAX_CAMPAIGN_STAGE = 5
const MAX_ROUNDS = 30

var starters = [0, 2, 4, 6]
var squad = []

# Dicionário que armazena a stamina de cada jogador no elenco { roster_idx: float }
var player_stamina: Dictionary = {}

var zone_idx = 0
var active_idx = 0

var level = 1
var xp = 0
var pending_xp = 0 # 👈 XP acumulado na partida que só é aplicado ao final!
var xp_to_next = 20

var goals = 0
var ai_goals = 0
var turnovers = 0
var streak = 0

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

var ai_zone_idx = 0
var ai_active_idx = 0
var ai_momentum = 0


func _ready():
	init_stamina()
	_apply_lineup()
	push_log("Apito inicial. A bola está com o %s." % active_player()["name"])


# ---------- Elenco / Escalação e Stamina ----------

func init_stamina() -> void:
	player_stamina.clear()
	for i in range(RosterData.ROSTER.size()):
		player_stamina[i] = 100.0


func apply_match_fatigue() -> void:
	for i in range(RosterData.ROSTER.size()):
		if not player_stamina.has(i):
			player_stamina[i] = 100.0

		if i in starters:
			# Titulares gastam 20% de energia por partida
			player_stamina[i] = maxf(30.0, player_stamina[i] - 20.0)
		else:
			# Reservas recuperam 30% de energia descansando no banco
			player_stamina[i] = minf(100.0, player_stamina[i] + 30.0)


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
		var stamina_val = player_stamina.get(idx, 100.0)
		
		# Multiplicador de desempenho baseado no cansaço
		var stamina_mult = 1.0
		if stamina_val < 50.0:
			stamina_mult = 0.80 # -20% se tiver abaixo de 50% de stamina
		elif stamina_val < 75.0:
			stamina_mult = 0.90 # -10% se tiver abaixo de 75% de stamina
		
		p["PAS"] = min(95, int(round((p["PAS"] + 2 * growth_levels) * stamina_mult)))
		p["DRI"] = min(95, int(round((p["DRI"] + 2 * growth_levels) * stamina_mult)))
		p["SHO"] = min(95, int(round((p["SHO"] + 3 * growth_levels) * stamina_mult)))
		p["INT"] = min(95, int(round((p["INT"] + 2 * growth_levels) * stamina_mult)))
		p["TAC"] = min(95, int(round((p["TAC"] + 2 * growth_levels) * stamina_mult)))
		p["BLQ"] = min(95, int(round((p["BLQ"] + 2 * growth_levels) * stamina_mult)))
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


func opponent_player_at(zone: int) -> Dictionary:
	return current_opponent_team()["squad"][zone]


# ---------- Quem marca quem ----------

func attacker_for_zone(zone: int) -> int:
	return 3 - zone


func defender_for_attacker() -> int:
	return attacker_for_zone(ai_zone_idx)


func ai_active_column() -> int:
	return attacker_for_zone(ai_zone_idx)


func team_player_at_column(column: int, mine: bool) -> Dictionary:
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
	return AIOpponent.attack_strength()


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
		Stats.shots += 1
		var succ_chance = chance_for("SHO")
		var success = randi_range(1, 100) <= succ_chance

		if success:
			Stats.shots_on_target += 1
			goals += 1
			streak += 1
			grant_xp(15)
			push_log(Narration.GOAL_CALL.pick_random())
			push_log(Narration.GOAL.pick_random() % [passer["name"], passer["role"]])
			SFX.play_goal()
		else:
			grant_xp(2)
			push_log(Narration.GOAL_FAIL.pick_random() % [passer["name"], passer["role"]])

		_kickoff(false)
		momentum_bonus = 0

	elif action == "DRI":
		Stats.dribbles_attempted += 1
		var succ_chance = chance_for("DRI")
		var success = randi_range(1, 100) <= succ_chance

		if success:
			Stats.dribbles_completed += 1
			grant_xp(6)
			streak += 1
			push_log(Narration.DRIBBLE.pick_random() % [passer["name"], passer["role"]])
			SFX.play_dribble()
			momentum_bonus = 22
		else:
			grant_xp(1)
			push_log(Narration.DRIBBLE_FAIL.pick_random() % [passer["name"], passer["role"]])
			SFX.play_turnover()
			AIOpponent.reset_possession("", zone_idx)
			momentum_bonus = 0

	elif action == "FEINT":
		Stats.feints_attempted += 1
		var succ_chance = feint_chance()
		var success = randi_range(1, 100) <= succ_chance

		if success:
			Stats.feints_completed += 1
			grant_xp(9)
			streak += 1
			push_log(Narration.FEINT.pick_random() % [passer["name"], passer["role"]])
			SFX.play_pass_success()
			momentum_bonus = 30
		else:
			grant_xp(1)
			AIOpponent.reset_possession(Narration.FEINT_FAIL.pick_random() % [passer["name"], passer["role"]], zone_idx)
			momentum_bonus = 0

	elif action == "LONG_SHO":
		Stats.long_shots += 1
		var succ_chance = long_shot_chance()
		var success = randi_range(1, 100) <= succ_chance

		if success:
			Stats.long_shots_on_target += 1
			goals += 1
			streak += 1
			grant_xp(20)
			push_log(Narration.GOAL_CALL.pick_random())
			push_log(Narration.LONG_GOAL.pick_random() % [passer["name"], passer["role"]])
			SFX.play_goal()
		else:
			grant_xp(2)
			push_log(Narration.LONG_GOAL_FAIL.pick_random() % [passer["name"], passer["role"]])

		_kickoff(false)
		momentum_bonus = 0

	else: # PASS
		Stats.passes_attempted += 1
		var succ_chance = pass_chance_to(target_idx)
		var success = randi_range(1, 100) <= succ_chance

		if success:
			Stats.passes_completed += 1
			grant_xp(4)
			streak += 1
			push_log(Narration.PASS_SUCCESS.pick_random() % [passer["name"], passer["role"], target["name"], target["role"]])
			SFX.play_pass_success()
			zone_idx = target_idx
			active_idx = target_idx
			momentum_bonus = 8
		else:
			grant_xp(1)
			AIOpponent.reset_possession(Narration.PASS_FAIL.pick_random() % [passer["name"], passer["role"], target["name"], target["role"]], target_idx)
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
		"ZAG": push_log(Narration.ZAG_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"VOL": push_log(Narration.VOL_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"MEI": push_log(Narration.MEI_RECOVERY.pick_random() % [defender["name"], defender["role"]])
		"CA":  push_log(Narration.CA_RECOVERY.pick_random() % [defender["name"], defender["role"]])


func _kickoff(start_with_player: bool = true) -> void:
	if start_with_player:
		player_gets_ball()
		var p = active_player()
		push_log("Reinício de jogo. A posse da bola está com %s (%s)." % [p["name"], p["role"]])
	else:
		possession = Possession.AI
		turn_state = TurnState.PLAYER_DEFENSE
		ai_zone_idx = 0
		ai_active_idx = 0
		ai_momentum = 0
		var p = ai_active_player()
		push_log("Reinício de jogo. A posse da bola está com %s (%s)." % [p["name"], p["role"]])
		AIOpponent.take_turn()

	state_changed.emit()


func _advance_round() -> void:
	round_num += 1
	if round_num >= MAX_ROUNDS:
		match_over = true
		SFX.play_whistle()
		
		# Aplica o XP pendente da partida agora que o apito final foi dado!
		_process_pending_xp()
		
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


# ---------- IA / Defesa ----------

func ai_gets_ball(player_zone: int = 0) -> void:
	AIOpponent.gets_ball(player_zone)


func ai_turn() -> void:
	AIOpponent.take_turn()


func defense_chance(action: String) -> int:
	return AIOpponent.defense_chance(action)


func defend(action: String) -> void:
	AIOpponent.defend(action)
# Adicione esta sinalização para a UI reagir a eventos especiais
signal match_event_triggered(event_name: String, details: Dictionary)

# Adicione no atalho de erro de desarme ou tentativa de ação:
func trigger_foul_check(is_player: bool) -> bool:
	# 20% de chance de falta ao errar desarme agressivo
	if randf() < 0.20:
		var card_given = randf() < 0.35 # 35% de chance de ser Amarelo
		if card_given:
			push_log("🟨 CARTÃO AMARELO! Entrada dura no lance.")
			SFX.play_whistle()
			match_event_triggered.emit("YELLOW_CARD", {})
		else:
			push_log("⚠️ FALTA! O juiz paralisa a jogada.")
			SFX.play_whistle()
			match_event_triggered.emit("FOUL", {})
		return true
	return false

# ---------- XP / Progressão ----------

func grant_xp(amount: int) -> void:
	# Guarda o XP obtido durante a partida sem subir os atributos no meio do jogo
	Stats.xp_gained_match += amount
	pending_xp += amount


func _process_pending_xp() -> void:
	xp += pending_xp
	pending_xp = 0
	
	var initial_level = level
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(xp_to_next * 1.35))
		
	if level > initial_level:
		push_log("🎉 Seu time subiu para o Nível %d! Atributos evoluídos." % level)


func push_log(text: String) -> void:
	log_messages.push_front(text)
	if log_messages.size() > 6:
		log_messages.resize(6)


func reset_match_stats() -> void:
	Stats.reset()


func match_stats() -> Dictionary:
	return Stats.to_dict()


# ---------- Fluxo entre Partidas ----------

func next_match() -> void:
	if not match_over or goals <= ai_goals:
		return
	if campaign_stage >= MAX_CAMPAIGN_STAGE:
		return

	apply_match_fatigue()
	_apply_lineup() # 👈 Atualiza o squad já com os atributos evoluídos e cansaço aplicado

	campaign_stage += 1
	log_messages.clear()
	reset_match_stats()
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
	SaveSystem.save_game()
	state_changed.emit()


func next_challenge_round() -> void:
	if not match_over or goals <= ai_goals:
		return

	apply_match_fatigue()
	_apply_lineup()

	challenge_wins += 1
	challenge_best = max(challenge_best, challenge_wins)
	log_messages.clear()
	reset_match_stats()
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
	pending_xp = 0
	xp_to_next = 20
	starters = [0, 2, 4, 6]
	init_stamina()
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
	reset_match_stats()
	push_log("Nova partida iniciada. A bola está com o %s." % active_player()["name"])
	state_changed.emit()
