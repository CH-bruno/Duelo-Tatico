extends Control
# PenaltyDialog.gd — Modal da cobrança de pênalti: gol mini desenhado,
# botões de lado, placar da disputa (quando aplicável).

signal closed

const AppTheme = preload("res://scripts/AppTheme.gd")
const UIUtils = preload("res://scripts/UIUtils.gd")

var title_label: Label
var scoreboard_label: Label
var status_label: Label
var goal_view: Control
var left_button: Button
var center_button: Button
var right_button: Button

var _close_timer: Timer
var _last_seen_result: String = ""


func _ready():
	theme = AppTheme.build()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_dialog_structure()

	_close_timer = Timer.new()
	_close_timer.one_shot = true
	_close_timer.wait_time = 1.4
	_close_timer.timeout.connect(_on_close_timer_timeout)
	add_child(_close_timer)

	GameState.state_changed.connect(_refresh)
	_refresh()


func _build_dialog_structure() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 420)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = AppTheme.PANEL
	panel_style.border_color = AppTheme.GOLD
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	title_label = Label.new()
	title_label.text = "🎯 COBRANÇA DE PÊNALTI"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", AppTheme.GOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title_label)

	scoreboard_label = Label.new()
	scoreboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_label.add_theme_font_size_override("font_size", 13)
	scoreboard_label.visible = false
	main_vbox.add_child(scoreboard_label)

	goal_view = _GoalView.new()
	goal_view.custom_minimum_size = Vector2(0, 180)
	goal_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(goal_view)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(status_label)

	var buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(buttons_row)

	left_button = _make_side_button("◀ Esquerda", "ESQUERDA")
	buttons_row.add_child(left_button)

	center_button = _make_side_button("▲ Centro", "CENTRO")
	buttons_row.add_child(center_button)

	right_button = _make_side_button("▶ Direita", "DIREITA")
	buttons_row.add_child(right_button)


func _make_side_button(label_text: String, side: String) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120, 36)
	btn.pressed.connect(func(): _on_side_pressed(side))
	UIUtils.add_press_feedback(btn)
	return btn


func _on_side_pressed(side: String) -> void:
	if GameState.penalty_phase == GameState.PenaltyPhase.AWAITING_KICK_SIDE:
		GameState.choose_penalty_kick_side(side)
	elif GameState.penalty_phase == GameState.PenaltyPhase.AWAITING_GK_SIDE:
		GameState.choose_penalty_gk_side(side)


func _refresh() -> void:
	if not is_inside_tree():
		return

	title_label.text = "🎯 DISPUTA DE PÊNALTIS" if GameState.in_shootout else "🎯 COBRANÇA DE PÊNALTI"

	if GameState.in_shootout:
		scoreboard_label.visible = true
		scoreboard_label.text = "Você %d × %d Adversário   │   Cobrança %d" % [
			GameState.shootout_player_score, GameState.shootout_ai_score, GameState.shootout_turn + 1
		]
	else:
		scoreboard_label.visible = false

	var awaiting_kick = GameState.penalty_phase == GameState.PenaltyPhase.AWAITING_KICK_SIDE
	var awaiting_gk = GameState.penalty_phase == GameState.PenaltyPhase.AWAITING_GK_SIDE
	var choosing = awaiting_kick or awaiting_gk

	left_button.visible = choosing
	center_button.visible = choosing
	right_button.visible = choosing

	if awaiting_kick:
		var kicker = GameState.shootout_kicker_dict() if GameState.in_shootout else GameState.active_player()
		status_label.text = "🎯 Escolha o lado da cobrança de %s (%s)!" % [kicker.get("name", "Jogador"), kicker.get("role", "")]
	elif awaiting_gk:
		status_label.text = "🧤 Pra qual lado seu goleiro pula?"
	elif GameState.penalty_last_result != "":
		var result_text = "⚽ GOOOL!" if GameState.penalty_last_result == "GOAL" else "🧤 DEFENDEU!"
		status_label.text = result_text
	else:
		status_label.text = "Aguardando cobrança..."

	goal_view.queue_redraw()

	# 🕒 Fecha sozinho um pouco depois de um resultado, desde que não tenha
	# começado outra cobrança nesse meio tempo (disputa continuando).
	if GameState.penalty_phase == GameState.PenaltyPhase.NONE and GameState.penalty_last_result != "":
		if GameState.penalty_last_result != _last_seen_result:
			_last_seen_result = GameState.penalty_last_result
			_close_timer.start()
	else:
		_close_timer.stop()


func _on_close_timer_timeout() -> void:
	# Se uma nova cobrança já começou (disputa segue), não fecha — só
	# limpa o resultado anterior pra não reabrir o timer à toa.
	if GameState.penalty_phase != GameState.PenaltyPhase.NONE:
		return

	# Disputa ainda rolando mas entre cobranças (raro, mas seguro): não fecha
	if GameState.in_shootout and not GameState.match_over:
		return

	closed.emit()
	queue_free()


# 🥅 Desenho simplificado do gol: trave, 3 zonas, e a revelação (bola +
# goleiro) depois que os dois lados são conhecidos.
class _GoalView extends Control:
	func _draw():
		var w = size.x
		var h = size.y
		var post_color = Color(0.92, 0.92, 0.92)
		var net_color = Color(1, 1, 1, 0.08)

		# Rede (linhas finas)
		for i in range(1, 8):
			draw_line(Vector2(w * i / 8.0, 10), Vector2(w * i / 8.0, h - 20), net_color, 1.0)
		for j in range(1, 5):
			draw_line(Vector2(0, 10 + (h - 30) * j / 5.0), Vector2(w, 10 + (h - 30) * j / 5.0), net_color, 1.0)

		# Trave
		draw_rect(Rect2(0, 6, w, 6), post_color)
		draw_rect(Rect2(0, 6, 6, h - 20), post_color)
		draw_rect(Rect2(w - 6, 6, 6, h - 20), post_color)

		# Divisórias das 3 zonas
		var zone_w = w / 3.0
		draw_line(Vector2(zone_w, 12), Vector2(zone_w, h - 24), Color(1, 1, 1, 0.15), 1.5)
		draw_line(Vector2(zone_w * 2, 12), Vector2(zone_w * 2, h - 24), Color(1, 1, 1, 0.15), 1.5)

		# Revelação: bola no lado escolhido, goleiro no lado que pulou
		if GameState.penalty_last_result != "":
			var kick_x = _x_for_side(GameState.penalty_last_kick_side, zone_w)
			var gk_x = _x_for_side(GameState.penalty_last_gk_side, zone_w)
			var result_color = AppTheme.SUCCESS if GameState.penalty_last_result == "GOAL" else AppTheme.DANGER

			# Goleiro
			draw_circle(Vector2(gk_x, h * 0.55), 12, Color(0.2, 0.4, 0.8))
			draw_arc(Vector2(gk_x, h * 0.55), 12, 0, TAU, 20, Color.WHITE, 2.0)

			# Bola
			draw_circle(Vector2(kick_x, h * 0.55), 8, result_color)
			draw_arc(Vector2(kick_x, h * 0.55), 8, 0, TAU, 16, Color.WHITE, 1.5)


	func _x_for_side(side: String, zone_w: float) -> float:
		match side:
			"ESQUERDA": return zone_w * 0.5
			"DIREITA": return zone_w * 2.5
			_: return zone_w * 1.5
