class_name Referee
extends Node
# Referee.gd — Árbitro da Partida (Controle de Faltas, Cartões e Pênaltis)

# Avalia se a jogada defensiva resultou em falta e se é Pênalti
static func check_foul(gs: Node, action: String = "TACKLE", diff: int = 0) -> Dictionary:
	var base_foul_chance = 8.0 if action == "TACKLE" else 30.0
	
	if diff > 20:
		base_foul_chance += 12.0
	elif diff > 10:
		base_foul_chance += 6.0

	var active_def = gs.active_defender()
	var def_trait = active_def.get("trait", "")
	
	if def_trait == "LIBERO" or def_trait == "CLEAN_PLAY":
		base_foul_chance *= 0.5
	elif def_trait == "AGGRESSIVE":
		base_foul_chance += 10.0

	var is_foul = randf() * 100.0 < base_foul_chance
	if not is_foul:
		return {
			"is_foul": false,
			"severity": 0,
			"is_penalty": false,
			"is_yellow": false,
			"is_red": false
		}

	# ✅ REGRA RIGOROSA DO PÊNALTI:
	# Apenas se quem está com a bola for o CA e estiver dentro da Grande Área correspondente!
	var is_penalty = false
	if gs.possession == gs.Possession.AI:
		var ai_player = gs.ai_active_player()
		# IA está atacando na sua Grande Área (Coluna 0) com o CA (Pipoca)
		if ai_player.get("role", "") == "CA" and gs.ai_zone_idx == 0:
			is_penalty = true
	else:
		var player_act = gs.active_player()
		# Usuário está atacando na Grande Área rival (Coluna 3) com o CA (Fominha)
		if player_act.get("role", "") == "CA" and gs.zone_idx == 3:
			is_penalty = true

	var severity = randi_range(10, 45) if action == "TACKLE" else randi_range(35, 80)

	if is_penalty:
		severity += 25
	if diff > 15:
		severity += 10
	if def_trait == "AGGRESSIVE":
		severity += 15

	return {
		"is_foul": true,
		"severity": severity,
		"is_penalty": is_penalty,
		"is_yellow": severity >= 40 and severity < 80,
		"is_red": severity >= 80
	}


# No Referee.gd:

static func process_sanctions(gs: Node, foul_info: Dictionary, roster_idx: int, def_player: Dictionary = {}) -> String:
	var player_name = def_player.get("name", "Jogador")
	
	if foul_info.get("is_red", false):
		gs.push_log("🟥 CARTÃO VERMELHO DIRETO para %s! Entrada violenta!" % player_name)
		SFX.play_whistle()
		_eject_player(gs, roster_idx)
		return "RED"
	elif foul_info.get("is_yellow", false):
		var count = gs.yellow_cards.get(roster_idx, 0) + 1
		gs.yellow_cards[roster_idx] = count
		if count >= 2:
			gs.push_log("🟨🟥 SEGUNDO AMARELO! %s foi expulso do jogo!" % player_name)
			SFX.play_whistle()
			_eject_player(gs, roster_idx)
			return "RED"
		else:
			gs.push_log("🟨 Cartão Amarelo para %s!" % player_name)
			return "YELLOW"
	return "NONE"

static func _eject_player(gs: Node, roster_idx: int) -> void:
	if not (roster_idx in gs.players_out):
		gs.players_out.append(roster_idx)
	
	# Aplica a reorganização do lineup empurrando o expulso para a última zona
	gs._apply_lineup()
