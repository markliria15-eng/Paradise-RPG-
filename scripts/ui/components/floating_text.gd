extends Label

func setup_kind(text_value: String, kind: String) -> void:
	text = text_value
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_shadow_color", Color.BLACK)
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
	match kind:
		"damage":
			add_theme_color_override("font_color", Color("#ffffff"))
		"critical":
			add_theme_color_override("font_color", Color("#ffb13b"))
		"magic":
			add_theme_color_override("font_color", Color("#7f8cff"))
		"heal":
			add_theme_color_override("font_color", Color("#4ce06b"))
		"xp":
			add_theme_color_override("font_color", Color("#e4c25c"))
		"miss":
			add_theme_color_override("font_color", Color("#8c8c8c"))
		_:
			add_theme_color_override("font_color", Color.WHITE)
	var tween := create_tween()
	tween.tween_property(self, "position", position + Vector2(0, -30), 0.5)
	tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(queue_free)

