extends Node
# Stats.gd — Autoload de estatísticas da partida atual.

var passes_attempted: int = 0
var passes_completed: int = 0

var dribbles_attempted: int = 0
var dribbles_completed: int = 0

var feints_attempted: int = 0
var feints_completed: int = 0

var shots: int = 0
var shots_on_target: int = 0

var long_shots: int = 0
var long_shots_on_target: int = 0

var interceptions: int = 0
var tackles: int = 0
var blocks: int = 0

var xp_gained_match: int = 0


# ---------- Mutadores / Ações Ataque ----------

func pass_attempt() -> void:
	passes_attempted += 1

func pass_completed() -> void:
	passes_completed += 1

func dribble_attempt() -> void:
	dribbles_attempted += 1

func dribble_success() -> void:
	dribbles_completed += 1

func feint_attempt() -> void:
	feints_attempted += 1

func feint_success() -> void:
	feints_completed += 1

func shot() -> void:
	shots += 1

func shot_on_target() -> void:
	shots_on_target += 1

func long_shot_attempt() -> void:
	long_shots += 1

func long_shot_on_target() -> void:
	long_shots_on_target += 1


# ---------- Mutadores / Ações Defesa ----------

func interception() -> void:
	interceptions += 1

func tackle() -> void:
	tackles += 1

func block() -> void:
	blocks += 1


# ---------- Reset e Exportação ----------

func reset() -> void:
	passes_attempted = 0
	passes_completed = 0
	dribbles_attempted = 0
	dribbles_completed = 0
	feints_attempted = 0
	feints_completed = 0
	shots = 0
	shots_on_target = 0
	long_shots = 0
	long_shots_on_target = 0
	interceptions = 0
	tackles = 0
	blocks = 0
	xp_gained_match = 0


func to_dict() -> Dictionary:
	return {
		"passes_attempted": passes_attempted,
		"passes_completed": passes_completed,
		"dribbles_attempted": dribbles_attempted,
		"dribbles_completed": dribbles_completed,
		"feints_attempted": feints_attempted,
		"feints_completed": feints_completed,
		"shots": shots,
		"shots_on_target": shots_on_target,
		"long_shots": long_shots,
		"long_shots_on_target": long_shots_on_target,
		"interceptions": interceptions,
		"tackles": tackles,
		"blocks": blocks,
		"xp": xp_gained_match,
		"goals": GameState.goals,
		"goals_ai": GameState.ai_goals,
		"turnovers": GameState.turnovers,
		"rounds": GameState.round_num,
	}
