class_name Matchups
extends Node
# Matchups.gd — Sistema centralizador de duelos táticos e marcação por função.

# Tabela de Duelos Diretos (Role Atacante -> Role Marcador)
const PAIRS = {
	"CA": "ZAG",
	"MEI": "VOL",
	"VOL": "MEI",
	"ZAG": "CA"
}

# Retorna a role do jogador que deve marcar a role do atacante
static func defender_role_for(attacker_role: String) -> String:
	return PAIRS.get(attacker_role, "ZAG")


# Retorna o jogador da IA que marca o jogador do usuário (baseado na role do usuário)
static func opponent_marker_for_player(gs: Node, player_dict: Dictionary) -> Dictionary:
	var target_role = defender_role_for(player_dict.get("role", "ZAG"))
	return _find_player_by_role(gs.current_opponent_team().get("squad", []), target_role)


# Retorna o jogador do usuário que marca a IA (baseado na role da IA)
static func player_defender_for_ai(gs: Node, ai_dict: Dictionary) -> Dictionary:
	var target_role = defender_role_for(ai_dict.get("role", "CA"))
	return _find_player_by_role(gs.squad, target_role)


# Retorna o índice do slot no squad do usuário para a role informada
static func player_slot_for_role(gs: Node, role: String) -> int:
	for i in range(gs.squad.size()):
		if gs.squad[i].get("role", "") == role:
			return i
	return 0


# Retorna o índice do slot no squad da IA para a role informada
static func ai_slot_for_role(gs: Node, role: String) -> int:
	var opp_squad = gs.current_opponent_team().get("squad", [])
	for i in range(opp_squad.size()):
		if opp_squad[i].get("role", "") == role:
			return i
	return 0


# Função auxiliar para encontrar dicionário de jogador por role
static func _find_player_by_role(squad_list: Array, role: String) -> Dictionary:
	for p in squad_list:
		if p.get("role", "") == role:
			return p
	return squad_list[0] if not squad_list.is_empty() else {}
