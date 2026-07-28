class_name Referee
extends Node

static func check_foul(gs: Node) -> bool:
	if randf() < 0.15:
		gs.push_log("⚠️ FALTA! O juiz paralisa a jogada.")
		SFX.play_whistle()
		gs.emit_match_event("FOUL", {})
		return true
	return false

static func check_yellow_card(_gs: Node) -> bool:
	return false

static func check_red_card(_gs: Node) -> bool:
	return false

static func check_penalty(_gs: Node) -> bool:
	return false
