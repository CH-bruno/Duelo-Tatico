class_name LineupManager
extends Node

const POSITION_ROUND_COST = {
	"ZAG": 1.0,
	"VOL": 1.1,
	"MEI": 1.1,
	"CA": 1.0
}

# Custos de Ação Rebalanceados
const ACTION_STAMINA = {
	"PASS": 1.0,
	"DRI": 1.5,
	"FEINT": 2.0,
	"SHO": 2.4,
	"LONG_SHO": 2.6
}

const DEFENSE_STAMINA = {
	"INTERCEPT": 1.5,
	"TACKLE": 2.2,
	"BLOCK": 1.8,
	"SLIDE": 2.0
}

# Inicializa Stamina
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
		
		# Ignora expulsos
		if roster_idx in gs.players_out:
			continue

		var role = RosterData.ROLES[i]
		var base_cost = POSITION_ROUND_COST.get(role, 1.0)
		
		var actual_cost = base_cost * randf_range(0.95, 1.05)
		var current = gs.get_stamina(roster_idx)
		gs.set_stamina(roster_idx, current - actual_cost)
		

# Consumo Ativo por Ação
static func consume_action_stamina(gs: Node, roster_idx: int, action: String, success: bool, is_defense: bool = false) -> void:
	var base_cost = 0.0
	
	if is_defense:
		base_cost = DEFENSE_STAMINA.get(action, 1.5)
	else:
		base_cost = ACTION_STAMINA.get(action, 1.0)

	# Se falhou, gasta menos energia (50%)
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

	# 🛑 Não permite substituir jogador expulso
	var squad_player = gs.squad[clampi(role_idx, 0, gs.squad.size() - 1)]
	if squad_player.get("is_ejected", false):
		gs.push_log("Jogadores expulsos não podem ser substituídos!")
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


# Retorna lista de reservas disponíveis para determinada posição (exclui titulares, quem já saiu e expulsos)
static func available_bench_for(gs: Node, role_idx: int) -> Array[int]:
	var current_starter_idx = gs.starters[role_idx]
	var squad_player = gs.squad[clampi(role_idx, 0, gs.squad.size() - 1)]

	# 🛑 REGRA DE EXPULSÃO: Se o jogador da posição estiver expulso, bloqueia substituições
	if squad_player.get("is_ejected", false) or current_starter_idx in gs.players_out:
		return []

	var all_candidates = RosterData.candidates_for(role_idx)
	var available: Array[int] = []

	for cand_idx in all_candidates:
		# 1. Ignora o titular que já está jogando nessa posição
		if cand_idx == current_starter_idx:
			continue
			
		# 2. Ignora jogadores que já saíram do jogo (substituídos ou expulsos)
		if cand_idx in gs.players_out:
			continue

		# 3. Ignora jogadores que porventura estejam escalados em outras posições
		if cand_idx in gs.starters:
			continue

		available.append(cand_idx)

	return available


static func apply_match_fatigue(stamina_dict: Dictionary, starters: Array) -> void:
	for i in range(RosterData.ROSTER.size()):
		if i in starters:
			# Titulares mantêm a stamina atual com a qual terminaram o jogo
			continue
		else:
			# ⚡ Quem NÃO JOGOU (Banco/Reserva) recupera 100% no vestiário pós-jogo
			stamina_dict[i] = 100.0


static func apply_lineup(gs: Node) -> Array:
	var active_squad: Array = []
	var ejected_squad: Array = []
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

		if roster_idx in gs.players_out:
			raw["is_ejected"] = true
			ejected_squad.append(raw)
		else:
			raw["is_ejected"] = false
			active_squad.append(raw)

	# REORGANIZAÇÃO:
	# Quem sobrou cobre da Zaga até o Meio/Ataque.
	# O expulso fica isolado no último slot.
	var final_squad: Array = []
	final_squad.append_array(active_squad)
	final_squad.append_array(ejected_squad)

	return final_squad
