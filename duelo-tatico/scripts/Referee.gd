class_name Referee
extends Node
# Referee.gd — Árbitro da Partida (Validação por Posicionamento Tático)

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
			# 🚨 JOGADOR FEZ FALTA NA DEFESA:
			# Se quem está com a bola na IA é o CA (Centroavante), o lance é na SUA Grande Área -> PÊNALTI CONTRA VOCÊ!
			var ai_attacker = gs.ai_active_player()
			is_penalty = (ai_attacker.get("role", "") == "CA")
		else:
			# 🚨 IA FEZ FALTA NO ATAQUE:
			# Se quem está com a bola no seu time é o seu CA (Centroavante), o lance é na área da IA -> PÊNALTI A SEU FAVOR!
			var player_attacker = gs.active_player()
			is_penalty = (player_attacker.get("role", "") == "CA")

		if is_penalty:
			return Decision.PENALTY
		else:
			return Decision.FOUL

	return Decision.NONE


# 🎯 roster_idx: para faltas do jogador é o índice do RosterData; para
# faltas da IA é o índice DENTRO do squad do time adversário (0..3).
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
			gs.push_log(Narration.SECOND_YELLOW_CARD.pick_random() % [p_name, p_role])
			SFX.play_whistle()
			return "RED"
		else:
			# 🟨 PRIMEIRO AMARELO
			target_yellows[roster_idx] = true
			_refresh_lineup(gs, is_player_foul)
			gs.push_log(Narration.YELLOW_CARD.pick_random() % [p_name, p_role])
			SFX.play_whistle()
			return "YELLOW"
			
	elif is_slide and card_roll > 85:
		# 🟥 VERMELHO DIRETO
		_eject_player(gs, roster_idx, player_dict, is_player_foul)
		gs.push_log(Narration.RED_CARD.pick_random() % [p_name, p_role])
		SFX.play_whistle()
		return "RED"

	return "NONE"


static func _eject_player(gs: Node, roster_idx: int, player_dict: Dictionary, is_player_foul: bool = true) -> void:
	if is_player_foul:
		if not (roster_idx in gs.players_out):
			gs.players_out.append(roster_idx)
	else:
		if not (roster_idx in gs.ai_players_out):
			gs.ai_players_out.append(roster_idx)

	_refresh_lineup(gs, is_player_foul)


# ⚠️ Nunca escreve "is_ejected"/"has_yellow" direto no dicionário do
# jogador — squad e opponent_squad são sempre RECONSTRUÍDOS a partir de
# players_out/yellow_cards e ai_players_out/ai_yellow_cards (fonte de
# verdade). Isso evita corromper permanentemente os dados originais de
# RosterData/OpponentTeams.
static func _refresh_lineup(gs: Node, is_player_foul: bool) -> void:
	if is_player_foul:
		gs._apply_lineup()
	else:
		gs._apply_opponent_lineup()
