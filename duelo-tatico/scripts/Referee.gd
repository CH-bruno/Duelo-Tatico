class_name Referee
extends Node
# Referee.gd — Árbitro da Partida (Validação de Faltas, Pênaltis, Cartões e Regra do W.O.)

enum Decision {
	NONE,
	FOUL,
	PENALTY
}

const FOUL_CHANCES = {
	"SLIDE_MISS_FOUL": 100,   # Carrinho errado na defesa = 100% falta
	"TACKLE_MISS_FOUL": 20,
	"BLOCK_MISS_FOUL": 10,
	"INTERCEPT_MISS_FOUL": 5,
	"DRIBBLE_FOUL": 15
}

# ==============================================================================
# WO POR EXPULSÕES (Centralizado no Árbitro)
# ==============================================================================

static func check_walkover(gs: Node) -> bool:
	# 2 expulsões do jogador -> vitória do adversário por WO
	if gs.players_out.size() >= 2:
		gs.match_over = true
		gs.walkover_winner = "AI"
		# 🔒 Placar fixo de W.O. (0 × 3) — substitui o placar real da partida
		gs.goals = 0
		gs.ai_goals = 3
		SFX.play_whistle()
		# ⚠️ Finaliza o XP pendente aqui — o WO nunca passa por advance_round(),
		# que é o único outro lugar que chama process_pending_xp().
		Progression.process_pending_xp(gs)
		gs.push_log("🟥🟥 WO! Seu time ficou com 2 jogadores expulsos.")
		gs.push_log("Vitória do adversário por WO (%d × %d)." % [gs.goals, gs.ai_goals])
		gs.state_changed.emit()
		return true

	# 2 expulsões da IA -> vitória do jogador por WO
	if gs.ai_players_out.size() >= 2:
		gs.match_over = true
		gs.walkover_winner = "PLAYER"
		# 🔒 Placar fixo de W.O. (3 × 0) — substitui o placar real da partida
		gs.goals = 3
		gs.ai_goals = 0
		SFX.play_whistle()
		Progression.process_pending_xp(gs)
		gs.push_log("🟥🟥 WO! O adversário ficou com 2 jogadores expulsos.")
		gs.push_log("Vitória por WO (%d × %d)!" % [gs.goals, gs.ai_goals])
		gs.state_changed.emit()
		return true

	return false


# 🎯 AVALIAÇÃO DE FALTA E PÊNALTI BASEADA NO ROLE
static func evaluate_foul(gs: Node, foul_context: String, is_player_foul: bool = true) -> Decision:
	var base_chance = float(FOUL_CHANCES.get(foul_context, 10))
	var active_def = gs.active_defender()
	var def_trait = active_def.get("trait", "")
	
	if foul_context != "SLIDE_MISS_FOUL":
		if def_trait == "LIBERO" or def_trait == "CLEAN_PLAY":
			base_chance *= 0.5
		elif def_trait == "AGGRESSIVE":
			base_chance += 10.0

	var roll = randi_range(1, 100)

	if roll <= int(base_chance):
		var is_penalty = false

		if is_player_foul:
			var ai_attacker = gs.ai_active_player()
			is_penalty = (ai_attacker.get("role", "") == "CA")
		else:
			var player_attacker = gs.active_player()
			is_penalty = (player_attacker.get("role", "") == "CA")

		if is_penalty:
			return Decision.PENALTY
		else:
			return Decision.FOUL

	return Decision.NONE


# 🎯 PROCESSAMENTO DE CARTÕES
static func process_cards(gs: Node, roster_idx: int, player_dict: Dictionary, is_slide: bool = false, is_player_foul: bool = true) -> String:
	var card_roll = randi_range(1, 100)
	var yellow_threshold = 75 if is_slide else 25
	
	var p_name = player_dict.get("name", "Jogador")
	var p_role = player_dict.get("role", "DEF")
	var target_yellows = gs.yellow_cards if is_player_foul else gs.ai_yellow_cards

	if card_roll <= yellow_threshold:
		if target_yellows.get(roster_idx, false):
			# 🟨➡️🟥 SEGUNDO AMARELO
			_eject_player(gs, roster_idx, player_dict, is_player_foul)
			gs.push_log(AIOpponent._format_narration(Narration.SECOND_YELLOW_CARD.pick_random(), [p_name, p_role]))
			SFX.play_whistle()
			return "RED"
		else:
			# 🟨 PRIMEIRO AMARELO
			target_yellows[roster_idx] = true
			_refresh_lineup(gs, is_player_foul)
			gs.push_log(AIOpponent._format_narration(Narration.YELLOW_CARD.pick_random(), [p_name, p_role]))
			SFX.play_whistle()
			return "YELLOW"
			
	elif is_slide and card_roll > 85:
		# 🟥 VERMELHO DIRETO
		_eject_player(gs, roster_idx, player_dict, is_player_foul)
		gs.push_log(AIOpponent._format_narration(Narration.RED_CARD.pick_random(), [p_name, p_role]))
		SFX.play_whistle()
		return "RED"

	return "NONE"


static func _eject_player(gs: Node, roster_idx: int, _player_dict: Dictionary, is_player_foul: bool = true) -> void:
	if is_player_foul:
		if not (roster_idx in gs.players_out):
			gs.players_out.append(roster_idx)
	else:
		if not (roster_idx in gs.ai_players_out):
			gs.ai_players_out.append(roster_idx)

	# Reconstrói a escalação
	_refresh_lineup(gs, is_player_foul)

	# 🟥 2 expulsões = WO imediato
	check_walkover(gs)


static func _refresh_lineup(gs: Node, is_player_foul: bool) -> void:
	if is_player_foul:
		gs._apply_lineup()
	else:
		gs._apply_opponent_lineup()
