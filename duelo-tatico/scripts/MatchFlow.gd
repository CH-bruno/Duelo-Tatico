class_name MatchFlow
extends Node
# MatchFlow.gd — Controle do fluxo de jogo, intervalos e transição de partidas.

static func half_time(gs: Node) -> void:
	gs.push_log("🔔 Fim do 1º Tempo! As equipes vão para o intervalo.")
	
	# Processa a recuperação de stamina do intervalo no vestiário
	LineupManager.process_halftime_recovery(gs)
	LineupManager.process_gk_halftime_recovery(gs)

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
	# 1. Aplica a fadiga pós-partida com a lista atual de quem jogou
	gs.apply_match_fatigue()
	gs.apply_gk_match_fatigue()

	# 2. Reseta o estado da partida
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
	
	gs.log_messages.clear()
	
	# 3. Zera os cartões e expulsões do jogo anterior
	gs.reset_substitutions()

# 🏁 Chamado quando a partida REALMENTE começa (depois que o jogador já
# confirmou/ajustou a escalação). Só agora fixamos "quem está jogando" e
# damos o pontapé inicial — assim trocas feitas na tela de Escalação entram
# corretas na lista usada por apply_match_fatigue no fim da partida.
static func _start_match(gs: Node) -> void:
	gs.reset_match_stats()
	gs._apply_opponent_lineup()
	MatchEngine.kickoff(gs, true)

static func next_match(gs: Node) -> void:
	_reset_common_stats(gs)
	
	if gs.campaign_stage < gs.MAX_CAMPAIGN_STAGE:
		gs.campaign_stage += 1
	
	# ⚠️ NÃO chama _start_match aqui: o jogador ainda vai passar pela
	# Campaign Menu / tela de Escalação. O pontapé inicial só acontece em
	# start_campaign_match(), chamado quando ele confirma e aperta "Iniciar".

static func start_campaign_match(gs: Node) -> void:
	_start_match(gs)

static func next_challenge_round(gs: Node) -> void:
	_reset_common_stats(gs)
	
	gs.challenge_wins += 1
	if gs.challenge_wins > gs.challenge_best:
		gs.challenge_best = gs.challenge_wins
	
	# Modo Desafio não passa por tela de escalação entre rodadas, então o
	# pontapé pode acontecer imediatamente.
	_start_match(gs)

static func reset_game(gs: Node) -> void:
	# ⚡ REINÍCIO TOTAL: Restaura a energia de 100% de todo o elenco
	gs.reset_all_stamina()
	gs.reset_all_gk_stamina()

	# 📉 Reseta a progressão de nível/XP — sem isso, o nível do time
	# "vazava" de uma campanha pra outra (ex: terminar no nível 6 e
	# começar a próxima campanha já nesse nível, em vez do 1).
	gs.level = 1
	gs.xp = 0
	gs.pending_xp = 0
	gs.xp_to_next = 20

	_reset_common_stats(gs)
	gs.campaign_stage = 1
	gs.challenge_wins = 0
	
	_start_match(gs)
