extends Node
# GameState.gd — Autoload (Singleton) Central de Estado

signal state_changed
signal match_event_triggered(event_name: String, details: Dictionary)

const OpponentTeams = preload("res://scripts/OpponentTeams.gd")
const MatchFlow = preload("res://scripts/MatchFlow.gd")

# ---------- ENUMS GLOBAIS ----------
enum Possession { PLAYER, AI }
enum TurnState { PLAYER_ATTACK, PLAYER_DEFENSE }
enum GameMode { CAMPAIGN, CHALLENGE }
enum AIMove { PASS, DRIBBLE, LONG_SHOT, SHOT }

# ---------- 1. ESTADO ----------
const ZONES = ["Campo Próprio", "Meio-Campo", "Terço Final", "Grande Área"]
const MAX_CAMPAIGN_STAGE = 5
const MAX_ROUNDS = 30

var first_half: bool = true
var yellow_cards: Dictionary = {}
var game_mode: GameMode = GameMode.CAMPAIGN

var goals: int = 0
var ai_goals: int = 0
var turnovers: int = 0
var streak: int = 0
var round_num: int = 0
var match_over: bool = false
var campaign_stage: int = 1
var challenge_wins: int = 0
var challenge_best: int = 0

# ---------- 2. LINEUP ----------
var starters: Array = [0, 2, 4, 6]
var squad: Array = []
var player_stamina: Dictionary = {}
var substitutions_left: int = 2
var players_out: Array = []

# ---------- 3. POSSE & TURNO ----------
var possession: Possession = Possession.PLAYER
var turn_state: TurnState = TurnState.PLAYER_ATTACK

var zone_idx: int = 0
var active_idx: int = 0
var momentum_bonus: int = 0

# ---------- 4. IA ----------
var ai_next_move: AIMove = AIMove.PASS
var ai_zone_idx: int = 0
var ai_active_idx: int = 0
var ai_momentum: int = 0

# ---------- 5. XP ----------
var level: int = 1
var xp: int = 0
var pending_xp: int = 0
var xp_to_next: int = 20

# ---------- 6. LOGS ----------
var log_messages: Array = []


func _ready() -> void:
	init_stamina()
	_apply_lineup()


# ==============================================================================
# 1. ESTADO
# ==============================================================================

func emit_match_event(event_name: String, details: Dictionary = {}) -> void:
	match_event_triggered.emit(event_name, details)

func difficulty_stage() -> int:
	if game_mode == GameMode.CHALLENGE:
		return challenge_wins + 1
	return campaign_stage

func _difficulty_bonus() -> int:
	if game_mode == GameMode.CHALLENGE:
		return challenge_wins * 2
	return 0

func reset_match_stats() -> void:
	Stats.reset()

func match_stats() -> Dictionary:
	return Stats.to_dict()


# ==============================================================================
# 2. LINEUP
# ==============================================================================

func consume_round_stamina() -> void:
	LineupManager.consume_round_stamina(self)

func consume_action_stamina(roster_idx: int, action: String, success: bool, is_defense: bool = false) -> void:
	LineupManager.consume_action_stamina(self, roster_idx, action, success, is_defense)
	
func init_stamina() -> void:
	LineupManager.init_stamina(player_stamina)

func get_stamina(roster_idx: int) -> float:
	return player_stamina.get(roster_idx, 100.0)

func set_stamina(roster_idx: int, amount: float) -> void:
	player_stamina[roster_idx] = clampf(amount, 0.0, 100.0)
	
func reset_all_stamina() -> void:
	LineupManager.reset_all_stamina(player_stamina)

func reset_substitutions() -> void:
	substitutions_left = 2
	players_out.clear()
	yellow_cards.clear()

func can_substitute() -> bool:
	return substitutions_left > 0

func make_substitution(role_idx: int, new_roster_idx: int) -> bool:
	return LineupManager.make_substitution(self, role_idx, new_roster_idx)
	
