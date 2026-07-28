class_name LineupManager
extends Node

# Custos Base por Ação de Ataque (Suavizados)
const ACTION_STAMINA = {
	"PASS": 0.8,
	"DRI": 1.8,
	"FEINT": 1.5,
	"SHO": 2.0,
	"LONG_SHO": 2.5
}

# Custos Base por Ação de Defesa
const DEFENSE_STAMINA = {
	"INTERCEPT": 1.2,
	"TACKLE": 1.8,
	"BLOCK": 1.5
}

# Custo Passivo por Posição a cada Rodada (Rebalanceado para equilibrar MEI e CA)
const POSITION_ROUND_COST = {
	"ZAG": 0.8,
	"VOL": 0.9,
	"MEI": 0.9,
	"CA": 0.8
}

# Initialize Stamina
static func init_stamina(stamina_dict: Dictionary) -> void:
	for i in range(RosterData.ROSTER.size()):
		if not stamina_dict.has(i):
			stamina_dict[i] = 100.0


# Reseta a stamina de TODO o elenco para 100%
static func reset_all_stamina(stamina_dict: Dictionary) -> void:
	for i in range(RosterData.ROSTER.size()):
		stamina_dict[i] = 100.0


# Consumo Passivo por Rodada (baseado na Posição do jogador)
static func consume_round_stamina(gs: Node) -> void:
	for i in range(gs.starters.size()):
		var roster_idx = gs.starters[i]
		var role = RosterData.ROLES[i]
		var base_cost = POSITION_ROUND_COST.get(role, 0.8)
		
		# Variação sutil (0.95 a 1.05)
		var actual_cost = base_cost * randf_range(0.95, 1.05)
		var current = gs.get_stamina(roster_idx)
		gs.set_stamina(roster_idx, current - actual_cost)


# Consumo Ativo por Ação
static func consume_action_stamina(gs: Node, roster_idx: int, action: String, success: bool, is_defense: bool = false) -> void:
	var base_cost = 0.0
	
	if is_defense:
		base_cost = DEFENSE_STAMINA.get(action, 1.5)
	else:
		base_cost = ACTION_STAMINA.get(action, 1.5)

	# Se falhou, gasta menos energia
	var success_multiplier = 1.0 if success else 0.5
	var final_cost = base_cost * success_multiplier

	var current = gs.get_stamina(roster_idx)
	gs.set_stamina(roster_idx, current - final_cost)


# Recuperação do Intervalo Fortalecida
static func process_halftime_recovery(gs: Node) -> void:
	for roster_idx in gs.starters:
		var current = gs.get_stamina(roster_idx)
		
		# Boost para quem está cansadão (<60%)
		var recovery = 0.0
		if current < 60.0:
			recovery = randf_range(16.0, 22.0)
		elif current < 80.0:
			recovery = randf_range(10.0, 15.0)
		else:
			recovery = randf_range(5.0, 8.0)

		gs.set_stamina(roster_idx, current + recovery)


# Executa a substituição validando limites e disponibilidade
static func make_substitution(gs: Node, role_idx: int, new_roster_idx: int) -> bool:
	if gs.substitutions_left <= 0:
		gs.push_log("Não há substituições restantes nesta partida!")
		return false

	if new_roster_idx in gs.players_out:
		gs.push_log("Este jogador já foi substituído e não pode voltar!")
		return false

	var old_roster_idx = gs.starters[role_idx]
	var old_player = RosterData.ROSTER[old_roster_idx]
	var new_player = RosterData.ROSTER[new_roster_idx]
	var old_stamina = int(gs.get_stamina(old_roster_idx))

	# Registra o jogador substituído como indisponível para o resto da partida
	gs.players_out.append(old_roster_idx)

	# Aplica a troca na escalação titular
	gs.starters[role_idx] = new_roster_idx
	gs.substitutions_left -= 1

	# Atualiza o squad no GameState
	gs._apply_lineup()

	# Narração no Log
	var msg = "🔄 Substituição: Sai %s (%d%% stamina) e entra %s!" % [old_player["name"], old_stamina, new_player["name"]]
	gs.push_log(msg)
	SFX.play_whistle()

	gs.state_changed.emit()
	return true


# Retorna lista de reservas disponíveis para determinada posição (exclui titulares e quem já saiu)
static func available_bench_for(gs: Node, role_idx: int) -> Array:
	var role = RosterData.ROLES[role_idx]
	var candidates = []
	for i in range(RosterData.ROSTER.size()):
		var p = RosterData.ROSTER[i]
		if p["role"] == role:
			if not (i in gs.starters) and not (i in gs.players_out):
				candidates.append(i)
	return candidates


static func apply_match_fatigue(_stamina_dict: Dictionary, _starters: Array) -> void:
	pass


static func apply_lineup(gs: Node) -> Array:
	var squad_list = []
	var growth = gs.level - 1

	for i in range(gs.starters.size()):
		var roster_idx = gs.starters[i]
		var raw = RosterData.ROSTER[roster_idx].duplicate()
		var stamina = gs.get_stamina(roster_idx)

		var st_mult = 1.0
		if stamina < 50.0: st_mult = 0.80
		elif stamina < 75.0: st_mult = 0.90

		raw["PAS"] = min(95, int(round((raw["PAS"] + 2 * growth) * st_mult)))
		raw["DRI"] = min(95, int(round((raw["DRI"] + 2 * growth) * st_mult)))
		raw["SHO"] = min(95, int(round((raw["SHO"] + 3 * growth) * st_mult)))
		raw["INT"] = min(95, int(round((raw["INT"] + 2 * growth) * st_mult)))
		raw["TAC"] = min(95, int(round((raw["TAC"] + 2 * growth) * st_mult)))
		raw["BLQ"] = min(95, int(round((raw["BLQ"] + 2 * growth) * st_mult)))

		squad_list.append(raw)

	return squad_list
