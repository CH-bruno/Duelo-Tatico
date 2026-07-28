class_name MatchFlow
extends Node

# Avança para a próxima partida da Campanha
static func next_match(gs: Node) -> void:
	if not gs.match_over or gs.goals <= gs.ai_goals:
		return
	if gs.campaign_stage >= gs.MAX_CAMPAIGN_STAGE:
		return

	gs.apply_match_fatigue()
	gs._apply_lineup()

	gs.campaign_stage += 1
	gs.log_messages.clear()
	gs.reset_match_stats()
	gs.possession = gs.Possession.PLAYER
	
	gs.goals = 0
	gs.ai_goals = 0
	gs.turnovers = 0
	gs.round_num = 0
	gs.match_over = false
	gs.first_half = true
	gs.momentum_bonus = 0

	MatchEngine.kickoff(gs, true)

	gs.push_log("Fase %d iniciada!" % gs.campaign_stage)
	gs.push_log("A bola está com o %s." % gs.active_player()["name"])
	SFX.play_whistle()
	SaveSystem.save_game()
	gs.state_changed.emit()


# Avança no Modo Desafio (Restaura stamina para 100% para o novo desafio)
static func next_challenge_round(gs: Node) -> void:
	if not gs.match_over or gs.goals <= gs.ai_goals:
		return

	gs.challenge_wins += 1
	gs.challenge_best = max(gs.challenge_best, gs.challenge_wins)
	gs.log_messages.clear()
	gs.reset_match_stats()
	gs.possession = gs.Possession.PLAYER

	# Reseta a stamina de todos para 100% a cada nova rodada do Desafio
	gs.reset_all_stamina()
	gs._apply_lineup()

	gs.goals = 0
	gs.ai_goals = 0
	gs.turnovers = 0
	gs.round_num = 0
	gs.match_over = false
	gs.first_half = true
	gs.momentum_bonus = 0

	MatchEngine.kickoff(gs, true)

	gs.push_log("Sobrevivência: %d vitória(s) seguida(s)! O adversário fica mais forte." % gs.challenge_wins)
	SFX.play_whistle()
	gs.state_changed.emit()


# Processamento do Intervalo da Partida
static func half_time(gs: Node) -> void:
	SFX.play_whistle()
	gs.push_log("⏱ Apito do árbitro: Fim do Primeiro Tempo!")

	# Recuperação proporcional ao desgaste acumulado no 1º Tempo
	LineupManager.process_halftime_recovery(gs)

	gs.momentum_bonus = 0
	gs.ai_momentum = 0
	gs.streak = 0

	MatchEngine.kickoff(gs, false)

	gs.emit_match_event("HALF_TIME", {
		"goals": gs.goals,
		"ai_goals": gs.ai_goals,
		"stage": gs.difficulty_stage()
	})


# Reset Completo do Jogo (Novo Jogo do zero)
static func reset_game(gs: Node) -> void:
	gs.level = 1
	gs.xp = 0
	gs.pending_xp = 0
	gs.xp_to_next = 20
	gs.starters = [0, 2, 4, 6]
	
	# Reseta a stamina de todos os jogadores da base para 100%
	gs.reset_all_stamina()
	gs._apply_lineup()
	gs.possession = gs.Possession.PLAYER
	
	gs.goals = 0
	gs.ai_goals = 0
	gs.turnovers = 0
	gs.round_num = 0
	gs.match_over = false
	gs.first_half = true
	gs.momentum_bonus = 0
	gs.campaign_stage = 1
	gs.challenge_wins = 0
	gs.log_messages = []
	
	gs.reset_match_stats()
	MatchEngine.kickoff(gs, true)
	
	gs.push_log("Nova partida iniciada. A bola está com o %s." % gs.active_player()["name"])
	gs.state_changed.emit()
