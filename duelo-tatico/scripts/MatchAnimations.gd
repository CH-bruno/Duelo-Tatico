class_name MatchAnimations
extends Node
# MatchAnimations.gd — Responsável por animações, barra de momentum e flashes visuais.

const AppTheme = preload("res://scripts/AppTheme.gd")

var goal_flash: ColorRect
var momentum_bar: ProgressBar


func setup(flash_node: ColorRect, vbox_container: VBoxContainer) -> void:
	goal_flash = flash_node
	goal_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	goal_flash.modulate.a = 0.0
	goal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_momentum_bar(vbox_container)


func _create_momentum_bar(vbox: VBoxContainer) -> void:
	if vbox.has_node("MomentumContainer"):
		return

	var container = HBoxContainer.new()
	container.name = "MomentumContainer"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.custom_minimum_size = Vector2(0, 26)

	var title = Label.new()
	title.text = "🔥 PRESSÃO: "
	title.add_theme_color_override("font_color", AppTheme.GOLD)
	title.add_theme_font_size_override("font_size", 13)

	momentum_bar = ProgressBar.new()
	momentum_bar.custom_minimum_size = Vector2(200, 16)
	momentum_bar.min_value = 0
	momentum_bar.max_value = 30
	momentum_bar.value = 0
	momentum_bar.show_percentage = false

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = AppTheme.BACKGROUND
	bg_style.border_color = Color(0.3, 0.4, 0.3)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(4)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.95, 0.45, 0.1) # Laranja Fogo
	fill_style.set_corner_radius_all(4)

	momentum_bar.add_theme_stylebox_override("background", bg_style)
	momentum_bar.add_theme_stylebox_override("fill", fill_style)

	container.add_child(title)
	container.add_child(momentum_bar)

	vbox.add_child(container)
	vbox.move_child(container, 1)


func update_momentum(target_val: float) -> void:
	if momentum_bar:
		var clamped_val = clamp(target_val, 0, 30)
		var tween = momentum_bar.create_tween()
		tween.tween_property(momentum_bar, "value", clamped_val, 0.2)


func flash(color: Color) -> void:
	if not goal_flash:
		return
	goal_flash.color = color
	goal_flash.modulate.a = 0.55
	var tween = goal_flash.create_tween()
	tween.tween_property(goal_flash, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
