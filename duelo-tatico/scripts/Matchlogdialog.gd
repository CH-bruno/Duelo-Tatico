extends Control
# MatchLogDialog.gd — Modal com o histórico completo de narração da partida.

signal closed

const AppTheme = preload("res://scripts/AppTheme.gd")
const UIUtils = preload("res://scripts/UIUtils.gd")

var title_label: Label
var log_label: Label
var close_button: Button


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
	setup()


func _build_dialog_structure() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 480)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = AppTheme.PANEL
	panel_style.border_color = AppTheme.GOLD
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(main_vbox)

	title_label = Label.new()
	title_label.text = "📜 HISTÓRICO DA PARTIDA"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", AppTheme.GOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var log_box = StyleBoxFlat.new()
	log_box.bg_color = AppTheme.BACKGROUND
	log_box.border_color = AppTheme.GOLD.darkened(0.2)
	log_box.set_border_width_all(1)
	log_box.set_corner_radius_all(8)
	log_box.set_content_margin_all(10)

	var log_panel = PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", log_box)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_panel)

	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_color_override("font_color", AppTheme.TEXT_COLOR)
	log_label.add_theme_font_size_override("font_size", 12)
	log_panel.add_child(log_label)

	close_button = Button.new()
	close_button.text = "Voltar ao Jogo ►"
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.pressed.connect(_on_close_pressed)
	UIUtils.add_press_feedback(close_button)
	main_vbox.add_child(close_button)


func setup() -> void:
	title_label.text = "📜 HISTÓRICO DA PARTIDA (%d eventos)" % GameState.log_messages.size()

	if GameState.log_messages.is_empty():
		log_label.text = "Nenhum evento registrado ainda."
		return

	# GameState.log_messages fica do mais recente pro mais antigo (push_front);
	# pro histórico completo é mais natural ler em ordem cronológica.
	var chronological = GameState.log_messages.duplicate()
	chronological.reverse()

	var lines: Array[String] = []
	for i in range(chronological.size()):
		lines.append("%d. %s" % [i + 1, chronological[i]])

	log_label.text = "\n".join(lines)


func _on_close_pressed():
	closed.emit()
	queue_free()
