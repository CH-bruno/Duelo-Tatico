class_name Progression
extends Node

# Concede XP acumulado da partida
static func grant_xp(gs: Node, amount: int) -> void:
	Stats.xp_gained_match += amount
	gs.pending_xp += amount


# Processa o XP ao final da partida e calcula subidas de nível
static func process_pending_xp(gs: Node) -> void:
	gs.xp += gs.pending_xp
	gs.pending_xp = 0
	
	var initial_level = gs.level
	while gs.xp >= gs.xp_to_next:
		gs.xp -= gs.xp_to_next
		gs.level += 1
		gs.xp_to_next = int(round(gs.xp_to_next * 1.35))
		
	if gs.level > initial_level:
		gs.push_log("🎉 Seu time subiu para o Nível %d! Atributos evoluídos." % gs.level)