func apply_match_fatigue() -> void:
	LineupManager.apply_match_fatigue(player_stamina, starters)

func set_starter(role_idx: int, roster_idx: int) -> void:
	if role_idx >= 0 and role_idx < starters.size():
		starters[role_idx] = roster_idx
		_apply_lineup()
		state_changed.emit()

func set_lineup(new_starters: Array) -> void:
	if new_starters.size() != RosterData.ROLES.size():
		return
	starters = new_starters.duplicate()
	_apply_lineup()
	state_changed.emit()

func _apply_lineup() -> void:
	squad = LineupManager.apply_lineup(self)

func active_player() -> Dictionary:
	var safe_idx = clampi(active_idx, 0, max(0, squad.size() - 1))
	return squad[safe_idx] if not squad.is_empty() else {}

# Retorna o jogador do usuário responsável por defender a IA atacante
func active_defender() -> Dictionary:
	var def_dict = Matchups.player_defender_for_ai(self, ai_active_player())
	
	# Caso o marcador dessa zona esteja expulso, redireciona a defesa para o primeiro ativo
	if def_dict.get("is_ejected", false):
		for p in squad:
			if not p.get("is_ejected", false):
				return p
				
	return def_dict

func candidates_for(role_idx: int) -> Array:
	return RosterData.candidates_for(role_idx)

func trait_name(trait_id: String) -> String:
	return RosterData.trait_name(trait_id)

func trait_bonus(action: String) -> int:
	return RosterData.trait_bonus(active_player(), action)


# ==============================================================================
# 3. POSSE
# ==============================================================================

func player_gets_ball() -> void:
	MatchEngine.player_gets_ball(self)
	
	# Se a posse caiu no jogador expulso, passa a bola para o companheiro ativo
	if active_player().get("is_ejected", false):
		for i in range(squad.size()):
			if not squad[i].get("is_ejected", false):
				active_idx = i
				zone_idx = i
				break

func recover_possession(defender_idx: int) -> void:
	MatchEngine.recover_possession(self, defender_idx)


# ==============================================================================
# 4. IA & DEFESA
# ==============================================================================

func current_opponent_team() -> Dictionary:
	if game_mode == GameMode.CHALLENGE:
		return OpponentTeams.team_for_challenge(challenge_wins)
	return OpponentTeams.team_for_stage(campaign_stage)

func opponent_team_name() -> String:
	return current_opponent_team().get("name", "Adversário")

func ai_active_player() -> Dictionary:
	var opp_squad = current_opponent_team().get("squad", [])
	var safe_idx = clampi(ai_active_idx, 0, max(0, opp_squad.size() - 1))
	return opp_squad[safe_idx]

func _opponent_marker_for(_zone_unused: int) -> Dictionary:
	return Matchups.opponent_marker_for_player(self, active_player())

func opponent_marker_for_player_dict(p_dict: Dictionary) -> Dictionary:
	return Matchups.opponent_marker_for_player(self, p_dict)

func defender_for_attacker() -> int:
	var def_dict = active_defender()
	return Matchups.player_slot_for_role(self, def_dict.get("role", "ZAG"))

func ai_gets_ball(player_zone: int = 3) -> void:
	AIOpponent.gets_ball(player_zone)

func ai_turn() -> void:
	AIOpponent.take_turn()

func defense_chance(action: String) -> int:
	# Todas as ações defensivas (inclusive o Carrinho) usam os atributos via AIOpponent
	return AIOpponent.defense_chance(action)

