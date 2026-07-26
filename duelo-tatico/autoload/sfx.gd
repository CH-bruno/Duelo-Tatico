extends Node
# SFX.gd — Autoload de Gerenciamento de Áudio e Efeitos Sonoros do Jogo.

var player: AudioStreamPlayer = null
var music: AudioStreamPlayer = null


func _ready():
	_ensure_players()


func _ensure_players():
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
	if music == null:
		music = AudioStreamPlayer.new()
		music.bus = "Master"
		add_child(music)


func play_sound(path: String):
	_ensure_players()
	var stream: AudioStream = load(path)
	if not stream:
		return

	player.stream = stream
	player.play()


func play_music(path: String):
	_ensure_players()

	var stream = load(path)
	if stream == null:
		return

	if music.stream == stream and music.playing:
		return

	music.stop()
	music.stream = stream
	music.volume_db = -8
	music.play()


# ---------- Sons da Partida ----------

func play_pass_success():
	play_sound("res://audio/pass.mp3")


func play_dribble():
	play_sound("res://audio/pass.mp3")


func play_turnover():
	play_sound("res://audio/pass.mp3")


func play_intercept():
	play_sound("res://audio/pass.mp3")


func play_tackle():
	play_sound("res://audio/pass.mp3")


func play_block():
	play_sound("res://audio/pass.mp3")


func play_defense_fail():
	play_sound("res://audio/pass.mp3")


func play_goal():
	play_sound("res://audio/goal.mp3")


func play_whistle():
	play_sound("res://audio/whistle.mp3")


func play_whistle_final():
	play_sound("res://audio/whistle_final.mp3")
