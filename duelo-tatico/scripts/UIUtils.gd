extends RefCounted
# Utilitários de UI compartilhados entre as telas — evita duplicar a
# mesma função em main.gd, campaign_menu.gd, OptionsMenu.gd e
# start_screen.gd.

static func add_press_feedback(btn: Button) -> void:
	# Faz o botão "encolher" ao ser pressionado e voltar ao soltar — dá feedback tátil.
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
	)
	btn.button_up.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
