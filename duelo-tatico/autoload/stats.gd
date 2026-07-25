extends Node
# Autoload — estatísticas da partida atual. Separado do GameState pra
# não misturar "o que está acontecendo no jogo" com "números pra tela
# de resumo no fim da partida".

var passes_attempted = 0
var passes_completed = 0

var dribbles_attempted = 0
var dribbles_completed = 0

var feints_attempted = 0
var feints_completed = 0

var shots = 0
var shots_on_target = 0

var long_shots = 0
var long_shots_on_target = 0

var interceptions = 0
var tackles = 0
var blocks = 0

var xp_gained_match = 0


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
	# goals/turnovers/rounds continuam morando no GameState (fazem parte
	# do estado da partida, não são só "estatística de resumo").
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
