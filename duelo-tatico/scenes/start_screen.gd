extends Control

const AppTheme = preload("res://scripts/AppTheme.gd")

@onready var campaign_button = $CenterContainer/VBoxContainer/CampaignButton
@onready var challenge_button = $CenterContainer/VBoxContainer/ChallengeButton
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton


func _ready():
	theme = AppTheme.build()

	campaign_button.pressed.connect(_campaign)
	challenge_button.pressed.connect(_challenge)
	quit_button.pressed.connect(func(): get_tree().quit())

	quit_button.theme_type_variation = "GhostButton"  # ação secundária, menos peso visual


func _campaign():
	GameState.game_mode = GameState.GameMode.CAMPAIGN
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")


func _challenge():
	GameState.game_mode = GameState.GameMode.CHALLENGE
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
