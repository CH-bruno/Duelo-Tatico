extends Node
# GameState.gd — Autoload (Singleton) Central de Estado

signal state_changed
signal match_event_triggered(event_name: String, details: Dictionary)

const OpponentTeams = preload("res://scripts/OpponentTeams.gd")

# ---------- 1. ESTADO ----------
const ZONES = ["Campo Próprio", "Meio-Campo", "Terço Final", "Grande Área"]
const MAX_CAMPAIGN_STAGE = 5
const MAX_ROUNDS = 30

enum GameMode { CAMPAIGN, CHALLENGE }
var game_mode = GameMode.CAMPAIGN

var goals = 0
var ai_goals = 0
var turnovers = 0
var streak = 0
var round_num = 0
var match_over = false
var campaign_stage = 1
var challenge_wins = 0
var challenge_best = 0

# ---------- 2. LINEUP ----------
var starters = [0, 2, 4, 6]
var squad = []
var player_stamina: Dictionary = {}

# ---------- 3. POSSE ----------
enum Possession { PLAYER, AI }
var possession = Possession.PLAYER

enum TurnState { PLAYER_ATTACK, PLAYER_DEFENSE }
var turn_state = TurnState.PLAYER_ATTACK

var zone_idx = 0
var active_idx = 0
var momentum_bonus = 0

# ---------- 4. IA ----------
enum AIMove { PASS, DRIBBLE, LONG_SHOT, SHOT }
var ai_next_move = AIMove.PASS

var ai_zone_idx = 0
var ai_active_idx = 0
var ai_momentum = 0

# ---------- 7. XP ----------
var level = 1
var xp = 0
var pending_xp = 0
var xp_to_next = 20

# ---------- 8. LOGS ----------
var log_messages = []


func _ready() -> void:
	init_stamina()
	_apply_lineup()
	push_log("Apito inicial. A bola está com o %s." % active_player()["name"])


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

func init_stamina() -> void:
	LineupManager.init_stamina(player_stamina)

func get_stamina(roster_idx: int) -> float:
	return player_stamina.get(roster_idx, 100.0)

func set_stamina(roster_idx: int, amount: float) -> void:
	player_stamina[roster_idx] = clampf(amount, 0.0, 100.0)

func consume_starter_stamina(cost: float = 12.0) -> void:
	LineupManager.consume_starter_stamina(self, cost)

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
	return squad[active_idx]

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

func recover_possession(defender_idx: int) -> void:
	MatchEngine.recover_possession(self, defender_idx)


# ==============================================================================
# 4. IA
# ==============================================================================

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

func _opponent_marker_for(my_zone: int) -> Dictionary:
	return current_opponent_team()["squad"][attacker_for_zone(my_zone)]

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

func ai_attack_strength() -> int:
	return AIOpponent.attack_strength()

func ai_gets_ball(player_zone: int = 0) -> void:
	AIOpponent.gets_ball(player_zone)

func ai_turn() -> void:
	AIOpponent.take_turn()

func defense_chance(action: String) -> int:
	return AIOpponent.defense_chance(action)

func defend(action: String) -> void:
	AIOpponent.defend(action)


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
	if log_messages.size() > 6:
		log_messages.resize(6)
