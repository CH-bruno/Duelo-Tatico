class_name LineupManager
extends Node

static func init_stamina(player_stamina: Dictionary) -> void:
	player_stamina.clear()
	for i in range(RosterData.ROSTER.size()):
		player_stamina[i] = 100.0


static func consume_starter_stamina(gs: Node, cost: float = 12.0) -> void:
	for idx in gs.starters:
		var current = gs.get_stamina(idx)
		gs.set_stamina(idx, current - cost)


static func apply_match_fatigue(player_stamina: Dictionary, starters: Array) -> void:
	for i in range(RosterData.ROSTER.size()):
		if not player_stamina.has(i):
			player_stamina[i] = 100.0

		if i in starters:
			player_stamina[i] = maxf(30.0, player_stamina[i] - 20.0)
		else:
			player_stamina[i] = minf(100.0, player_stamina[i] + 30.0)


static func apply_lineup(gs: Node) -> Array:
	var growth_levels = gs.level - 1
	var new_squad = []
	
	for idx in gs.starters:
		var p = RosterData.ROSTER[idx].duplicate()
		var stamina_val = gs.get_stamina(idx)
		
		var stamina_mult = 1.0
		if stamina_val < 50.0:
			stamina_mult = 0.80
		elif stamina_val < 75.0:
			stamina_mult = 0.90
		
		p["PAS"] = min(95, int(round((p["PAS"] + 2 * growth_levels) * stamina_mult)))
		p["DRI"] = min(95, int(round((p["DRI"] + 2 * growth_levels) * stamina_mult)))
		p["SHO"] = min(95, int(round((p["SHO"] + 3 * growth_levels) * stamina_mult)))
		p["INT"] = min(95, int(round((p["INT"] + 2 * growth_levels) * stamina_mult)))
		p["TAC"] = min(95, int(round((p["TAC"] + 2 * growth_levels) * stamina_mult)))
		p["BLQ"] = min(95, int(round((p["BLQ"] + 3 * growth_levels) * stamina_mult)))
		new_squad.append(p)
		
	return new_squad
