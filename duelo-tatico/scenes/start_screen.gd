extends Control
# StartScreen.gd — Menu Principal com Moldura e Fundo Animado do Gramado.

const AppTheme = preload("res://scripts/AppTheme.gd")

@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var campaign_button: Button = $CenterContainer/VBoxContainer/CampaignButton
@onready var challenge_button: Button = $CenterContainer/VBoxContainer/ChallengeButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

var ball_t: float = 0.0
var ball_direction: int = 1


func _ready():
	theme = AppTheme.build()
	SFX.play_music("res://audio/music_menu.mp3")

	continue_button.visible = SaveSystem.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	campaign_button.pressed.connect(_campaign)
	challenge_button.pressed.connect(_challenge)
	quit_button.pressed.connect(func(): get_tree().quit())

	_apply_card_frame()
	_apply_button_styles()


func _process(delta: float) -> void:
	ball_t += delta * 0.6 * ball_direction
	if ball_t >= 1.0:
		ball_t = 1.0
		ball_direction = -1
	elif ball_t <= 0.0:
		ball_t = 0.0
		ball_direction = 1
	queue_redraw()


func _draw():
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2.0
	var center_y = viewport_size.y / 2.0

	# 1. Fundo do Gramado Escuro
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.07, 0.12, 0.09))

	# 2. Linhas do Campo
	var line_color = Color(1.0, 1.0, 1.0, 0.08)
	draw_line(Vector2(center_x, 0), Vector2(center_x, viewport_size.y), line_color, 2.0)
	draw_arc(Vector2(center_x, center_y), 110.0, 0.0, TAU, 32, line_color, 2.0)

	# 3. Jogadores e Bola Animada no Fundo
	var p1_pos = Vector2(center_x - 260, center_y + 160)
	var p2_pos = Vector2(center_x + 260, center_y + 160)

	draw_circle(p1_pos, 10, Color(0.2, 0.5, 0.8, 0.5))
	draw_circle(p2_pos, 10, Color(0.8, 0.3, 0.3, 0.5))

	var current_ball_pos = p1_pos.lerp(p2_pos, ball_t)
	current_ball_pos.y -= sin(ball_t * PI) * 22.0
	draw_circle(current_ball_pos, 6, Color(1.0, 1.0, 0.85))


func _apply_card_frame():
	var vbox = $CenterContainer/VBoxContainer
	if vbox and not $CenterContainer.has_node("MenuCardPanel"):
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.05, 0.09, 0.06, 0.85)
		card_style.border_color = Color(0.85, 0.65, 0.25, 0.7)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(12)
		card_style.set_content_margin_all(20)

		var panel = PanelContainer.new()
		panel.name = "MenuCardPanel"
		panel.add_theme_stylebox_override("panel", card_style)
		
		var center_container = $CenterContainer
		center_container.remove_child(vbox)
		panel.add_child(vbox)
		center_container.add_child(panel)

		vbox.add_theme_constant_override("separation", 10)


func _apply_button_styles():
	var buttons = [continue_button, campaign_button, challenge_button, quit_button]
	
	for btn in buttons:
		if btn:
			btn.custom_minimum_size = Vector2(250, 36)
			_add_press_feedback(btn)

	challenge_button.theme_type_variation = "GhostButton"
	quit_button.theme_type_variation = "GhostButton"


# ---------- FLUXO DAS CENAS ----------

func _on_continue_pressed():
	if SaveSystem.load_game():
		get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")

func _on_new_game_pressed():
	SaveSystem.delete_save()
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")

func _campaign():
	GameState.game_mode = GameState.GameMode.CAMPAIGN
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")

func _challenge():
	GameState.game_mode = GameState.GameMode.CHALLENGE
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

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
