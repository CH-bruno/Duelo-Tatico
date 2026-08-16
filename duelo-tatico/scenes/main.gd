extends Control
# Main.gd — Controlador principal da Partida

@onready var zone_label: Label = $VBoxContainer/TopHeader/ZoneLabel
@onready var options_button: Button = $VBoxContainer/TopHeader/OptionsButton
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var pass_container: HBoxContainer = $VBoxContainer/PassContainer
@onready var dri_button: Button = $VBoxContainer/HBoxContainer/DriButton
@onready var feint_button: Button = $VBoxContainer/HBoxContainer/FeintButton
@onready var sho_button: Button = $VBoxContainer/HBoxContainer/ShoButton
@onready var long_shot_button: Button = $VBoxContainer/HBoxContainer/LongShotButton
@onready var next_match: Button = $VBoxContainer/NextMatchButton
@onready var goal_flash: ColorRect = $GoalFlash
@onready var defense_container: HBoxContainer = $VBoxContainer/DefenseContainer
@onready var intercept_button: Button = $VBoxContainer/DefenseContainer/InterceptButton
@onready var tackle_button: Button = $VBoxContainer/DefenseContainer/TackleButton
@onready var block_button: Button = $VBoxContainer/DefenseContainer/BlockButton
@onready var attack_container: HBoxContainer = $VBoxContainer/HBoxContainer

const AppTheme = preload("res://scripts/AppTheme.gd")
const OptionsMenuScene = preload("res://scenes/OptionsMenu.tscn")
const MatchStatsScene = preload("res://scenes/MatchStats.tscn")
const SubstitutionDialogScene = preload("res://scenes/SubstitutionDialog.tscn")
const HalftimeDialogScript = preload("res://scenes/HalftimeDialog.gd")
const MatchLogDialogScript = preload("res://scripts/MatchLogDialog.gd")
const UIUtils = preload("res://scripts/UIUtils.gd")

var sub_button: Button = null
var log_button: Button = null
var _last_goals = 0
var _last_ai_goals = 0
var stats_opened := false

var match_ui: MatchUI
var match_anims: MatchAnimations


func _ready():
	theme = AppTheme.build()
	SFX.play_music("res://assets/audio/music_match.mp3")
	SFX.play_whistle()

	_setup_top_header_buttons()
	_init_submodules()
	_connect_signals()

	_last_goals = GameState.goals
	_last_ai_goals = GameState.ai_goals

	refresh_ui()


func _setup_top_header_buttons() -> void:
	var header = options_button.get_parent()
	
	# Estiliza o botão de Opções de forma bem compacta
	options_button.text = "⚙ Opções"
	options_button.custom_minimum_size = Vector2(90, 30)
	options_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Cria o botão de Subs apenas se ele ainda não existir
	if sub_button == null:
		sub_button = Button.new()
		sub_button.name = "SubButton"
		sub_button.theme_type_variation = "GhostButton"
		sub_button.custom_minimum_size = Vector2(90, 30)
		sub_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		header.add_child(sub_button)
		header.move_child(sub_button, options_button.get_index())

	sub_button.text = "🔄 Subs (%d)" % GameState.substitutions_left

	# 📜 Botão de Histórico completo da narração
	if log_button == null:
		log_button = Button.new()
		log_button.name = "LogButton"
		log_button.theme_type_variation = "GhostButton"
		log_button.text = "📜 Histórico"
		log_button.custom_minimum_size = Vector2(100, 30)
		log_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		header.add_child(log_button)
		header.move_child(log_button, options_button.get_index())


func _init_submodules() -> void:
	match_anims = MatchAnimations.new()
	add_child(match_anims)
	match_anims.setup(goal_flash, $VBoxContainer)

	match_ui = MatchUI.new()
	add_child(match_ui)
	match_ui.setup({
		"zone_label": zone_label,
		"stats_label": stats_label,
		"log_label": log_label,
		"pass_container": pass_container,
		"dri_button": dri_button,
		"feint_button": feint_button,
		"sho_button": sho_button,
		"long_shot_button": long_shot_button,
		"next_match": next_match,
		"options_button": options_button,
		"defense_container": defense_container,
		"intercept_button": intercept_button,
		"tackle_button": tackle_button,
		"block_button": block_button,
		"attack_container": attack_container
	})

	var all_buttons = [
		dri_button, feint_button, sho_button, long_shot_button,
		next_match, options_button, intercept_button, tackle_button, block_button
	]
	if sub_button:
		all_buttons.append(sub_button)
	if log_button:
		all_buttons.append(log_button)

	for btn in all_buttons:
		if btn:
			UIUtils.add_press_feedback(btn)


