extends Node
# GameState.gd — Autoload (Singleton) Central de Estado

signal state_changed
signal match_event_triggered(event_name: String, details: Dictionary)

const OpponentTeams = preload("res://scripts/OpponentTeams.gd")

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
var walkover_winner: String = "" # "" | "PLAYER" | "AI"

var goals: int = 0
var ai_goals: int = 0
var turnovers: int = 0
var streak: int = 0
var round_num: int = 0
var match_over: bool = false
var campaign_stage: int = 1
var challenge_wins: int = 0
var challenge_best: int = 0

# ---------- 2. LINEUP & FADIGA ----------
var starters: Array = [0, 2, 4, 6]
var squad: Array = []
var player_stamina: Dictionary = {}
var substitutions_left: int = 2
var players_out: Array = []
var players_who_played: Array = []
# 🚫 Jogadores que já saíram por substituição nesta partida — não podem
# voltar a jogar até a próxima partida (regra do futebol).
var subbed_out_players: Array = []

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
var ai_yellow_cards: Dictionary = {}
var ai_players_out: Array = []
# 🔒 Squad ativo do adversário para a partida atual — construído 1x por
# partida a partir de OpponentTeams (que nunca é mutado diretamente) e
# atualizado sempre que um cartão/expulsão da IA acontece.
var opponent_squad: Array = []

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
	_apply_opponent_lineup()


# ==============================================================================
# 1. ESTADO DE PARTIDA E DIFICULDADE
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
	players_who_played.clear()
	
	# Adiciona os IDs do Roster de cada titular atual
	for roster_idx in starters:
		if not (roster_idx in players_who_played):
			players_who_played.append(roster_idx)
			

func match_stats() -> Dictionary:
	return Stats.to_dict()


# ==============================================================================
# 2. ESCALAÇÃO, STAMINA E SUBSTITUIÇÕES
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
	subbed_out_players.clear()
	
	# 🧹 Limpa os cartões e expulsões da IA também!
	ai_yellow_cards.clear()
	ai_players_out.clear()
	walkover_winner = ""
	_apply_lineup()
	
func can_substitute() -> bool:
	return substitutions_left > 0

func make_substitution(role_idx: int, new_roster_idx: int) -> bool:
	return LineupManager.make_substitution(self, role_idx, new_roster_idx)
	
# 💤 Aplica a regra entre jogos: QUEM JOGOU mantém a energia; QUEM DESCANSOU recupera 100%
func apply_match_fatigue() -> void:
	LineupManager.apply_match_fatigue(player_stamina, players_who_played)
	
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

# 🔄 Reconstrói o squad do adversário a partir dos dados originais em
# OpponentTeams + as flags de cartão/expulsão vindas de ai_players_out /
# ai_yellow_cards (fonte de verdade). Nunca escreve de volta em OpponentTeams.
func _apply_opponent_lineup() -> void:
	opponent_squad = OpponentTeams.build_active_squad(self)

func active_player() -> Dictionary:
	var safe_idx = clampi(active_idx, 0, max(0, squad.size() - 1))
	return squad[safe_idx] if not squad.is_empty() else {}

# 🛡️ Defensor Ativo com Cobertura Inteligente (Se o marcador original estiver expulso)
func active_defender() -> Dictionary:
	var def_dict = Matchups.player_defender_for_ai(self, ai_active_player())
	
	# Se o marcador direto (ex: ZAG) foi expulso, busca o companheiro não-expulso mais próximo
	if def_dict.get("is_ejected", false):
		# Prioridade de Cobertura: VOL -> MEI -> CA
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
# 3. CONTROLE DE POSSE E COMPANHEIROS
# ==============================================================================

func player_gets_ball() -> void:
	MatchEngine.player_gets_ball(self)
	
	# Se o portador da bola estivesse expulso, passa a posse para o companheiro válido mais próximo
	if active_player().get("is_ejected", false):
		for i in range(squad.size()):
			if not squad[i].get("is_ejected", false):
				active_idx = i
				# Mantém zone_idx consistente com a posição no campo, sem forçar sobrescrita errada
				break

func recover_possession(defender_idx: int) -> void:
	MatchEngine.recover_possession(self, defender_idx)


# ==============================================================================
# 4. ADVERSÁRIO E RESOLUÇÃO DEFENSIVA
# ==============================================================================

func current_opponent_team() -> Dictionary:
	if game_mode == GameMode.CHALLENGE:
		return OpponentTeams.team_for_challenge(challenge_wins)
	return OpponentTeams.team_for_stage(campaign_stage)

func opponent_team_name() -> String:
	return current_opponent_team().get("name", "Adversário")

# ⚠️ Usa sempre o cache (opponent_squad), nunca current_opponent_team()
# direto — é o único jeito de manter cartões/expulsões da IA visíveis de
# forma consistente durante a partida, sem vazar pros dados originais.
func ai_active_player() -> Dictionary:
	var safe_idx = clampi(ai_active_idx, 0, max(0, opponent_squad.size() - 1))
	return opponent_squad[safe_idx] if not opponent_squad.is_empty() else {}

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
	return AIOpponent.defense_chance(action)

func defend(action: String) -> void:
	AIOpponent.defend(action)

func _resolve_penalty(is_player_kicker: bool) -> void:
	PenaltyEngine.execute_penalty(self, is_player_kicker)


# ==============================================================================
# 5. MOTORES DE JOGO
# ==============================================================================

func attempt(action: String, target_idx: int = -1) -> void:
	MatchEngine.attempt(self, action, target_idx)


# ==============================================================================
# 6. FLUXO DE PARTIDAS
# ==============================================================================

func next_match() -> void:
	MatchFlow.next_match(self)

# Chamado quando o jogador confirma a escalação na Campaign Menu e aperta
# "Iniciar Partida" — só aqui a partida de fato começa (kickoff + registro
# de quem está jogando para a fadiga pós-jogo).
func start_campaign_match() -> void:
	MatchFlow.start_campaign_match(self)

func next_challenge_round() -> void:
	MatchFlow.next_challenge_round(self)

func reset_game() -> void:
	MatchFlow.reset_game(self)


# ==============================================================================
# 7. PROGRESSÃO E XP
# ==============================================================================

func grant_xp(amount: int) -> void:
	Progression.grant_xp(self, amount)

func _process_pending_xp() -> void:
	Progression.process_pending_xp(self)


# ==============================================================================
# 8. SISTEMA DE TRANSMISSÃO E LOGS
# ==============================================================================

func push_log(text: String) -> void:
	log_messages.push_front(text)
	if log_messages.size() > 5:
		log_messages.resize(5)
