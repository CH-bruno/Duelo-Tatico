class_name Matchups
extends Node
# Matchups.gd — Sistema centralizador de duelos táticos e marcação por função.

const PAIRS = {
	"CA": "ZAG",
	"MEI": "VOL",
	"VOL": "MEI",
	"ZAG": "CA"
}

static func defender_role_for(attacker_role: String) -> String:
	return PAIRS.get(attacker_role, "ZAG")


static func opponent_marker_for_player(gs: Node, player_dict: Dictionary) -> Dictionary:
	var target_role = defender_role_for(player_dict.get("role", "ZAG"))
	return _find_player_by_role(gs.opponent_squad, target_role)


static func player_defender_for_ai(gs: Node, ai_dict: Dictionary) -> Dictionary:
	var target_role = defender_role_for(ai_dict.get("role", "CA"))
	return _find_player_by_role(gs.squad, target_role)


# 🎯 RETORNO DE SLOT BLINDADO: Se não achar no squad por role dinamica, usa a ordem padrao dos slots (0=ZAG, 1=VOL, 2=MEI, 3=CA)
static func player_slot_for_role(gs: Node, role: String) -> int:
	for i in range(gs.squad.size()):
		if gs.squad[i].get("role", "") == role:
			return i
			
	# Fallback seguro baseado na constante de roles padrão do jogo
	var default_roles = ["ZAG", "VOL", "MEI", "CA"]
	var fallback_idx = default_roles.find(role)
	return fallback_idx if fallback_idx != -1 else 0


static func ai_slot_for_role(gs: Node, role: String) -> int:
	var opp_squad = gs.opponent_squad
	for i in range(opp_squad.size()):
		if opp_squad[i].get("role", "") == role:
			return i
			
	var default_roles = ["ZAG", "VOL", "MEI", "CA"]
	var fallback_idx = default_roles.find(role)
	return fallback_idx if fallback_idx != -1 else 0


static func _find_player_by_role(squad_list: Array, role: String) -> Dictionary:
	for p in squad_list:
		if p.get("role", "") == role:
			return p
	return squad_list[0] if not squad_list.is_empty() else {}