func _connect_signals() -> void:
	GameState.state_changed.connect(refresh_ui)
	if GameState.has_signal("match_event_triggered"):
		GameState.match_event_triggered.connect(_on_match_event)

	dri_button.pressed.connect(func(): GameState.attempt("DRI"))
	feint_button.pressed.connect(func(): GameState.attempt("FEINT"))
	sho_button.pressed.connect(func(): GameState.attempt("SHO"))
	long_shot_button.pressed.connect(func(): GameState.attempt("LONG_SHO"))

	next_match.pressed.connect(_on_next_match_pressed)
	options_button.pressed.connect(_on_options_pressed)
	
	if sub_button:
		# ✅ Conexão segura via lambda para evitar inconsistências de parâmetros
		sub_button.pressed.connect(func(): _open_substitutions_dialog(false))

	if log_button:
		log_button.pressed.connect(_open_log_dialog)

	intercept_button.pressed.connect(func(): GameState.defend("INTERCEPT"))
	tackle_button.pressed.connect(func(): GameState.defend("TACKLE"))
	block_button.pressed.connect(func(): GameState.defend("BLOCK"))


func refresh_ui():
	match_ui.refresh()
	match_anims.update_momentum(GameState.momentum_bonus)

	if sub_button:
		sub_button.text = "🔄 Subs (%d)" % GameState.substitutions_left
		sub_button.disabled = GameState.match_over or GameState.substitutions_left <= 0

	if GameState.goals > _last_goals:
		match_anims.flash(AppTheme.GOLD)
	elif GameState.ai_goals > _last_ai_goals:
		match_anims.flash(AppTheme.DANGER)

	_last_goals = GameState.goals
	_last_ai_goals = GameState.ai_goals

	if GameState.match_over and not stats_opened:
		stats_opened = true
		show_match_stats()


func _on_match_event(event_name: String, details: Dictionary):
	match event_name:
		"HALF_TIME":
			_show_halftime_dialog(details)
		"YELLOW_CARD":
			match_anims.flash(AppTheme.WARNING)
		"FOUL":
			match_anims.flash(Color(0.8, 0.8, 0.8, 0.3))


func _show_halftime_dialog(details: Dictionary) -> void:
	if has_node("HalftimeDialog"):
		return

	var dialog = ColorRect.new()
	dialog.name = "HalftimeDialog"
	dialog.set_script(HalftimeDialogScript)
	add_child(dialog)

	dialog.setup(details)

	dialog.continued.connect(func():
		if GameState.can_substitute():
			_open_substitutions_dialog(true)
		else:
			MatchFlow.start_second_half(GameState)
			refresh_ui()
	)


func _open_substitutions_dialog(is_halftime: bool = false) -> void:
	if has_node("SubstitutionDialog"):
		return

	var dialog = SubstitutionDialogScene.instantiate()
	add_child(dialog)
	dialog.setup()
	
	dialog.closed.connect(func():
		# Dispara a saída de bola do 2º tempo apenas se veio do intervalo
		if is_halftime or (GameState.round_num == int(GameState.MAX_ROUNDS / 2.0) and not GameState.first_half):
			MatchFlow.start_second_half(GameState)
		refresh_ui()
	)


# 📜 Abre o modal com o histórico completo da narração da partida.
# Não precisa de .tscn própria — mesmo padrão do HalftimeDialog, script
# anexado direto num Control novo.
func _open_log_dialog() -> void:
	if has_node("MatchLogDialog"):
		return

	var dialog = Control.new()
	dialog.name = "MatchLogDialog"
	dialog.set_script(MatchLogDialogScript)
	add_child(dialog)

	dialog.closed.connect(func():
		pass
	)


func show_match_stats():
	var stats_overlay = MatchStatsScene.instantiate()
	add_child(stats_overlay)


func _on_next_match_pressed():
	stats_opened = false
	if GameState.game_mode == GameState.GameMode.CAMPAIGN:
		GameState.next_match()
		get_tree().change_scene_to_file("res://scenes/campaign_menu.tscn")
	else:
		GameState.next_challenge_round()


func _on_options_pressed():
	if has_node("OptionsMenu"):
		return
	var menu = OptionsMenuScene.instantiate()
	menu.name = "OptionsMenu"
	add_child(menu)
