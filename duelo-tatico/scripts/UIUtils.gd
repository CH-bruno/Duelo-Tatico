extends RefCounted
# UIUtils.gd — Utilitários de UI compartilhados (Animações e feedback tátil)

static func add_press_feedback(btn: Button) -> void:
	if not is_instance_valid(btn):
		return

	# Ajusta o pivô para o centro do botão para escalar sem deslocar
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): 
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size / 2.0
	)
	
	# Efeito ao pressionar (encolhe)
	btn.button_down.connect(func():
		if is_instance_valid(btn):
			var tween = btn.create_tween()
			tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
	)
	
	# Efeito ao soltar (retorna com bounce elástico)
	btn.button_up.connect(func():
		if is_instance_valid(btn):
			var tween = btn.create_tween()
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
