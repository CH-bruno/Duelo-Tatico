extends Node
# Autoload (singleton) que gera efeitos sonoros simples por código,
# sem precisar de nenhum arquivo de áudio.

func _play_tone(freq: float, duration: float, volume := 0.25) -> void:
	var player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = duration + 0.1
	player.stream = gen
	add_child(player)
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count = int(gen.mix_rate * duration)
	for i in range(sample_count):
		var t = float(i) / gen.mix_rate
		var envelope = 1.0 - (t / duration)  # o som some suavemente no final, sem "clique"
		var sample = sin(TAU * freq * t) * volume * envelope
		playback.push_frame(Vector2(sample, sample))

	await get_tree().create_timer(duration + 0.2).timeout
	player.queue_free()


func play_pass_success() -> void:
	_play_tone(700.0, 0.08, 0.18)


func play_turnover() -> void:
	_play_tone(180.0, 0.18, 0.2)


func play_goal() -> void:
	# Um pequeno arpejo ascendente (dó-mi-sol), soa "comemorativo".
	_play_tone(523.0, 0.12, 0.22)
	await get_tree().create_timer(0.1).timeout
	_play_tone(659.0, 0.12, 0.22)
	await get_tree().create_timer(0.1).timeout
	_play_tone(784.0, 0.25, 0.24)


func play_whistle() -> void:
	_play_tone(1400.0, 0.35, 0.15)
