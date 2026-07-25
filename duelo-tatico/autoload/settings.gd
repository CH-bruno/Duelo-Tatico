extends Node
# Autoload — configurações do aplicativo (volume, etc.), separadas do
# save da campanha: isso persiste mesmo sem nenhuma partida em andamento.

const SETTINGS_PATH = "user://settings.json"

var master_volume: float = 1.0  # 0.0 a 1.0


func _ready():
	load_settings()
	apply_volume()


func apply_volume() -> void:
	var idx = AudioServer.get_bus_index("Master")
	if idx == -1:
		return
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))


func set_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_volume()


func save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"master_volume": master_volume}))
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		master_volume = parsed.get("master_volume", 1.0)