func defend(action: String) -> void:
	if turn_state != TurnState.PLAYER_DEFENSE or match_over:
		return

	var def_player = active_defender()
	var def_slot = defender_for_attacker()
	var def_roster_idx = starters[def_slot] if def_slot < starters.size() else starters[0]
	var att_player = ai_active_player()
	var def_role = def_player.get("role", "")

	# 🛡 RESTRIÇÃO DO BLOQUEIO: Bloqueio só é permitido para ZAG e VOL
	if action == "BLOCK" and not (def_role in ["ZAG", "VOL"]):
		push_log("⚠️ Bloqueio de chute só pode ser feito por Volantes e Zagueiros!")
		return

	var success_chance = defense_chance(action)
	var success = randf() * 100.0 < success_chance

	consume_action_stamina(def_roster_idx, action, success, true)

	if success:
		if action == "SLIDE":
			push_log("🦵 CARRINHO PERFEITO! %s limpa a jogada e toma a bola!" % def_player.get("name", "Jogador"))
			Stats.tackle()
			Stats.interception()
			SFX.play_tackle()
		elif action == "INTERCEPT":
			push_log("🛡 Interceptação bem sucedida por %s!" % def_player.get("name", "Jogador"))
			Stats.interception()
			SFX.play_intercept()
		elif action == "TACKLE":
			push_log("🛡 Desarme bem sucedido por %s!" % def_player.get("name", "Jogador"))
			Stats.tackle()
			SFX.play_tackle()
		elif action == "BLOCK":
			push_log("🛡 Bloqueio de chute bem sucedido por %s!" % def_player.get("name", "Jogador"))
			Stats.block()
			SFX.play_block()
		
		recover_possession(def_slot)
		turnovers += 1
		Stats.add_turnover()
		emit_match_event("DEFENSE_SUCCESS", {"action": action})
		
		MatchEngine.advance_round(self)
	else:
		var diff = att_player.get("DRI", 50) - def_player.get("TAC", 50)
		var foul_info = Referee.check_foul(self, action, diff)

		if foul_info.get("is_foul", false):
			push_log("⚠️ Falta de %s (%s) em %s (%s)!" % [
				def_player.get("name", "Jogador"), def_role,
				att_player.get("name", "Adversário"), att_player.get("role", "")
			])

			var card_type = Referee.process_sanctions(self, foul_info, def_roster_idx, def_player)
			
			if foul_info.get("is_penalty", false):
				push_log("🚨 PÊNALTI PARA O ADVERSÁRIO!")
				_resolve_penalty(false)
			else:
				ai_gets_ball(ai_zone_idx)
				ai_turn()
				emit_match_event("FOUL", {"card": card_type})
				
			MatchEngine.advance_round(self)
		else:
			if action == "SLIDE":
				push_log("❌ Carrinho furado! O atacante passou ileso.")
			else:
				push_log("❌ %s tentou o desarme/bloqueio mas falhou!" % def_player.get("name", "Jogador"))
			
			AIOpponent._move_succeeds()

	state_changed.emit()

func _resolve_penalty(is_player_kicker: bool) -> void:
	if is_player_kicker:
		goals += 1
		Stats.add_goal(active_idx)
		push_log("⚽ GOL DE PÊNALTI!")
		ai_gets_ball(3)
	else:
		ai_goals += 1
		push_log("⚽ O Adversário converteu o pênalti!")
		player_gets_ball()
	
	emit_match_event("GOAL", {})


# ==============================================================================
# 5. MATCHENGINE
# ==============================================================================

func attempt(action: String, target_idx: int = -1) -> void:
	MatchEngine.attempt(self, action, target_idx)


# ==============================================================================
# 6. FLUXO
# ==============================================================================

func next_match() -> void:
	MatchFlow.next_match(self)

func next_challenge_round() -> void:
	MatchFlow.next_challenge_round(self)

func reset_game() -> void:
	MatchFlow.reset_game(self)


# ==============================================================================
# 7. XP
# ==============================================================================

func grant_xp(amount: int) -> void:
	Progression.grant_xp(self, amount)

func _process_pending_xp() -> void:
	Progression.process_pending_xp(self)


# ==============================================================================
# 8. LOGS
# ==============================================================================

func push_log(text: String) -> void:
	log_messages.push_front(text)
	if log_messages.size() > 5:
		log_messages.resize(5)
