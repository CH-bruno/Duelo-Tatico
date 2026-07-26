extends RefCounted
# Constrói um Theme por código — assim todas as cenas compartilham
# a mesma paleta e estilo de botão sem duplicar nada.

const BG_COLOR = Color(0.07, 0.12, 0.09)
const ACCENT = Color(0.85, 0.65, 0.25)
const TEXT_COLOR = Color(0.95, 0.95, 0.92)
const BUTTON_BG = Color(0.16, 0.24, 0.19)
const BUTTON_HOVER = Color(0.22, 0.32, 0.25)
const BUTTON_PRESSED = Color(0.12, 0.18, 0.14)
const BUTTON_DISABLED = Color(0.12, 0.15, 0.13)
const GOLD = Color8(217, 166, 64)        # Color(0.85, 0.65, 0.25)
const PANEL = Color8(31, 46, 36)          # Fundo de Cards / Painéis
const BACKGROUND = Color8(18, 30, 23)      # Fundo do Gramado / Tela Escura
const SUCCESS = Color8(90, 220, 90)       # Verdes de confirmação / Destaque
const WARNING = Color8(255, 200, 70)      # Amarelo / Alertas
const DANGER = Color8(220, 80, 80)        # Vermelhos / Erros

const BUTTON_SIZE_DEFAULT = Vector2(250, 36)
const BUTTON_SIZE_COMPACT = Vector2(260, 32)

static func build() -> Theme:
	var theme = Theme.new()

	var normal_box = StyleBoxFlat.new()
	normal_box.bg_color = BUTTON_BG
	normal_box.set_corner_radius_all(6)
	normal_box.set_content_margin_all(10)
	normal_box.border_width_bottom = 3
	normal_box.border_color = ACCENT.darkened(0.35)

	var hover_box: StyleBoxFlat = normal_box.duplicate()
	hover_box.bg_color = BUTTON_HOVER

	var pressed_box: StyleBoxFlat = normal_box.duplicate()
	pressed_box.bg_color = BUTTON_PRESSED
	pressed_box.border_width_bottom = 1

	var disabled_box: StyleBoxFlat = normal_box.duplicate()
	disabled_box.bg_color = BUTTON_DISABLED
	disabled_box.border_color = Color(0, 0, 0, 0)

	for type_name in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type_name, normal_box)
		theme.set_stylebox("hover", type_name, hover_box)
		theme.set_stylebox("pressed", type_name, pressed_box)
		theme.set_stylebox("disabled", type_name, disabled_box)
		theme.set_color("font_color", type_name, TEXT_COLOR)
		theme.set_color("font_hover_color", type_name, TEXT_COLOR)
		theme.set_color("font_disabled_color", type_name, Color(0.5, 0.5, 0.5))

	theme.set_color("font_color", "Label", TEXT_COLOR)

	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.05, 0.08, 0.06)
	pb_bg.set_corner_radius_all(5)
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = ACCENT
	pb_fill.set_corner_radius_all(5)
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)
	theme.set_color("font_color", "ProgressBar", TEXT_COLOR)

	# "GhostButton" — variação pra ações secundárias (Voltar, Menu):
	# só contorno, sem preenchimento, pra não competir visualmente com
	# os botões de ação principal.
	theme.add_type("GhostButton")

	var ghost_normal = StyleBoxFlat.new()
	ghost_normal.bg_color = Color(0, 0, 0, 0)
	ghost_normal.set_corner_radius_all(6)
	ghost_normal.set_content_margin_all(10)
	ghost_normal.set_border_width_all(1)
	ghost_normal.border_color = ACCENT.darkened(0.2)

	var ghost_hover: StyleBoxFlat = ghost_normal.duplicate()
	ghost_hover.bg_color = Color(1, 1, 1, 0.06)

	var ghost_pressed: StyleBoxFlat = ghost_normal.duplicate()
	ghost_pressed.bg_color = Color(1, 1, 1, 0.12)

	theme.set_stylebox("normal", "GhostButton", ghost_normal)
	theme.set_stylebox("hover", "GhostButton", ghost_hover)
	theme.set_stylebox("pressed", "GhostButton", ghost_pressed)
	theme.set_stylebox("disabled", "GhostButton", ghost_normal)
	theme.set_color("font_color", "GhostButton", TEXT_COLOR)
	theme.set_color("font_hover_color", "GhostButton", TEXT_COLOR)

	return theme
