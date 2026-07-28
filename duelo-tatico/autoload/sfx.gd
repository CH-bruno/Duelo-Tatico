extends Node
# SFX.gd — Gerenciamento de Áudio Polifônico com Ducking (Efeito de Prioridade de Áudio)

var music: AudioStreamPlayer = null
var sound_cache: Dictionary = {}
var _duck_tween: Tween


func _ready():
	_ensure_music_player()


func _ensure_music_player():
	if music == null:
		music = AudioStreamPlayer.new()
		music.bus = "Master"
		add_child(music)


# Toca um som com opção de "Ducking" (abaixar a torcida/música enquanto toca)
func play_sound(path: String, volume_db: float = 0.0, duck_music: bool = false):
	if not ResourceLoader.exists(path):
		print_verbose("[SFX] Arquivo de áudio não encontrado: ", path)
		return

	var stream: AudioStream = sound_cache.get(path)
	if stream == null:
		stream = load(path)
		sound_cache[path] = stream

	if stream:
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.stream = stream
		sfx_player.bus = "Master"
		sfx_player.volume_db = volume_db
		add_child(sfx_player)
		sfx_player.play()
		
		# Se for um som importante (Juiz / Gol), reduz o volume da torcida/música temporariamente
		if duck_music:
			_apply_music_ducking(stream.get_length())

		# Libera o nó da memória assim que o som terminar
		sfx_player.finished.connect(sfx_player.queue_free)


func _apply_music_ducking(duration: float):
	if music == null or not music.playing:
		return

	if _duck_tween and _duck_tween.is_running():
		_duck_tween.kill()

	_duck_tween = create_tween()
	
	# 1. Abaixa o volume da torcida/música rapidamente (para -22 dB)
	_duck_tween.tween_property(music, "volume_db", -22.0, 0.1)
	
	# 2. Mantém baixo durante a duração do som do juiz/gol
	_duck_tween.tween_interval(max(0.5, duration))
	
	# 3. Retorna suavemente para o volume normal de fundo (-10 dB)
	_duck_tween.tween_property(music, "volume_db", -10.0, 0.6)


func play_music(path: String):
	_ensure_music_player()

	if not ResourceLoader.exists(path):
		print_verbose("[SFX] Música não encontrada: ", path)
		return

	var stream = load(path)
	if stream == null:
		return

	if music.stream == stream and music.playing:
		return

	music.stop()
	music.stream = stream
	music.volume_db = -10.0
	music.play()


# ---------- Sons da Partida ----------

func play_pass_success():
	play_sound("res://assets/audio/pass.mp3")

func play_dribble():
	play_sound("res://assets/audio/dribble.mp3" if ResourceLoader.exists("res://assets/audio/dribble.mp3") else "res://assets/audio/pass.mp3")

func play_turnover():
	play_sound("res://assets/audio/turnover.mp3" if ResourceLoader.exists("res://assets/audio/turnover.mp3") else "res://assets/audio/pass.mp3")

func play_intercept():
	play_sound("res://assets/audio/intercept.mp3" if ResourceLoader.exists("res://assets/audio/intercept.mp3") else "res://assets/audio/pass.mp3")

func play_tackle():
	play_sound("res://assets/audio/tackle.mp3" if ResourceLoader.exists("res://assets/audio/tackle.mp3") else "res://assets/audio/pass.mp3")

func play_block():
	play_sound("res://assets/audio/block.mp3" if ResourceLoader.exists("res://assets/audio/block.mp3") else "res://assets/audio/pass.mp3")

func play_defense_fail():
	play_sound("res://assets/audio/fail.mp3" if ResourceLoader.exists("res://assets/audio/fail.mp3") else "res://assets/audio/pass.mp3")

func play_goal():
	play_sound("res://assets/audio/goal.mp3", 3.0, true)

func play_whistle():
	play_sound("res://assets/audio/whistle.mp3", 1.0, true)

func play_whistle_final():
	play_sound("res://assets/audio/whistle_final.mp3" if ResourceLoader.exists("res://assets/audio/whistle_final.mp3") else "res://assets/audio/whistle.mp3", 1.0, true)
