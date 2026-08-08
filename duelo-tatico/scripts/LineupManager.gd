class_name LineupManager
extends Node
# LineupManager.gd — Gestão de escalação, estamina, substituições e fadiga do elenco.

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
	"FEINT": 1.8,
	"SHO": 2.0,
	"LONG_SHO": 2.2
}

const DEFENSE_STAMINA = {
	"INTERCEPT": 1.5,
	"TACKLE": 2.0,
	"BLOCK": 1.8,
	"SLIDE": 2.2
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

	# 🏃 PENALIDADE POR ERRO: Se errou a ação, gasta +10% de fôlego!
	var success_multiplier = 1.0 if success else 1.10
	var final_cost = base_cost * success_multiplier

	var current = gs.get_stamina(roster_idx)
	gs.set_stamina(roster_idx, current - final_cost)


# Recuperação do Intervalo Fortalecida
static func process_halftime_recovery(gs: Node) -> void:
	for roster_idx in gs.starters:
		# Ignora expulsos: quem já saiu de campo não "recupera" fôlego no intervalo
		if roster_idx in gs.players_out:
			continue

		var current = gs.get_stamina(roster_idx)
		
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
		gs.push_log("⚠️ Não há mais substituições disponíveis!")
		return false

	var old_roster_idx = gs.starters[role_idx]
	if old_roster_idx == new_roster_idx:
		return false

	# Realiza a substituição no time titular
	gs.starters[role_idx] = new_roster_idx
	gs.substitutions_left -= 1

	# 🚫 Quem sai não pode mais voltar nesta mesma partida (regra do futebol)
	if not (old_roster_idx in gs.subbed_out_players):
		gs.subbed_out_players.append(old_roster_idx)

	# Registra que o substituto entrou em jogo nesta partida
	if not (new_roster_idx in gs.players_who_played):
		gs.players_who_played.append(new_roster_idx)

	# Atualiza o squad em tempo real
	gs._apply_lineup()

	var old_player = RosterData.ROSTER[old_roster_idx]
	var new_player = RosterData.ROSTER[new_roster_idx]

	gs.push_log("🔄 Substituição: Entra %s (%s) no lugar de %s." % [
		new_player.get("name", ""), new_player.get("role", ""), old_player.get("name", "")
	])

	gs.state_changed.emit()
	return true


# Retorna lista de reservas disponíveis para determinada posição
static func available_bench_for(gs: Node, role_idx: int) -> Array[int]:
	var current_starter_idx = gs.starters[role_idx]
	var squad_player = gs.squad[clampi(role_idx, 0, gs.squad.size() - 1)]

	if squad_player.get("is_ejected", false) or current_starter_idx in gs.players_out:
		var empty_list: Array[int] = []
		return empty_list

	var all_candidates = RosterData.candidates_for(role_idx)
	var available: Array[int] = []

	for cand_idx in all_candidates:
		if cand_idx == current_starter_idx:
			continue
			
		if cand_idx in gs.players_out:
			continue

		if cand_idx in gs.starters:
			continue

		# 🚫 Já saiu por substituição nesta partida — não pode voltar
		if cand_idx in gs.subbed_out_players:
			continue

		available.append(cand_idx)

	return available


# Aplica a regra de fadiga pós-jogo entre partidas
static func apply_match_fatigue(stamina_dict: Dictionary, players_who_played: Array) -> void:
	for i in range(RosterData.ROSTER.size()):
		if i in players_who_played:
			# 🏃 JOGOU (Titular ou Entrou): Mantém a estamina exata do fim da partida
			var current_stamina = stamina_dict.get(i, 100.0)
			stamina_dict[i] = clampf(current_stamina, 10.0, 100.0)
		else:
			# 💤 FICOU NO BANCO O JOGO TODO: Volta direto para 100%!
			stamina_dict[i] = 100.0

# Constrói e aplica a escalação com CURVA SUAVE DE STAMINA
static func apply_lineup(gs: Node) -> Array:
	var final_squad: Array = []
	var growth = gs.level - 1

	for i in range(gs.starters.size()):
		var roster_idx = gs.starters[i]
		var raw = RosterData.ROSTER[roster_idx].duplicate()
		var stamina = gs.get_stamina(roster_idx)

		# 📈 CURVA SUAVE DE IMPACTO DA STAMINA (100% -> 1.0x, 50% -> 0.85x, 0% -> 0.70x)
		var st_mult = 0.70 + (0.30 * (stamina / 100.0))

		raw["PAS"] = min(95, int(round((raw["PAS"] + 2 * growth) * st_mult)))
		raw["DRI"] = min(95, int(round((raw["DRI"] + 2 * growth) * st_mult)))
		raw["SHO"] = min(95, int(round((raw["SHO"] + 3 * growth) * st_mult)))
		raw["INT"] = min(95, int(round((raw["INT"] + 2 * growth) * st_mult)))
		raw["TAC"] = min(95, int(round((raw["TAC"] + 2 * growth) * st_mult)))
		raw["BLQ"] = min(95, int(round((raw["BLQ"] + 3 * growth) * st_mult)))

		# Preserva a ordem rígida dos slots originais
		if roster_idx in gs.players_out:
			raw["is_ejected"] = true
		else:
			raw["is_ejected"] = false

		final_squad.append(raw)

	return final_squad
