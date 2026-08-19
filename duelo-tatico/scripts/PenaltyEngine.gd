class_name PenaltyEngine
extends RefCounted
# PenaltyEngine.gd — Cobrança de pênalti em duas fases: lado de quem bate,
# depois lado de quem defende. Se o goleiro acerta o lado, vira duelo de
# atributos; se erra, o cobrador fica muito favorito.
# Serve tanto pro pênalti normal (falta na área) quanto pra disputa de
# pênaltis (empate no fim da partida) — só muda a origem do cobrador e o
# que acontece depois do resultado (volta ao jogo x segue a disputa).

const SIDES = ["ESQUERDA", "CENTRO", "DIREITA"]


# 🚨 Início do pênalti NORMAL (falta na área) — chamado no lugar do antigo
# execute_penalty(). Se você cobra, aguarda sua escolha de lado (UI mostra
# os 3 botões). Se a IA cobra, ela escolhe sozinha na hora.
static func start_penalty(gs: Node, is_player_kicker: bool) -> void:
	gs.push_log(Narration.PENALTY_CALL.pick_random())
	_start_kick(gs, is_player_kicker)


# 🎯 Início de UMA cobrança da disputa de pênaltis (chamado por
# GameState.start_shootout() / shootout_advance_or_finish()).
static func start_shootout_kick(gs: Node) -> void:
	var is_player_kicker = gs.shootout_kicker_is_player()
	var kicker = gs.shootout_kicker_dict()

	gs.push_log("🎯 Cobrança %d — %s (%s) vai bater!" % [
		gs.shootout_turn + 1, kicker.get("name", "Jogador"), kicker.get("role", "")
	])

	_start_kick(gs, is_player_kicker)


static func _start_kick(gs: Node, is_player_kicker: bool) -> void:
	gs.penalty_is_player_kicker = is_player_kicker
	gs.penalty_kick_side = ""
	gs.penalty_last_result = ""

	if is_player_kicker:
		gs.penalty_phase = gs.PenaltyPhase.AWAITING_KICK_SIDE
		gs.state_changed.emit()
	else:
		var side = SIDES.pick_random()
		gs.penalty_kick_side = side

		var kicker = gs.shootout_kicker_dict() if gs.in_shootout else gs.ai_active_player()
		gs.push_log(AIOpponent._format_narration(Narration.PENALTY_KICK_ANNOUNCE.pick_random(), [
			kicker.get("name", "Jogador"), kicker.get("role", ""), side
		]))

		_proceed_to_gk_phase(gs)


# 🎯 Chamado pela UI quando VOCÊ é quem cobra e escolhe o lado.
static func choose_kick_side(gs: Node, side: String) -> void:
	if gs.penalty_phase != gs.PenaltyPhase.AWAITING_KICK_SIDE:
		return

	gs.penalty_kick_side = side

	var kicker = gs.shootout_kicker_dict() if gs.in_shootout else gs.active_player()
	gs.push_log(AIOpponent._format_narration(Narration.PENALTY_KICK_ANNOUNCE.pick_random(), [
		kicker.get("name", "Jogador"), kicker.get("role", ""), side
	]))

	_proceed_to_gk_phase(gs)


static func _proceed_to_gk_phase(gs: Node) -> void:
	if gs.penalty_is_player_kicker:
		# 🥅 Você cobra — o goleiro da IA "adivinha" sozinho, na hora.
		# Chance de acertar o lado escala com o POS dele.
		var ai_gk = gs.current_opponent_team().get("goalkeeper", {})
		var guess_chance = clampi(int(round(30 + (ai_gk.get("POS", 50) - 50) * 0.5)), 15, 70)
		var gk_side = gs.penalty_kick_side if randi_range(1, 100) <= guess_chance else _random_other_side(gs.penalty_kick_side)
		resolve_penalty(gs, gk_side)
	else:
		# 🧤 A IA cobra — é o SEU goleiro que escolhe (UI mostra os 3 botões).
		gs.penalty_phase = gs.PenaltyPhase.AWAITING_GK_SIDE
		gs.state_changed.emit()


