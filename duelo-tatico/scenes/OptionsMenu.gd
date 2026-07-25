extends Control
# Menu de Opções elegante, compacto e proporcional em ambos os modos.

const AppTheme = preload("res://scripts/AppTheme.gd")

@onready var background: ColorRect = $Background
@onready var center_container: CenterContainer = $CenterContainer
@onready var panel: Panel = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Title
@onready var volume_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/VolumeLabel
@onready var volume_slider: HSlider = $CenterContainer/Panel/MarginContainer/VBoxContainer/VolumeSlider

@onready var reset_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ResetButton
@onready var save_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/SaveButton
@onready var save_quit_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/SaveQuitButton
@onready var menu_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/MenuButton
@onready var quit_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/QuitButton
@onready var close_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/CloseButton


func _ready():
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	theme = AppTheme.build()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fundo escurecido
	if background:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.color = Color(0, 0, 0, 0.75)
		background.mouse_filter = Control.MOUSE_FILTER_STOP

	if center_container:
		center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 1. Painel mais compacto (Altura se adapta ao número de botões)
	if panel:
		var panel_height = 420 if GameState.game_mode == GameState.GameMode.CAMPAIGN else 320
		panel.custom_minimum_size = Vector2(360, panel_height)
		
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.12, 0.18, 0.14)
		panel_style.border_color = Color(0.85, 0.65, 0.25)
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(8)
		panel_style.set_content_margin_all(16)
		panel.add_theme_stylebox_override("panel", panel_style)

	# 2. VBoxContainer COMPACTO (não estica os botões verticalmente!)
	var vbox = $CenterContainer/Panel/MarginContainer/VBoxContainer
	if vbox:
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # 👈 Impede os botões de ficarem "gordos"!
		vbox.add_theme_constant_override("separation", 6)     # 👈 Espaçamento fino e bonito entre eles

	# Título em Dourado
	if title_label:
		title_label.text = "OPÇÕES DO JOGO"
		title_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.25))
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Volume Slider
	if volume_slider:
		volume_slider.min_value = 0.0
		volume_slider.max_value = 1.0
		volume_slider.step = 0.05
		volume_slider.value = Settings.master_volume
		volume_slider.value_changed.connect(_on_volume_changed)

	_update_volume_label()

	# Configuração conforme Modo
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		reset_button.text = "Nova Partida"
		reset_button.visible = true
		save_button.visible = true
		save_quit_button.visible = true
	else:
		reset_button.text = "Reiniciar Desafio"
		reset_button.visible = true
		save_button.visible = false
		save_quit_button.visible = false

	save_button.text = "Salvar"
	save_quit_button.text = "Salvar e Menu"
	menu_button.text = "Voltar ao Menu"
	quit_button.text = "Sair do Jogo"
	close_button.text = "Fechar"

	# Conexões
	reset_button.pressed.connect(_on_new_game_pressed)
	save_button.pressed.connect(_on_save_pressed)
	save_quit_button.pressed.connect(_on_save_quit_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# 3. Estilos dos Botões:
	# Ações Principais (fundo preenchido)
	reset_button.theme_type_variation = ""
	save_button.theme_type_variation = ""
	save_quit_button.theme_type_variation = ""

	# Ações Secundárias (GhostButton = apenas contorno vazado, sem preenchimento pesado!)
	menu_button.theme_type_variation = "GhostButton"
	quit_button.theme_type_variation = "GhostButton"
	close_button.theme_type_variation = "GhostButton"

	# 4. Altura fixa fina para os botões principais (32px de altura)
	var main_buttons = [reset_button, save_button, save_quit_button, menu_button, quit_button]
	for btn in main_buttons:
		if btn:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.custom_minimum_size = Vector2(0, 32)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_add_press_feedback(btn)

	# 5. Botão "Fechar" delicado e centralizado no rodapé
	if close_button:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		close_button.custom_minimum_size = Vector2(140, 30)
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_add_press_feedback(close_button)


func _on_volume_changed(value: float) -> void:
	Settings.set_volume(value)
	Settings.save_settings()
	_update_volume_label()


func _update_volume_label() -> void:
	if volume_label:
		volume_label.text = "Volume: %d%%" % int(round(Settings.master_volume * 100))


func _on_new_game_pressed():
	get_tree().paused = false
	queue_free()

	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		GameState.reset_game()
		get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")
	else:
		GameState.reset_game()
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_save_pressed() -> void:
	SaveSystem.save_game()
	Settings.save_settings()

	save_button.text = "Salvo!"
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(save_button):
		save_button.text = "Salvar"


func _on_save_quit_pressed() -> void:
	SaveSystem.save_game()
	Settings.save_settings()
	get_tree().paused = false
	SFX.play_music("res://audio/music_menu.mp3")
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_menu_pressed():
	get_tree().paused = false
	queue_free()
	SFX.play_music("res://audio/music_menu.mp3")
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_close_pressed():
	get_tree().paused = false
	queue_free()


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
		queue_free()


func _add_press_feedback(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.06)
	)
	btn.button_up.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
