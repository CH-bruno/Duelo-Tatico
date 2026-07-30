class_name MatchFlow
extends Node
# MatchFlow.gd — Controle do fluxo de jogo, intervalos e transição de partidas.

static func half_time(gs: Node) -> void:
	gs.push_log("🔔 Fim do 1º Tempo! As equipes vão para o intervalo.")
	
	# Processa a recuperação de stamina do intervalo no vestiário
	LineupManager.process_halftime_recovery(gs)

	# Passa o placar e estatísticas corretas no evento de UI
	var details = {
		"goals": gs.goals,
		"ai_goals": gs.ai_goals
	}

	gs.emit_match_event("HALF_TIME", details)
	gs.state_changed.emit()


static func start_second_half(gs: Node) -> void:
	gs.push_log("🏁 Apito do 2º Tempo! O adversário tem a saída de bola.")
	MatchEngine.kickoff(gs, false)


static func _reset_common_stats(gs: Node) -> void:
	gs.goals = 0
	gs.ai_goals = 0
	gs.turnovers = 0
	gs.streak = 0
	gs.round_num = 0
	gs.match_over = false
	gs.first_half = true
	gs.zone_idx = 0
	gs.active_idx = 0
	gs.possession = gs.Possession.PLAYER
	gs.turn_state = gs.TurnState.PLAYER_ATTACK
	
	# Limpa os logs da partida anterior
	gs.log_messages.clear()
	
	gs.reset_substitutions()
	gs.reset_match_stats()
	
	# ✅ Aplica a regra de fadiga pós-jogo: titulares mantêm o desgaste e reservas recuperam 100%
	gs.apply_match_fatigue()


static func next_match(gs: Node) -> void:
	_reset_common_stats(gs)
	
	if gs.campaign_stage < gs.MAX_CAMPAIGN_STAGE:
		gs.campaign_stage += 1
		
	MatchEngine.kickoff(gs, true)


static func next_challenge_round(gs: Node) -> void:
	_reset_common_stats(gs)
	
	gs.challenge_wins += 1
	if gs.challenge_wins > gs.challenge_best:
		gs.challenge_best = gs.challenge_wins
		
	MatchEngine.kickoff(gs, true)


static func reset_game(gs: Node) -> void:
	_reset_common_stats(gs)
	gs.campaign_stage = 1
	gs.challenge_wins = 0
	
	# Reinício total de um novo jogo: restaura stamina de todo o elenco
	gs.reset_all_stamina()
	
	MatchEngine.kickoff(gs, true)