# 🧤 Chamado pela UI quando o SEU goleiro é quem defende e você escolhe o lado.
static func choose_gk_side(gs: Node, side: String) -> void:
	if gs.penalty_phase != gs.PenaltyPhase.AWAITING_GK_SIDE:
		return
	resolve_penalty(gs, side)


static func _random_other_side(exclude: String) -> String:
	var options = SIDES.filter(func(s): return s != exclude)
	return options.pick_random()


# ⚖️ Resolve o pênalti conhecendo os dois lados (cobrador e goleiro).
static func resolve_penalty(gs: Node, gk_side: String) -> void:
	gs.penalty_phase = gs.PenaltyPhase.NONE

	var is_player_kicker = gs.penalty_is_player_kicker
	var kick_side = gs.penalty_kick_side

	var kicker_dict = gs.shootout_kicker_dict() if gs.in_shootout else (gs.active_player() if is_player_kicker else gs.ai_active_player())
	var k_name = kicker_dict.get("name", "Jogador")
	var k_role = kicker_dict.get("role", "")
	var sho_stat = float(kicker_dict.get("SHO", 50))
	var trait_bonus = float(RosterData.trait_bonus(kicker_dict, "SHO"))

	var guessed_right = (gk_side == kick_side)

	var gk_stat := 50.0
	var gk_name := "o goleiro"
	if is_player_kicker:
		var ai_gk = gs.current_opponent_team().get("goalkeeper", {})
		gk_stat = ai_gk.get("REF", 50) * 0.6 + ai_gk.get("POS", 50) * 0.4
		gk_name = ai_gk.get("name", "o goleiro")
	else:
		var gk = gs.active_goalkeeper()
		gk_stat = gk.get("REF", 50) * 0.6 + gk.get("POS", 50) * 0.4
		gk_name = gk.get("name", "o goleiro")

	var convert_chance: int
	if guessed_right:
		convert_chance = clampi(int(round(60 + (sho_stat - 50) * 0.5 + trait_bonus - (gk_stat - 50) * 0.7)), 25, 90)
		gs.push_log(AIOpponent._format_narration(Narration.PENALTY_GK_GUESSED_RIGHT.pick_random(), [gk_name]))
	else:
		convert_chance = clampi(int(round(88 + (sho_stat - 50) * 0.2 + trait_bonus * 0.5)), 70, 97)
		gs.push_log(AIOpponent._format_narration(Narration.PENALTY_GK_GUESSED_WRONG.pick_random(), [gk_name]))

	var success = randi_range(1, 100) <= convert_chance

	# 🎬 Guarda a "revelação" pro modal desenhar antes de fechar
	gs.penalty_last_kick_side = kick_side
	gs.penalty_last_gk_side = gk_side
	gs.penalty_last_result = "GOAL" if success else "MISS"

	# 🧤 Consome energia do SEU goleiro sempre que ele é quem está defendendo
	if not is_player_kicker:
		gs.consume_gk_action_stamina("SAVE", not success)

	if success:
		# Na disputa, os "gols" reais só entram no placar oficial no fim
		# (shootout_record_result cuida da contagem da disputa em si)
		if not gs.in_shootout:
			if is_player_kicker:
				gs.goals += 1
				Stats.shot_on_target()
				Stats.add_goal(gs.active_idx)
			else:
				gs.ai_goals += 1

		gs.push_log(AIOpponent._format_narration(Narration.PENALTY_GOAL.pick_random(), [k_name, k_role]))
		SFX.play_goal()
	else:
		if not is_player_kicker:
			gs.push_log(AIOpponent._format_narration(MatchEngine.gk_save_narration(100 - convert_chance), [gk_name]))
		else:
			gs.push_log(AIOpponent._format_narration(Narration.PENALTY_FAIL.pick_random(), [k_name, k_role]))

		SFX.play_defense_fail()

	gs.penalty_kick_side = ""

	if gs.in_shootout:
		gs.shootout_record_result(is_player_kicker, success)
		gs.shootout_advance_or_finish()
	else:
		# Recomeço após o pênalti: bola vai para quem sofreu a cobrança
		MatchEngine.kickoff(gs, not is_player_kicker)
