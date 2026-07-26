extends Node
# Autoload — salva/carrega o progresso em disco (user://), como um
# arquivo JSON simples. Atualizado para salvar a Stamina dos atletas!

const SAVE_PATH = "user://savegame.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data = {
		"level": GameState.level,
		"xp": GameState.xp,
		"xp_to_next": GameState.xp_to_next,

		"starters": GameState.starters,
		"player_stamina": GameState.player_stamina, # 👈 Salva o cansaço!

		"campaign_stage": GameState.campaign_stage,
		"challenge_best": GameState.challenge_best,

		# caso o jogador saia durante uma campanha
		"game_mode": GameState.game_mode,

		# caso queira continuar exatamente da próxima fase
		"campaign_completed": GameState.campaign_stage > GameState.MAX_CAMPAIGN_STAGE
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func load_game() -> bool:
	if not has_save():
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	GameState.level = parsed.get("level", 1)
	GameState.xp = parsed.get("xp", 0)
	GameState.xp_to_next = parsed.get("xp_to_next", 20)

	GameState.starters = parsed.get("starters", [0, 2, 4, 6])

	GameState.campaign_stage = parsed.get("campaign_stage", 1)
	GameState.challenge_best = parsed.get("challenge_best", 0)
	GameState.game_mode = parsed.get("game_mode", GameState.GameMode.CAMPAIGN)

	# 👈 Carrega a stamina, convertendo as chaves do JSON (String) de volta para int
	var loaded_stamina = parsed.get("player_stamina", {})
	GameState.player_stamina.clear()
	for key in loaded_stamina:
		GameState.player_stamina[int(key)] = float(loaded_stamina[key])

	GameState._apply_lineup()

	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
