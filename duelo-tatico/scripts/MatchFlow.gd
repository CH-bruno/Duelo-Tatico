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
