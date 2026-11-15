extends "res://scripts/main_partes/main_estado.gd"

# Parte do main.gd (dividido em 2026-11-15 para ficar mais facil de manter).
# Utilitarios: JSON, regras do ChatGPT (game_rules.json), relogio, estilos de botao/painel e avisos na tela.
# Cadeia: main_estado -> main_util -> main_mundo -> main_combate -> main_companheiros
#         -> main_interface -> scripts/main.gd (o no Main da cena usa main.gd).
# Cada parte so chama funcoes dela mesma ou das partes de baixo da cadeia.

func _load_json_array(path: String) -> Array:
	return ItemDatabase.load_json_array(path)

func _definition_by_code(definitions: Array, code: String) -> Dictionary:
	for entry in definitions:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("code", "")) == code:
			return entry
	return {}

func _owned_entry(state_key: String, list_key: String, code: String) -> Dictionary:
	var payload: Dictionary = mmo_cache.get(state_key, {})
	for entry in payload.get(list_key, []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("code", "")) == code:
			return entry
	return {}

# _rule(["afinidade", "ganho_pedido"], 8.0) -> valor de data/game_rules.json ou o padrao
func _rule(path: Array, default_value: Variant) -> Variant:
	var node: Variant = game_rules
	for key in path:
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(key):
			return default_value
		node = node[key]
	return node

func _rule_range(path: Array, a: float, b: float) -> float:
	var value: Variant = _rule(path, [a, b])
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return randf_range(float(value[0]), float(value[1]))
	return randf_range(a, b)

func _now_s() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _set_control_rect(control: Control, pos: Vector2, size: Vector2) -> void:
	if control == null:
		return
	control.position = pos
	control.size = size
	control.custom_minimum_size = size

func _set_progress_bar_rect(bar: TextureProgressBar, pos: Vector2, size: Vector2) -> void:
	if bar == null:
		return
	bar.position = pos
	bar.size = size
	bar.custom_minimum_size = size

func _set_label_font_size(label: Label, size: int) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", size)

func _vector2_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	return fallback

func _vector2_to_array(value: Vector2) -> Array:
	return [roundf(value.x), roundf(value.y)]

func _style_potion_button(button: Button) -> void:
	_apply_texture_button_style(button)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.42))

func _style_quick_top_button(button: Button, icon_path: String, tooltip: String) -> void:
	if button == null:
		return
	_apply_texture_button_style(button)
	button.icon = load(icon_path)
	button.expand_icon = true
	button.tooltip_text = tooltip

func _style_quick_text_button(button: Button, text: String) -> void:
	if button == null:
		return
	_apply_texture_button_style(button)
	button.icon = null
	button.text = text
	button.tooltip_text = text
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("#f6e2ad"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#fff0c8"))

func _style_interact_button(button: Button) -> void:
	if button == null:
		return
	_apply_texture_button_style(button)
	_apply_button_icon(button, "res://assets/ui/buttons/btn_ok.png", "OK", "Interagir")
	button.tooltip_text = "Interagir"

# Aba premium (assets/ui/menu_tabs/<item>.png, tools/menu_tabs): a arte ja traz o nome.
# Todas na mesma largura e com a base alinhada; o icone que sai por cima da moldura
# pode passar do botao.
func _style_side_menu_tab(button: Button, texture: Texture2D, item_label: String) -> void:
	button.text = ""
	button.icon = null
	button.tooltip_text = item_label
	button.custom_minimum_size = SIDE_MENU_TAB_SIZE
	button.clip_contents = false
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	if texture == null:
		return
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_size := texture.get_size()
	var h := SIDE_MENU_TAB_SIZE.x * tex_size.y / maxf(1.0, tex_size.x)
	art.custom_minimum_size = Vector2.ZERO
	art.position = Vector2(0, SIDE_MENU_TAB_SIZE.y - h)
	art.size = Vector2(SIDE_MENU_TAB_SIZE.x, h)
	button.add_child(art)
	# clareia ao tocar
	button.button_down.connect(func() -> void: art.modulate = Color(1.25, 1.2, 1.05))
	button.button_up.connect(func() -> void: art.modulate = Color.WHITE)

func _make_texture_rect(path: String, pos: Vector2, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.position = pos
	rect.size = size
	rect.custom_minimum_size = size
	rect.scale = Vector2.ONE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(rect)
	return rect

func _make_texture_progress_bar_layers(prefix: String, pos: Vector2, size: Vector2, z: int) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.position = pos
	bar.size = size
	bar.custom_minimum_size = size
	bar.scale = Vector2.ONE
	bar.z_index = z
	bar.min_value = 0
	bar.max_value = 1
	bar.value = 1
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = 9
	bar.stretch_margin_right = 9
	bar.stretch_margin_top = 4
	bar.stretch_margin_bottom = 4
	bar.texture_under = load("res://assets/ui/hud/bars/%s_bar_under.png" % prefix)
	bar.texture_progress = load("res://assets/ui/hud/bars/%s_bar_progress.png" % prefix)
	bar.texture_over = load("res://assets/ui/hud/bars/%s_bar_over.png" % prefix)
	ui.add_child(bar)
	return bar

func _apply_texture_button_style(button: Button) -> void:
	if button == null:
		return
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))

func _apply_button_icon(button: Button, icon_path: String, fallback_text: String, tooltip: String = "") -> void:
	if button == null:
		return
	var icon := load(icon_path) as Texture2D
	if icon == null:
		button.text = fallback_text
		return
	button.text = ""
	button.icon = icon
	button.expand_icon = true
	button.tooltip_text = tooltip

func _forest_noise01(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

func _distance_to_path_points(point: Vector2, points: Array[Vector2]) -> float:
	var best := INF
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var ab := b - a
		var denom := maxf(1.0, ab.length_squared())
		var t := clampf((point - a).dot(ab) / denom, 0.0, 1.0)
		var projection := a + ab * t
		best = minf(best, point.distance_to(projection))
	return best

func _skill_color(skill_id: String) -> Color:
	match skill_id:
		"fireball", "burning_fireball", "fire_hurricane":
			return Color("#ff8d2e")
		"arcane_blast", "mystic_shield", "blue_meteor", "basic_magic":
			return Color("#5ca8ff")
		"arrow_rain", "precise_shot", "quick_jump", "agility", "stun_shot", "basic_arrow":
			return Color("#8eea77")
		"war_cry", "heavy_slash", "blade_spin", "hero_hour", "death_area", "soul_reaper", "basic_slash":
			return Color("#ffe4a3")
	return Color("#dce7ef")

func _style_equipment_slot(button: Button, empty: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.06, 0.072, 0.96)
	normal.border_color = Color(0.75, 0.78, 0.82, 0.36)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.12, 0.14, 0.16, 0.98)
	pressed.border_color = Color(1, 1, 1, 0.58)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.55 if empty else 1.0))
	button.add_theme_font_size_override("font_size", 12)

func _panel_label(text: String, font_size: int = 15, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _style_panel_button(button: Button) -> void:
	button.clip_contents = true
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.095, 0.11, 0.96)
	normal.border_color = Color(1, 1, 1, 0.18)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.16, 0.20, 0.24, 0.98)
	pressed.border_color = Color(1, 1, 1, 0.38)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#aeb4bd"))
	button.add_theme_font_size_override("font_size", 14)

func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.z_index = 130
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	world.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", pos + Vector2(0, -34), 0.55)
	tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), 0.55)
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

func _flash(text: String) -> void:
	message_label.text = text
	message_label.modulate = Color("#f7d67a")

func _flash_red(text: String) -> void:
	message_label.text = text
	message_label.modulate = Color("#ff4b4b")

