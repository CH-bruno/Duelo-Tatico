class_name MatchFlow
extends Node

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
	
	MatchEngine.kickoff(gs)
	gs.goals = 0
	gs.ai_goals = 0
	gs.turnovers = 0
	gs.round_num = 0
	gs.match_over = false
	gs.momentum_bonus = 0

	gs.push_log("Fase %d iniciada!" % gs.campaign_stage)
	gs.push_log("A bola está com o %s." % gs.active_player()["name"])
	SFX.play_whistle()
	SaveSystem.save_game()
	gs.state_changed.emit()


static func next_challenge_round(gs: Node) -> void:
	if not gs.match_over or gs.goals <= gs.ai_goals:
		return

	gs.apply_match_fatigue()
	gs._apply_lineup()

	gs.challenge_wins += 1
	gs.challenge_best = max(gs.challenge_best, gs.challenge_wins)
	gs.log_messages.clear()
	gs.reset_match_stats()
	gs.possession = gs.Possession.PLAYER

	MatchEngine.kickoff(gs)
	gs.goals = 0
	gs.ai_goals = 0
	gs.turnovers = 0
	gs.round_num = 0
	gs.match_over = false
	gs.momentum_bonus = 0

	gs.push_log("Sobrevivência: %d vitória(s) seguida(s)! O adversário fica mais forte." % gs.challenge_wins)
	SFX.play_whistle()
	gs.state_changed.emit()

static func half_time(gs: Node) -> void:
	SFX.play_whistle()
	gs.push_log("⏱ Apito do árbitro: Fim do Primeiro Tempo!")

	# 1. Recuperação parcial de stamina no vestiário (entre 8 e 14)
	for i in range(gs.starters.size()):
		var roster_idx = gs.starters[i]
		var current_st = gs.get_stamina(roster_idx)
		var recovery = randf_range(8.0, 14.0)
		gs.set_stamina(roster_idx, current_st + recovery)

	# 2. Reset de momentum e streak
	gs.momentum_bonus = 0
	gs.ai_momentum = 0
	gs.streak = 0

	# 3. Dá o pontapé inicial do 2º Tempo com o Rival (Mudança de Posse)
	MatchEngine.kickoff(gs, false)

	# 4. Notifica a Interface sobre o Intervalo
	gs.emit_match_event("HALF_TIME", {
		"goals": gs.goals,
		"ai_goals": gs.ai_goals,
		"stage": gs.difficulty_stage()
	})

static func reset_game(gs: Node) -> void:
	gs.level = 1
	gs.xp = 0
	gs.pending_xp = 0
	gs.xp_to_next = 20
	gs.starters = [0, 2, 4, 6]
	
	gs.init_stamina()
	gs._apply_lineup()
	gs.possession = gs.Possession.PLAYER
	
	MatchEngine.kickoff(gs)
	gs.goals = 0
	gs.ai_goals = 0
	gs.turnovers = 0
	gs.round_num = 0
	gs.match_over = false
	gs.momentum_bonus = 0
	gs.campaign_stage = 1
	gs.challenge_wins = 0
	gs.log_messages = []
	
	gs.reset_match_stats()
	gs.push_log("Nova partida iniciada. A bola está com o %s." % gs.active_player()["name"])
	gs.state_changed.emit()
