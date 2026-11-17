extends "res://scripts/main_partes/main_companheiros.gd"

# Parte do main.gd (dividido em 2026-11-15 para ficar mais facil de manter).
# Interface: HUD, controles de toque, menu lateral, chat, lojas e paineis.
# Cadeia: main_estado -> main_util -> main_mundo -> main_combate -> main_companheiros
#         -> main_interface -> scripts/main.gd (o no Main da cena usa main.gd).
# Cada parte so chama funcoes dela mesma ou das partes de baixo da cadeia.

func _layout_status_hud() -> void:
	hud_status_scale = clampf(hud_status_scale, 0.72, 1.32)
	var scale := hud_status_scale
	var panel_size := HUD_PANEL_SIZE * scale
	_set_control_rect(hud_frame, hud_status_pos, panel_size)
	_set_control_rect(hud_skin_rect, hud_status_pos, panel_size)
	_set_control_rect(hud_label, hud_status_pos + HUD_LABEL_POS * scale, HUD_LABEL_SIZE * scale)
	_set_label_font_size(hud_label, int(round(13.0 * scale)))
	var bar_size := HUD_BAR_SIZE * scale
	_set_progress_bar_rect(hp_bar, hud_status_pos + HUD_HP_BAR_POS * scale, bar_size)
	_set_progress_bar_rect(mana_bar, hud_status_pos + HUD_MP_BAR_POS * scale, bar_size)
	_set_progress_bar_rect(xp_bar, hud_status_pos + HUD_XP_BAR_POS * scale, bar_size)
	_set_control_rect(hp_label, hp_bar.position, bar_size)
	_set_control_rect(mana_label, mana_bar.position, bar_size)
	_set_control_rect(xp_value_label, xp_bar.position, bar_size)
	var value_font_size: int = maxi(9, int(round(11.0 * scale)))
	_set_label_font_size(hp_label, value_font_size)
	_set_label_font_size(mana_label, value_font_size)
	_set_label_font_size(xp_value_label, value_font_size)

func _apply_hud_layout_to_touch_controls() -> void:
	var viewport_size := get_viewport_rect().size
	var joystick_base_size := HUD_JOYSTICK_BASE_SIZE * hud_joystick_scale
	var joystick_knob_size := HUD_JOYSTICK_KNOB_SIZE * hud_joystick_scale
	touch_move_center = _clamp_joystick_center(hud_joystick_center, joystick_base_size, viewport_size)
	hud_joystick_center = touch_move_center
	touch_move_radius = 72.0 * hud_joystick_scale
	_set_control_rect(joystick_base, touch_move_center - joystick_base_size * 0.5, joystick_base_size)
	_set_control_rect(joystick_knob, touch_move_center - joystick_knob_size * 0.5, joystick_knob_size)
	_reset_joystick_knob()
	_set_control_rect(attack_button, hud_attack_pos, Vector2(116, 86) * hud_attack_scale)
	for i in range(skill_buttons.size()):
		var button := skill_buttons[i]
		var pos: Vector2 = SKILL_BUTTON_POSITIONS[i] + hud_skills_offset
		_set_control_rect(button, pos, SKILL_BUTTON_SIZE * hud_skills_scale)
	for i in range(POTION_SLOTS.size()):
		var item_name := str(POTION_SLOTS[i]["item"])
		var entry: Dictionary = potion_buttons.get(item_name, {})
		var button := entry.get("button", null) as Button
		var pos: Vector2 = POTION_BUTTON_POSITIONS[i] + hud_potions_offset
		_set_control_rect(button, pos, POTION_BUTTON_SIZE * hud_potions_scale)
		var count_label := entry.get("count", null) as Label
		if count_label != null and button != null:
			count_label.position = Vector2(5, max(16.0, button.size.y - 21.0))
			count_label.size = Vector2(max(28.0, button.size.x - 10.0), 18)
	var quick_buttons := [inventory_button, character_button, quests_button, chat_button]
	for i in range(quick_buttons.size()):
		_set_control_rect(quick_buttons[i], QUICK_TOP_BUTTON_POSITIONS[i], QUICK_TOP_BUTTON_SIZE)
	_set_control_rect(interact_button, INTERACT_BUTTON_POS, INTERACT_BUTTON_SIZE)

func _load_hud_layout() -> void:
	if not FileAccess.file_exists(HUD_LAYOUT_PATH):
		return
	var file := FileAccess.open(HUD_LAYOUT_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != HUD_LAYOUT_VERSION:
		return
	hud_status_pos = _vector2_from_value(data.get("status_pos", []), HUD_PANEL_POS)
	hud_status_scale = clampf(float(data.get("status_scale", 1.0)), 0.72, 1.32)
	hud_minimap_frame_pos = _vector2_from_value(data.get("minimap_pos", []), MINIMAP_FRAME_POS)
	hud_minimap_scale = clampf(float(data.get("minimap_scale", 1.0)), 0.55, 1.55)
	hud_joystick_center = _vector2_from_value(data.get("joystick_center", []), HUD_JOYSTICK_DEFAULT_CENTER)
	touch_move_center = hud_joystick_center
	hud_joystick_scale = clampf(float(data.get("joystick_scale", 1.0)), 0.65, 1.55)
	hud_attack_pos = _vector2_from_value(data.get("attack_pos", []), Vector2(1110, 586))
	hud_attack_scale = clampf(float(data.get("attack_scale", 1.0)), 0.65, 1.55)
	hud_skills_offset = _vector2_from_value(data.get("skills_offset", []), Vector2.ZERO)
	hud_skills_scale = clampf(float(data.get("skills_scale", 1.0)), 0.65, 1.55)
	hud_potions_offset = _vector2_from_value(data.get("potions_offset", []), Vector2.ZERO)
	hud_potions_scale = clampf(float(data.get("potions_scale", 1.0)), 0.65, 1.55)
	hud_zoom_index = clampi(int(data.get("zoom_index", hud_zoom_index)), 0, CAMERA_ZOOMS.size() - 1)
	_apply_camera_zoom()

func _save_hud_layout() -> void:
	var data := {
		"version": HUD_LAYOUT_VERSION,
		"status_pos": _vector2_to_array(hud_status_pos),
		"status_scale": hud_status_scale,
		"minimap_pos": _vector2_to_array(hud_minimap_frame_pos),
		"minimap_scale": hud_minimap_scale,
		"joystick_center": _vector2_to_array(hud_joystick_center),
		"joystick_scale": hud_joystick_scale,
		"attack_pos": _vector2_to_array(hud_attack_pos),
		"attack_scale": hud_attack_scale,
		"skills_offset": _vector2_to_array(hud_skills_offset),
		"skills_scale": hud_skills_scale,
		"potions_offset": _vector2_to_array(hud_potions_offset),
		"potions_scale": hud_potions_scale,
		"zoom_index": hud_zoom_index
	}
	var file := FileAccess.open(HUD_LAYOUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func _reset_hud_layout() -> void:
	hud_status_pos = HUD_PANEL_POS
	hud_status_scale = 1.0
	hud_minimap_frame_pos = MINIMAP_FRAME_POS
	hud_minimap_scale = 1.0
	hud_joystick_center = HUD_JOYSTICK_DEFAULT_CENTER
	hud_joystick_scale = 0.98
	hud_attack_pos = Vector2(1110, 586)
	hud_attack_scale = 1.0
	hud_skills_offset = Vector2.ZERO
	hud_skills_scale = 1.0
	hud_potions_offset = Vector2.ZERO
	hud_potions_scale = 1.0
	hud_zoom_index = 1
	_apply_camera_zoom()
	_layout_status_hud()
	_layout_minimap_hud()
	_apply_hud_layout_to_touch_controls()
	_save_hud_layout()
	_flash("HUD restaurado.")

func _build_potion_bar() -> void:
	for i in range(POTION_SLOTS.size()):
		var slot: Dictionary = POTION_SLOTS[i]
		var item_name := str(slot["item"])
		var button := Button.new()
		button.position = POTION_BUTTON_POSITIONS[i]
		button.size = POTION_BUTTON_SIZE
		button.custom_minimum_size = button.size
		button.focus_mode = Control.FOCUS_NONE
		button.text = ""
		button.disabled = true
		button.add_theme_font_size_override("font_size", 13)
		button.icon = load(str(slot["icon"]))
		button.expand_icon = true
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_NONE
		_style_potion_button(button)
		var shortcut := str(slot.get("shortcut", ""))
		button.tooltip_text = "%s [%s]" % [item_name, shortcut]
		_add_shortcut_badge(button, shortcut)
		var count_label := Label.new()
		count_label.position = Vector2(5, 37)
		count_label.size = Vector2(52, 18)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		count_label.add_theme_constant_override("shadow_offset_x", 1)
		count_label.add_theme_constant_override("shadow_offset_y", 1)
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count_label)
		button.pressed.connect(func() -> void:
			_use_potion_item(item_name)
		)
		ui.add_child(button)
		potion_buttons[item_name] = {"button": button, "label": str(slot["label"]), "count": count_label}

func _add_shortcut_badge(button: Button, shortcut: String) -> void:
	if button == null or shortcut.is_empty():
		return
	var badge := Label.new()
	badge.name = "ShortcutBadge"
	badge.text = shortcut
	badge.position = Vector2(4, 3)
	badge.size = Vector2(32, 20)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 8
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_color_override("font_shadow_color", Color.BLACK)
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.03, 0.04, 0.06, 0.88)
	badge_style.border_color = Color(1, 0.84, 0.38, 0.9)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("normal", badge_style)
	button.add_child(badge)

func _build_chat_panel() -> void:
	chat_panel = PanelContainer.new()
	chat_panel.visible = false
	chat_panel.position = CHAT_PANEL_POS
	chat_panel.size = CHAT_PANEL_SIZE
	chat_panel.custom_minimum_size = CHAT_PANEL_SIZE
	chat_panel.z_index = 936
	chat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.014, 0.018, 0.94)
	style.border_color = Color("#c79d43")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	chat_panel.add_theme_stylebox_override("panel", style)
	ui.add_child(chat_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	chat_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	var title := Label.new()
	title.text = "Chat"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#f5dca0"))
	header.add_child(title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var hint := Label.new()
	hint.text = "global / local / guilda / party"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("#bcae86"))
	header.add_child(hint)

	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(52, 38)
	close.focus_mode = Control.FOCUS_NONE
	close.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	close.mouse_filter = Control.MOUSE_FILTER_STOP
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color("#a11f25")
	close_style.border_color = Color(1, 0.55, 0.55, 0.85)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(6)
	close.add_theme_stylebox_override("normal", close_style)
	close.add_theme_stylebox_override("hover", close_style)
	close.add_theme_stylebox_override("pressed", close_style)
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override("font_color", Color.WHITE)
	close.pressed.connect(_close_chat_panel)
	header.add_child(close)

	var channel_row := HBoxContainer.new()
	channel_row.add_theme_constant_override("separation", 6)
	root.add_child(channel_row)
	chat_channel_buttons.clear()
	for item in [
		{"id": "global", "label": "Global"},
		{"id": "local", "label": "Local"},
		{"id": "guild", "label": "Guilda"},
		{"id": "party", "label": "Party"}
	]:
		var channel_id := str(item["id"])
		var channel_button := Button.new()
		channel_button.text = str(item["label"])
		channel_button.focus_mode = Control.FOCUS_NONE
		channel_button.mouse_filter = Control.MOUSE_FILTER_STOP
		channel_button.custom_minimum_size = Vector2(88, 30)
		channel_button.pressed.connect(func() -> void:
			chat_selected_channel = channel_id
			_refresh_chat_channel_buttons()
		)
		channel_row.add_child(channel_button)
		chat_channel_buttons[channel_id] = channel_button
	_refresh_chat_channel_buttons()

	chat_history_scroll = ScrollContainer.new()
	chat_history_scroll.custom_minimum_size = Vector2(396, 140)
	chat_history_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_history_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	chat_history_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(chat_history_scroll)

	chat_history_box = VBoxContainer.new()
	chat_history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_history_box.add_theme_constant_override("separation", 4)
	chat_history_scroll.add_child(chat_history_box)

	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Digite mensagem ou /local /guild /party"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size = Vector2(0, 34)
	chat_input.focus_mode = Control.FOCUS_ALL
	chat_input.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_input.add_theme_color_override("font_color", Color.WHITE)
	chat_input.add_theme_color_override("font_placeholder_color", Color("#8f8f8f"))
	chat_input.add_theme_color_override("caret_color", Color("#f5dca0"))
	chat_input.gui_input.connect(_on_chat_input_gui_input)
	chat_input.text_submitted.connect(_on_chat_input_submitted)
	root.add_child(chat_input)

func _toggle_chat_panel() -> void:
	if chat_panel == null:
		return
	if chat_panel.visible:
		_close_chat_panel()
		return
	chat_panel.visible = true
	chat_panel.move_to_front()
	if chat_input != null:
		chat_input.clear()
		chat_input.grab_focus()
	if side_menu_panel != null and side_menu_panel.visible:
		side_menu_visible = false
		side_menu_panel.visible = false
		_sync_side_menu_mouse_filter()
	_refresh_chat_history_scroll()

func _close_chat_panel() -> void:
	if chat_panel == null:
		return
	chat_panel.visible = false
	if chat_input != null:
		chat_input.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _on_chat_input_submitted(text: String) -> void:
	_send_chat_message(text)

func _send_chat_message(raw_text: String) -> void:
	var parsed := _parse_chat_submission(raw_text)
	if parsed.is_empty():
		return
	var channel := str(parsed.get("channel", "global"))
	var text := str(parsed.get("text", "")).strip_edges()
	if text.is_empty():
		return
	var display_name := str(player.character_name if player != null else "Aventureiro")
	if online_mode and mmo_client != null:
		mmo_client.call("send_chat", channel, text)
		_append_chat_message(channel, display_name, text, true)
		chat_last_sent_channel = channel
		chat_last_sent_text = text
		chat_last_sent_at = float(Time.get_ticks_msec()) / 1000.0
		_flash("Chat enviado.")
	else:
		_append_chat_message(channel, display_name, text, true)
		_flash("Chat offline local.")
	if chat_input != null:
		chat_input.clear()
		chat_input.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _parse_chat_submission(raw_text: String) -> Dictionary:
	var text := str(raw_text).strip_edges()
	if text.is_empty():
		return {}
	var channel := "global"
	if text.begins_with("/"):
		var parts := text.split(" ", false, 1)
		var command := str(parts[0]).to_lower()
		var remainder := ""
		if parts.size() > 1:
			remainder = str(parts[1]).strip_edges()
		match command:
			"/local", "/l":
				channel = "local"
			"/guild", "/g":
				channel = "guild"
			"/party", "/p":
				channel = "party"
			"/global", "/all", "/world", "/w":
				channel = "global"
			_:
				_append_chat_system_message("Comando de chat invalido.", Color("#ff6b6b"))
				return {}
		if remainder.is_empty():
			_append_chat_system_message("Digite uma mensagem apos o comando.", Color("#ff6b6b"))
			return {}
		text = remainder
	else:
		channel = chat_selected_channel
	return {"channel": channel, "text": text}

func _append_chat_message(channel: String, from_name: String, text: String, local_echo: bool = false) -> void:
	var channel_color := Color("#8fd6ff")
	match channel:
		"local":
			channel_color = Color("#9be38f")
		"guild":
			channel_color = Color("#c79dff")
		"party":
			channel_color = Color("#ffd28c")
		_:
			channel_color = Color("#8fd6ff")
	var line := {
		"text": "[%s] %s: %s" % [channel.to_upper(), from_name, text],
		"color": channel_color if not local_echo else Color("#d8e5ff")
	}
	chat_lines.append(line)
	if chat_lines.size() > CHAT_MAX_LINES:
		chat_lines.pop_front()
	_refresh_chat_history_scroll()

func _append_chat_system_message(text: String, color: Color = Color("#ffe4a3")) -> void:
	chat_lines.append({
		"text": text,
		"color": color
	})
	if chat_lines.size() > CHAT_MAX_LINES:
		chat_lines.pop_front()
	_refresh_chat_history_scroll()

func _refresh_chat_history_scroll() -> void:
	if chat_history_box == null:
		return
	for child in chat_history_box.get_children():
		child.queue_free()
	for entry_variant in chat_lines:
		var entry: Dictionary = entry_variant
		var line_label := Label.new()
		line_label.text = str(entry.get("text", ""))
		line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_label.add_theme_font_size_override("font_size", 11)
		line_label.add_theme_color_override("font_color", entry.get("color", Color.WHITE))
		line_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		line_label.add_theme_constant_override("shadow_offset_x", 1)
		line_label.add_theme_constant_override("shadow_offset_y", 1)
		chat_history_box.add_child(line_label)
	call_deferred("_scroll_chat_to_bottom")

func _scroll_chat_to_bottom() -> void:
	if chat_history_scroll == null or not chat_history_scroll.visible:
		return
	chat_history_scroll.scroll_vertical = 2147483647

func _is_chat_panel_blocked(pos: Vector2) -> bool:
	if chat_panel == null or not chat_panel.visible:
		return false
	return Rect2(chat_panel.global_position, chat_panel.size).has_point(pos)

func _is_chat_panel_focused() -> bool:
	return chat_input != null and chat_input.has_focus()

func _on_chat_input_gui_input(event: InputEvent) -> void:
	if chat_input == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			chat_input.grab_focus()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			chat_input.grab_focus()

func _refresh_chat_channel_buttons() -> void:
	for channel_id in chat_channel_buttons.keys():
		var button := chat_channel_buttons.get(channel_id) as Button
		if button == null:
			continue
		var selected: bool = channel_id == chat_selected_channel
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#2c63c9") if selected else Color("#242427")
		style.border_color = Color("#f1d089") if selected else Color("#6b5a39")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_color_override("font_color", Color.WHITE if selected else Color("#e3d3aa"))

func _toggle_side_menu() -> void:
	if panel.visible:
		return
	side_menu_visible = not side_menu_visible
	side_menu_panel.visible = side_menu_visible
	if side_menu_visible:
		if panel_blocker != null:
			panel_blocker.visible = false
		if input_guard != null:
			input_guard.visible = false
		side_menu_panel.move_to_front()
		if side_menu_toggle_button != null:
			side_menu_toggle_button.move_to_front()
	_sync_side_menu_mouse_filter()

func _build_joystick() -> void:
	joystick_base = _make_texture_rect("res://assets/ui/joystick/joystick_base.png", touch_move_center - HUD_JOYSTICK_BASE_SIZE * 0.5, HUD_JOYSTICK_BASE_SIZE)
	joystick_base.modulate = Color(1, 1, 1, 0.90)
	joystick_knob = _make_texture_rect("res://assets/ui/joystick/joystick_knob.png", touch_move_center - HUD_JOYSTICK_KNOB_SIZE * 0.5, HUD_JOYSTICK_KNOB_SIZE)
	joystick_knob.modulate = Color(1, 1, 1, 0.96)
	_reset_joystick_knob()

func _is_move_touch(pos: Vector2) -> bool:
	return pos.distance_to(touch_move_center) <= max(80.0, 105.0 * hud_joystick_scale)

func _activate_potion_region(pos: Vector2) -> void:
	var index: int = clamp(int(pos.x / 100.0), 0, POTION_SLOTS.size() - 1)
	_use_potion_slot(index)

func _use_potion_slot(index: int) -> void:
	if index < 0 or index >= POTION_SLOTS.size():
		return
	_use_potion_item(str(POTION_SLOTS[index]["item"]))

func _update_touch_move(pos: Vector2) -> void:
	var delta := (pos - touch_move_center).limit_length(touch_move_radius)
	var axis := delta / touch_move_radius
	var dead_zone := 0.16
	if joystick_knob != null:
		joystick_knob.position = touch_move_center + delta - joystick_knob.size * 0.5
	_set_touch_action_strength("move_left", max(0.0, -axis.x) if abs(axis.x) >= dead_zone else 0.0)
	_set_touch_action_strength("move_right", max(0.0, axis.x) if abs(axis.x) >= dead_zone else 0.0)
	_set_touch_action_strength("move_up", max(0.0, -axis.y) if abs(axis.y) >= dead_zone else 0.0)
	_set_touch_action_strength("move_down", max(0.0, axis.y) if abs(axis.y) >= dead_zone else 0.0)

func _set_touch_action(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _set_touch_action_strength(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _release_touch_move() -> void:
	touch_move_index = -1
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	_reset_joystick_knob()

func _reset_joystick_knob() -> void:
	if joystick_knob != null:
		joystick_knob.position = touch_move_center - joystick_knob.size * 0.5

func _clamp_joystick_center(center: Vector2, base_size: Vector2, viewport_size: Vector2) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return center
	var min_center := base_size * 0.5 + HUD_JOYSTICK_SAFE_MARGIN
	var max_center := viewport_size - base_size * 0.5 - HUD_JOYSTICK_SAFE_MARGIN
	if max_center.x < min_center.x:
		max_center.x = min_center.x
	if max_center.y < min_center.y:
		max_center.y = min_center.y
	return Vector2(
		clampf(center.x, min_center.x, max_center.x),
		clampf(center.y, min_center.y, max_center.y)
	)

func _make_hold_button(text: String, pos: Vector2, size: Vector2, action: String) -> Button:
	var button := _make_touch_button(text, pos, size)
	button.button_down.connect(func() -> void:
		Input.action_press(action)
	)
	button.button_up.connect(func() -> void:
		Input.action_release(action)
	)
	return button

func _make_tap_button(text: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var button := _make_touch_button(text, pos, size)
	touch_button_callbacks[button] = callback
	button.pressed.connect(callback)
	return button

func _make_touch_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 22)
	_apply_texture_button_style(button)
	ui.add_child(button)
	touch_buttons.append(button)
	return button

func _update_action_icons() -> void:
	if player == null:
		return
	var attack_icon := str(ATTACK_ICON_BY_CLASS.get(player.class_name_selected, ""))
	if not attack_icon.is_empty():
		_apply_button_icon(attack_button, attack_icon, "ATK", "Ataque basico [1]")
	var skills: Array = player.class_data.get("skills", [])
	for i in range(skill_buttons.size()):
		var button := skill_buttons[i]
		if i >= skills.size():
			button.text = str(i + 2)
			continue
		var skill: Dictionary = skills[i]
		var skill_id := str(skill.get("id", ""))
		var skill_icon := str(SKILL_ICON_BY_ID.get(skill_id, ""))
		if skill_icon.is_empty():
			button.text = str(i + 2)
		else:
			_apply_button_icon(button, skill_icon, str(i + 2), "%s [%d]" % [str(skill.get("name", "")), i + 2])

func _spawn_npcs(map_data: Dictionary) -> void:
	var npc_list: Array = map_data.get("npcs", [])
	if current_map == "city_eldoria":
		npc_list = _eldoria_active_npc_list()
	for npc_data in npc_list:
		var npc: Npc = NPC_SCENE.instantiate()
		var npc_ref := npc
		var npc_name := str(npc_data.get("name", "NPC"))
		npc.add_to_group("npcs")
		world.add_child(npc)
		npc.setup(npc_data)
		var pos: Array = npc_data.get("pos", [100, 100])
		npc.global_position = _map_data_point(pos)
		var npc_greeting := str(npc_data.get("greeting", ""))
		npc.set_meta("greeting", npc_greeting)
		npc.set_meta("unlock_flag", str(npc_data.get("unlock_flag", "")))
		npc.set_meta("unlock_text", str(npc_data.get("unlock_text", "")))
		npc.set_meta("unlocked_text", str(npc_data.get("unlocked_text", "")))
		npc.body_entered.connect(func(body: Node) -> void:
			if body == player:
				selected_npc = npc_ref
				_flash("OK: falar com " + npc_name)
				if not npc_greeting.is_empty():
					_show_npc_bubble(npc_ref, npc_greeting)
		)
		npc.body_exited.connect(func(body: Node) -> void:
			if body == player and selected_npc == npc_ref:
				selected_npc = null
		)

func _show_npc_bubble(npc: Npc, text: String) -> void:
	if dialog_bubble != null and is_instance_valid(dialog_bubble):
		dialog_bubble.queue_free()
	if not is_inside_tree():
		return
	dialog_bubble = PanelContainer.new()
	dialog_bubble.z_index = 4000
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.025, 0.88)
	style.border_color = Color("#d8b45a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	dialog_bubble.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(260, 54)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#fff3cf"))
	dialog_bubble.add_child(label)
	world.add_child(dialog_bubble)
	# Acima do nome do NPC (o Label do NPC ocupa de -104 a -78).
	dialog_bubble.global_position = npc.global_position + Vector2(-130, -176)
	var tree := get_tree()
	tree.create_timer(5.0).timeout.connect(func() -> void:
		if dialog_bubble != null and is_instance_valid(dialog_bubble):
			dialog_bubble.queue_free()
			dialog_bubble = null
	)

func _show_quest_dialog(quest_id: String, intro: String, can_accept: bool) -> void:
	var quest: Dictionary = quest_system.quests.get(quest_id, {})
	var title := str(quest.get("title", "Missao"))
	var box := _start_modal(title, "quest_dialog")
	# textos de missao podem ser longos (intro do quests.json): quebra a linha em vez de esticar o painel
	var intro_label := _panel_label(intro, 15, Color("#fff3cf"))
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_label.custom_minimum_size = Vector2(600, 0)
	box.add_child(intro_label)
	box.add_child(_panel_label(quest_system.quest_text(quest_id), 14, Color("#d7e3f1")))
	var actions := HBoxContainer.new()
	box.add_child(actions)
	if can_accept:
		var accept := Button.new()
		accept.text = "Aceitar"
		_style_panel_button(accept)
		accept.pressed.connect(func() -> void:
			quest_system.accept(quest_id)
			quest_system.register_visit(current_map)  # "visite X" ja conta se a missao foi pega em X
			_flash("Missao aceita: " + title)
			_show_quests()
		)
		actions.add_child(accept)
	var quests_btn := Button.new()
	quests_btn.text = "Missoes"
	_style_panel_button(quests_btn)
	quests_btn.pressed.connect(_show_quests)
	actions.add_child(quests_btn)

func _show_shop(title: String = "Loja do Carlos") -> void:
	if panel.visible and current_panel == "shop":
		_hide_panel()
		return
	var box := _start_modal(title, "shop")
	box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	for item_name in NpcShop.GOODS:
		var item := item_db.get_item(item_name)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		box.add_child(line)
		var icon := TextureRect.new()
		var icon_path := str(item.get("icon", ""))
		icon.texture = load(icon_path) if not icon_path.is_empty() and ResourceLoader.exists(icon_path) else load("res://assets/sprites/drop_bag.png")
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(icon)
		var btn := Button.new()
		btn.text = "%s - %d ouro" % [item_name, int(item.get("price", 0))]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_panel_button(btn)
		btn.pressed.connect(func() -> void:
			if NpcShop.buy(player, item_db, item_name):
				_flash("Comprado: " + item_name)
				_update_potion_buttons()
				_show_shop(title)
			else:
				_flash("Ouro insuficiente.")
		)
		line.add_child(btn)

func _show_pet_shop() -> void:
	if panel.visible and current_panel == "pet_shop":
		_hide_panel()
		return
	_ensure_local_companion_state()
	var box := _start_modal("Mercado de Pets de Valdoria", "pet_shop")
	box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	box.add_child(_panel_label("Pets atacam seu alvo automatico e aplicam passivas/debuffs.", 13, Color("#cfd6df")))
	var grid := _market_grid(box)
	for def in pet_definitions:
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var code := str(def.get("code", ""))
		var owned := not _owned_entry("pets_state", "pets", code).is_empty()
		var card := _market_card()
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(398, 130)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = load(_pet_icon_path(code))
		icon.custom_minimum_size = Vector2(76, 76)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(280, 128)
		row.add_child(info)
		info.add_child(_panel_label("%s  |  %s" % [str(def.get("name", code)), str(def.get("rarity", "common")).to_upper()], 15, Color.WHITE))
		info.add_child(_panel_label("%d ouro  |  Dano %d" % [int(def.get("price", 0)), int(def.get("attack", 1))], 13, Color("#ffd36b")))
		info.add_child(_panel_label("Passiva: %s" % str(def.get("passive_desc", "")), 12, Color("#d8e6f2")))
		info.add_child(_panel_label("Ataque: %s" % str(def.get("active_desc", "")), 12, Color("#c7d6e5")))
		if not _owned_entry("pets_state", "pets", code).is_empty():
			var aff := _pet_affinity(code)
			info.add_child(_panel_label("Afinidade %d%%  |  +%d%% de %s" % [int(aff), int(round(_pet_affinity_tier(aff) * 100.0)), _pet_affinity_kind(code)], 12, Color("#ffb3c8")))
		var buy := Button.new()
		buy.text = "Equipar" if owned else "Comprar"
		_style_panel_button(buy)
		buy.pressed.connect(func() -> void:
			if _buy_local_pet(code):
				_flash(("Equipado: " if owned else "Comprado: ") + str(def.get("name", code)))
				_show_pet_shop()
			else:
				_flash("Ouro insuficiente para comprar este pet.")
		)
		info.add_child(buy)

func _show_mount_shop() -> void:
	if panel.visible and current_panel == "mount_shop":
		_hide_panel()
		return
	_ensure_local_companion_state()
	var box := _start_modal("Mercado de Montarias", "mount_shop")
	box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	box.add_child(_panel_label("Montarias dao velocidade e cada uma tem uma vantagem. Monte e desca com o botao rapido (tecla R); atacar desce da montaria.", 13, Color("#cfd6df")))
	if game_extras != null:
		var care_row := HBoxContainer.new()
		box.add_child(care_row)
		care_row.add_child(_panel_label(game_extras.mount_care_text(), 13, Color("#8fe3a8")))
		if not game_extras.mount_care_active():
			var care := Button.new()
			care.text = "Cuidar"
			_style_panel_button(care)
			care.pressed.connect(func() -> void:
				game_extras.care_for_mount()
				_show_mount_shop()
			)
			care_row.add_child(care)
	var grid := _market_grid(box)
	for def in mount_definitions:
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var code := str(def.get("code", ""))
		var owned := not _owned_entry("mounts_state", "mounts", code).is_empty()
		var card := _market_card()
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(398, 118)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = load(_mount_icon_path(code))
		icon.custom_minimum_size = Vector2(76, 76)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(280, 116)
		row.add_child(info)
		info.add_child(_panel_label("%s  |  %s" % [str(def.get("name", code)), str(def.get("rarity", "common")).to_upper()], 15, Color.WHITE))
		info.add_child(_panel_label("%d ouro  |  +%d%% velocidade" % [int(def.get("price", 0)), int(round(float(def.get("speed_bonus", 0.0)) * 100.0))], 13, Color("#ffd36b")))
		info.add_child(_panel_label(str(def.get("desc", "")), 12, Color("#c8d3e0")))
		var perk_text := str(_mount_perk(code).get("text", ""))
		if not perk_text.is_empty():
			info.add_child(_panel_label(perk_text, 12, Color("#8fe3a8")))
		var buy := Button.new()
		buy.text = "Montar" if owned else "Comprar"
		_style_panel_button(buy)
		buy.pressed.connect(func() -> void:
			if _buy_local_mount(code):
				_flash(("Montado: " if owned else "Comprado: ") + str(def.get("name", code)))
				_show_mount_shop()
			else:
				_flash("Ouro insuficiente para comprar esta montaria.")
		)
		info.add_child(buy)

# Grade de cartoes das lojas dentro de uma rolagem: com muitos itens (10 pets) a janela
# nao passa da tela e o botao X continua alcancavel.
func _market_grid(box: VBoxContainer) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(850, 400)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	return grid

func _market_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(410, 140)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.052, 0.068, 0.96)
	style.border_color = Color("#8a6a2f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	return card

func _show_forge(tier: String = "basic") -> void:
	if panel.visible and current_panel == "forge":
		_hide_panel()
		return
	var title := "Forja Rara de Valdoria" if tier == "rare" else "Forja"
	var box := _start_modal(title, "forge")
	box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	box.add_child(_panel_label("Use materiais dos monstros e moedas para criar equipamentos.", 14, Color("#cfd6df")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 405)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var recipes := CraftingSystem.load_recipes()
	for recipe_name in recipes.keys():
		var recipe_id := str(recipe_name)
		var recipe: Dictionary = recipes[recipe_id]
		var recipe_tier := str(recipe.get("tier", "basic"))
		if tier == "rare" and recipe_tier != "rare":
			continue
		if tier != "rare" and recipe_tier == "rare":
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(820, 56)
		var data := item_db.get_item(str(recipe.get("result", recipe_id)))
		var icon := TextureRect.new()
		icon.texture = load(str(data.get("icon", "res://assets/sprites/drop_bag.png")))
		icon.custom_minimum_size = Vector2(42, 42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(570, 54)
		info.add_child(_panel_label("%s  |  %d ouro" % [recipe_id, int(recipe.get("gold", 0))], 15, Color.WHITE))
		info.add_child(_panel_label(CraftingSystem.material_text(recipe, player.inventory), 12, Color("#aeb8c3")))
		row.add_child(info)
		var craft := Button.new()
		craft.text = "Criar"
		craft.custom_minimum_size = Vector2(100, 42)
		craft.disabled = not CraftingSystem.can_craft(player, recipe)
		_style_panel_button(craft)
		craft.pressed.connect(func() -> void:
			if CraftingSystem.craft(player, recipe):
				player.recalculate_equipment()
				_flash("Forjado: " + str(recipe.get("result", recipe_id)))
				_show_forge()
			else:
				_flash("Materiais ou ouro insuficientes.")
		)
		row.add_child(craft)
		list.add_child(row)

func _show_inventory() -> void:
	if panel.visible and current_panel == "inventory":
		_hide_panel()
		return
	_open_inventory_panel()

func _open_inventory_panel() -> void:
	var body := _start_modal("Bolsa", "inventory")
	var root := HBoxContainer.new()
	root.custom_minimum_size = Vector2(850, 470)
	body.add_child(root)
	var equipment_box := VBoxContainer.new()
	equipment_box.custom_minimum_size = Vector2(300, 470)
	root.add_child(equipment_box)
	equipment_box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	equipment_box.add_child(_panel_label("Equipamentos", 16, Color("#f4f4f4")))
	var slot_data := ItemDatabase.load_json("res://data/equipment_slots.json")
	var equip_grid := GridContainer.new()
	equip_grid.columns = 3
	equip_grid.custom_minimum_size = Vector2(290, 400)
	equip_grid.add_theme_constant_override("h_separation", 6)
	equip_grid.add_theme_constant_override("v_separation", 6)
	equipment_box.add_child(equip_grid)
	for row in EquipmentSystem.SLOT_GRID:
		for slot in row:
			var slot_name := str(slot)
			if slot_name.is_empty():
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(86, 62)
				equip_grid.add_child(spacer)
				continue
			equip_grid.add_child(_inventory_equipment_slot_button(slot_name, slot_data))

	var bag_box := VBoxContainer.new()
	bag_box.custom_minimum_size = Vector2(535, 470)
	root.add_child(bag_box)
	bag_box.add_child(_panel_label("Bolsa (%d slots)" % player.inventory.capacity(), 18, Color.WHITE))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(535, 430)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_box.add_child(scroll)
	var bag_grid := GridContainer.new()
	bag_grid.columns = 5
	bag_grid.custom_minimum_size = Vector2(510, 420)
	bag_grid.add_theme_constant_override("h_separation", 8)
	bag_grid.add_theme_constant_override("v_separation", 8)
	bag_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(bag_grid)
	_enable_touch_scroll(scroll, bag_grid)
	var keys: Array = player.inventory.items.keys()
	keys.sort()
	var shown := 0
	for item_name in keys:
		if shown >= player.inventory.capacity():
			break
		var bag_item_name := str(item_name)
		var data := item_db.get_item(bag_item_name)
		var amount: int = int(player.inventory.items.get(bag_item_name, 0))
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(96, 76)
		slot_btn.text = ""
		slot_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		_add_slot_icon(slot_btn, load(str(data.get("icon", "res://assets/sprites/drop_bag.png"))) as Texture2D, Vector2(44, 44), Vector2(46, 41))
		_add_slot_count(slot_btn, "x%d" % amount)
		slot_btn.tooltip_text = "%s\n%s" % [bag_item_name, str(data.get("description", ""))]
		_style_panel_button(slot_btn)
		slot_btn.pressed.connect(func() -> void:
			_use_or_equip_item(bag_item_name)
			_open_inventory_panel()
		)
		bag_grid.add_child(slot_btn)
		shown += 1
	while shown < player.inventory.capacity():
		var empty_slot := PanelContainer.new()
		empty_slot.custom_minimum_size = Vector2(96, 76)
		empty_slot.mouse_filter = Control.MOUSE_FILTER_PASS
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.04, 0.05, 0.9)
		style.border_color = Color(1, 1, 1, 0.2)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		empty_slot.add_theme_stylebox_override("panel", style)
		bag_grid.add_child(empty_slot)
		shown += 1

func _use_or_equip_item(item_name: String) -> void:
	var data := item_db.get_item(item_name)
	match str(data.get("type", "")):
		"consumivel":
			_use_potion_item(item_name)
		"equipment", "equipamento", "joia":
			var slot: String = player.inventory.equip(item_name, data)
			if not slot.is_empty():
				player.recalculate_equipment()
				_flash("Equipado em " + EquipmentSystem.slot_label(slot) + ": " + item_name)
			elif EquipmentSystem.normalize_slot(str(data.get("slot", ""))) == "backpack":
				_flash_red("Essa bolsa e menor: libere espaco antes de trocar.")
		_:
			_flash(str(data.get("description", "Item sem acao.")))

func _remove_equipped_item(slot: String) -> void:
	var removed: String = player.inventory.remove_equipment(slot)
	if removed.is_empty():
		if EquipmentSystem.normalize_slot(slot) == "backpack" and not str(player.inventory.equipment.get("backpack", "")).is_empty():
			_flash_red("Esvazie a bolsa antes de tirar: sem ela cabem %d itens." % InventorySystem.MAX_SLOTS)
		else:
			_flash("Slot vazio.")
		return
	player.recalculate_equipment()
	_flash("Removido: " + removed)

func _use_potion_item(item_name: String) -> void:
	if player == null:
		return
	if int(player.inventory.items.get(item_name, 0)) <= 0:
		_flash("Sem " + item_name)
		_update_potion_buttons()
		return
	var data := item_db.get_item(item_name)
	if str(data.get("type", "")) != "consumivel":
		_flash("Este item nao e consumivel.")
		return
	var heal_amount := int(data.get("heal", 0))
	var mana_amount := int(data.get("mana", 0))
	if heal_amount > 0 and player.vida >= player.vida_max:
		_flash("Vida ja esta cheia.")
		return
	if mana_amount > 0 and player.mana >= player.mana_max:
		_flash("Mana ja esta cheia.")
		return
	if not player.inventory.remove_item(item_name, 1):
		_flash("Sem " + item_name)
		return
	if heal_amount > 0:
		player.heal(heal_amount)
	if mana_amount > 0:
		player.recover_mana(mana_amount)
	_flash("Usado: " + item_name)
	_update_potion_buttons()

func _show_character() -> void:
	_show_skills_window()

func _show_skills_window() -> void:
	if panel.visible and current_panel == "character":
		_hide_panel()
		return
	var box := _start_modal("Habilidades", "character")
	box.add_child(_panel_label("Nome: %s    Nivel: %d    XP: %d/%d" % [player.character_name, player.level, player.xp, player.xp_to_next_level()], 16, Color.WHITE))
	box.add_child(_panel_label("HP: %d/%d    MP: %d/%d" % [player.vida, player.vida_max, player.mana, player.mana_max], 16, Color.WHITE))
	box.add_child(_panel_label("HABILIDADES", 18, Color("#9cff72")))
	for skill_id in SkillProgressionSystem.SKILL_ORDER:
		var skill: Dictionary = player.skills.get(skill_id, {})
		box.add_child(_skill_progress_row(skill_id, skill))

func _show_equipment_window() -> void:
	if panel.visible and current_panel == "equipment":
		_hide_panel()
		return
	var box := _start_modal("Equipamento", "equipment")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.custom_minimum_size = Vector2(430, 520)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	var slot_data := ItemDatabase.load_json("res://data/equipment_slots.json")
	for row in EquipmentSystem.SLOT_GRID:
		for slot in row:
			var slot_name := str(slot)
			if slot_name.is_empty():
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(132, 78)
				grid.add_child(spacer)
				continue
			grid.add_child(_equipment_slot_button(slot_name, slot_data))

func _show_quests() -> void:
	if panel.visible and current_panel == "quests":
		_hide_panel()
		return
	var box := _start_modal("Missoes", "quests")
	if quest_system.active.is_empty():
		var empty := Label.new()
		empty.text = "Nenhuma missao ativa."
		empty.add_theme_color_override("font_color", Color("#d4d9e1"))
		box.add_child(empty)
	for quest_id in quest_system.active.keys():
		var label := Label.new()
		label.text = quest_system.quest_text(str(quest_id))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color.WHITE)
		box.add_child(label)

func _show_bank(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "bank" and not force_refresh:
		_hide_panel()
		return
	var box := _start_modal("Banco", "bank")
	box.add_child(_panel_label("Saldo do personagem e moedas premium.", 13, Color("#b8c3d1")))
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 14)
	box.add_child(values)
	values.add_child(_currency_card("Ouro", str(player.ouro), Color("#ffd36b")))
	values.add_child(_currency_card("Diamantes", str(player.diamantes), Color("#9dd8ff")))
	box.add_child(_panel_label("O banco exibe as duas moedas. O valor dos diamantes fica salvo no personagem e pode ser sincronizado online.", 12, Color("#cfd6df")))

func _currency_card(title: String, value_text: String, tint: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 112)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.97)
	style.border_color = tint.darkened(0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	card.add_child(box)
	box.add_child(_panel_label(title, 16, tint))
	var value := _panel_label(value_text, 28, Color.WHITE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	return card

func _show_wikipedia() -> void:
	if panel.visible and current_panel == "wikipedia":
		_hide_panel()
		return
	var box := _start_modal("Wikipedia", "wikipedia")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(850, 450)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(_panel_label("Classes e habilidades", 18, Color("#ffd36b")))
	for class_key in class_db.classes.keys():
		var data: Dictionary = class_db.classes.get(class_key, {})
		var base: Dictionary = data.get("base", {})
		content.add_child(_panel_label("%s | HP %s | MP %s | ATK %s | DEF %s" % [
			str(class_key),
			str(base.get("vida", "-")),
			str(base.get("mana", "-")),
			str(base.get("ataque", "-")),
			str(base.get("defesa", "-"))
		], 15, Color.WHITE))
		content.add_child(_panel_label("Passiva: %s" % str(data.get("passive", "")), 13, Color("#b8c3d1")))
		for skill in data.get("skills", []):
			if typeof(skill) == TYPE_DICTIONARY:
				content.add_child(_panel_label("- %s: %s mana, recarga %ss" % [str(skill.get("name", "")), str(skill.get("mana", 0)), str(skill.get("cooldown", 0))], 13, Color("#d7e3f1")))
	content.add_child(_panel_label("Pets", 18, Color("#ffd36b")))
	for pet in pet_definitions:
		if typeof(pet) != TYPE_DICTIONARY:
			continue
		content.add_child(_panel_label("%s [%s] - %d moedas" % [str(pet.get("name", "")), str(pet.get("rarity", "")), int(pet.get("price", 0))], 15, Color.WHITE))
		content.add_child(_panel_label("Passiva: %s | Ativa: %s" % [str(pet.get("passive_desc", "")), str(pet.get("active_desc", ""))], 13, Color("#b8c3d1")))
	content.add_child(_panel_label("Montarias", 18, Color("#ffd36b")))
	for mount in mount_definitions:
		if typeof(mount) != TYPE_DICTIONARY:
			continue
		content.add_child(_panel_label("%s [%s] - +%d%% velocidade - %d moedas" % [
			str(mount.get("name", "")),
			str(mount.get("rarity", "")),
			int(round(float(mount.get("speed_bonus", 0.0)) * 100.0)),
			int(mount.get("price", 0))
		], 15, Color.WHITE))
	content.add_child(_panel_label("NPCs e mapas", 18, Color("#ffd36b")))
	for map_id in maps.keys():
		var map_data: Dictionary = maps.get(map_id, {})
		content.add_child(_panel_label(str(map_data.get("name", map_id)), 15, Color.WHITE))
		for npc in map_data.get("npcs", []):
			if typeof(npc) == TYPE_DICTIONARY:
				content.add_child(_panel_label("- %s: %s" % [str(npc.get("name", "")), str(npc.get("role", ""))], 13, Color("#b8c3d1")))
	content.add_child(_panel_label("Monstros", 18, Color("#ffd36b")))
	for enemy_name in enemies_db.keys():
		var enemy_data: Dictionary = enemies_db.get(enemy_name, {})
		var level_text := str(enemy_data.get("level", 1))
		var level_range: Array = enemy_data.get("level_range", [])
		if level_range.size() >= 2:
			level_text = "%d-%d" % [int(level_range[0]), int(level_range[1])]
		var special := "Veneno %.0f%%" % [float(enemy_data.get("poison_chance", 0.0)) * 100.0] if float(enemy_data.get("poison_chance", 0.0)) > 0.0 else "Sem habilidade especial"
		content.add_child(_panel_label("%s Lv %s | HP %s | ATK %s | DEF %s | %s" % [
			str(enemy_name),
			level_text,
			str(enemy_data.get("vida", 0)),
			str(enemy_data.get("ataque", 0)),
			str(enemy_data.get("defesa", 0)),
			special
		], 13, Color("#d7e3f1")))
	content.add_child(_panel_label("Ervas e reagentes", 18, Color("#ffd36b")))
	for herb_text in [
		"Erva Curativa - usada em pochetes de cura e pomadas simples.",
		"Erva Arcana - reforca poÃ§Ãµes de mana e pergaminhos.",
		"Folha da Floresta - ingrediente leve para alquimia inicial.",
		"Raiz de Cristal - usada em forjas e receitas de cristal.",
		"Esporo Sombrio - reage com materiais de caverna e ruinas."
	]:
		content.add_child(_panel_label("- %s" % herb_text, 13, Color("#cfe6ca")))
	content.add_child(_panel_label("Drops importantes", 18, Color("#ffd36b")))
	for drop_text in [
		"Floresta: couro rasgado, presas, carne crua, tiras de couro, pocoes.",
		"Caverna: asas de morcego, teia pegajosa, presa venenosa, carvao, minerais.",
		"Ruinas: essencia arcana, po mistico, fragmentos de cristal, nucleo flamejante.",
		"Bosses: joias especiais, materiais raros e equipamentos de set."
	]:
		content.add_child(_panel_label("- %s" % drop_text, 13, Color("#d8e6f2")))
	content.add_child(_panel_label("Ordem dos mapas", 18, Color("#ffd36b")))
	for map_step in [
		"1. Eldoria Cidade",
		"2. Floresta dos Javalis",
		"3. Caverna dos Morcegos",
		"4. Ruinas Arcanas",
		"5. Valdoria Cidade"
	]:
		content.add_child(_panel_label(map_step, 13, Color("#f6f1e2")))

func _show_professions(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "professions" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_professions")
	var box := _start_modal("Profissoes", "professions")
	var payload: Dictionary = mmo_cache.get("professions_state", {})
	var professions: Dictionary = payload.get("professions", {})
	if professions.is_empty():
		box.add_child(_panel_label("Sem dados online ainda. Coletando...", 14, Color("#d4d9e1")))
		var refresh := Button.new()
		refresh.text = "Atualizar"
		_style_panel_button(refresh)
		refresh.pressed.connect(func() -> void:
			if mmo_client != null:
				mmo_client.call("request_professions")
		)
		box.add_child(refresh)
		return
	var info := _panel_label("Profissoes evoluem com coleta/crafting. VIP +10% XP de profissao.", 13, Color("#b8c3d1"))
	box.add_child(info)
	for key in professions.keys():
		var row: Dictionary = professions.get(key, {})
		var level: int = int(row.get("level", 1))
		var xp: int = int(row.get("xp", 0))
		var xp_required: int = max(1, int(row.get("xp_required", 100)))
		box.add_child(_panel_label("%s  Lv.%d" % [str(row.get("name", key)), level], 16, Color.WHITE))
		box.add_child(_xp_bar_row("%d/%d" % [xp, xp_required], xp, xp_required, Color("#55d86a")))

func _show_crafting_window(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "crafting" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_crafting_recipes")
	var box := _start_modal("Crafting", "crafting")
	var payload: Dictionary = mmo_cache.get("crafting_recipes", {})
	var recipes: Array = payload.get("recipes", [])
	if recipes.is_empty():
		box.add_child(_panel_label("Nenhuma receita recebida ainda.", 14, Color("#d4d9e1")))
		return
	box.add_child(_panel_label("Crie armas, armaduras, pocoes e materiais refinados.", 13, Color("#b8c3d1")))
	for recipe in recipes:
		if typeof(recipe) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(820, 60)
		var recipe_name: String = str(recipe.get("name", recipe.get("code", "receita")))
		var profession: String = str(recipe.get("profession", ""))
		var req_level: int = int(recipe.get("profession_level_required", 1))
		var success_chance: int = int(recipe.get("success_chance", 100))
		row.add_child(_panel_label("%s  |  %s Lv.%d  |  %d%%" % [recipe_name, profession, req_level, success_chance], 14, Color.WHITE))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var craft_button := Button.new()
		craft_button.text = "Criar"
		_style_panel_button(craft_button)
		craft_button.pressed.connect(func() -> void:
			if online_mode and mmo_client != null:
				mmo_client.call("craft", str(recipe.get("code", "")))
				_flash("Pedido de craft enviado.")
		)
		row.add_child(craft_button)
		box.add_child(row)

func _show_pets(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "pets" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_pets")
	var box := _start_modal("Pets", "pets")
	box.add_child(_panel_label("Pets desbloqueados ficam nitidos. Bloqueados aparecem escurecidos.", 13, Color("#b8c3d1")))
	var payload: Dictionary = mmo_cache.get("pets_state", {})
	var owned: Array = payload.get("pets", [])
	var by_code: Dictionary = {}
	for pet in owned:
		if typeof(pet) != TYPE_DICTIONARY:
			continue
		by_code[str(pet.get("code", ""))] = pet
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 410)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)
	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards)
	for def in pet_definitions:
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var code := str(def.get("code", ""))
		var owned_pet: Dictionary = by_code.get(code, {})
		var unlocked: bool = not owned_pet.is_empty()
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(410, 140)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.05, 0.06, 0.08, 0.95)
		card_style.border_color = Color(1, 1, 1, 0.2)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", card_style)
		cards.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(394, 130)
		card.add_child(row)
		var icon_holder := Control.new()
		icon_holder.custom_minimum_size = Vector2(92, 92)
		row.add_child(icon_holder)
		var icon := TextureRect.new()
		icon.texture = load(_pet_icon_path(code))
		icon.custom_minimum_size = Vector2(92, 92)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.add_child(icon)
		if not unlocked:
			var shade := ColorRect.new()
			shade.color = Color(0, 0, 0, 0.58)
			shade.size = Vector2(92, 92)
			icon_holder.add_child(shade)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(290, 128)
		row.add_child(info)
		var level: int = int(owned_pet.get("level", 1))
		var equipped: bool = bool(owned_pet.get("equipped", false))
		info.add_child(_panel_label("%s %s" % [str(def.get("name", code)), "(Lv.%d)" % level if unlocked else "(Bloqueado)"], 15, Color.WHITE))
		info.add_child(_panel_label("Passiva: %s" % str(def.get("passive_desc", _pet_bonus_text(def.get("base_bonus", {})))), 12, Color("#d8e6f2")))
		info.add_child(_panel_label("Ativa: %s" % str(def.get("active_desc", "Sem ativa por enquanto.")), 12, Color("#c7d6e5")))
		if unlocked:
			var equip_btn := Button.new()
			equip_btn.text = "Equipado" if equipped else "Equipar"
			equip_btn.disabled = equipped
			_style_panel_button(equip_btn)
			var character_pet_id: int = int(owned_pet.get("id", 0))
			equip_btn.pressed.connect(func() -> void:
				if online_mode and mmo_client != null:
					mmo_client.call("equip_pet", character_pet_id)
				else:
					_equip_local_pet(code)
					_show_pets(true)
			)
			info.add_child(equip_btn)

func _show_mounts(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "mounts" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_mounts")
	var box := _start_modal("Montarias", "mounts")
	box.add_child(_panel_label("Montarias aumentam mobilidade. Bloqueadas aparecem escurecidas.", 13, Color("#b8c3d1")))
	var payload: Dictionary = mmo_cache.get("mounts_state", {})
	var owned: Array = payload.get("mounts", [])
	var by_code: Dictionary = {}
	for mount in owned:
		if typeof(mount) != TYPE_DICTIONARY:
			continue
		by_code[str(mount.get("code", ""))] = mount
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 400)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)
	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards)
	for def in mount_definitions:
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var code := str(def.get("code", ""))
		var owned_mount: Dictionary = by_code.get(code, {})
		var unlocked: bool = not owned_mount.is_empty()
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(410, 122)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.05, 0.06, 0.08, 0.95)
		card_style.border_color = Color(1, 1, 1, 0.2)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", card_style)
		cards.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(394, 116)
		card.add_child(row)
		var icon_holder := Control.new()
		icon_holder.custom_minimum_size = Vector2(92, 92)
		row.add_child(icon_holder)
		var icon := TextureRect.new()
		icon.texture = load(_mount_icon_path(code))
		icon.custom_minimum_size = Vector2(92, 92)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon_holder.add_child(icon)
		if not unlocked:
			var shade := ColorRect.new()
			shade.color = Color(0, 0, 0, 0.58)
			shade.size = Vector2(92, 92)
			icon_holder.add_child(shade)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(290, 116)
		row.add_child(info)
		var speed_bonus: float = float(def.get("speed_bonus", 0.0)) * 100.0
		var equipped: bool = bool(owned_mount.get("equipped", false))
		info.add_child(_panel_label("%s %s" % [str(def.get("name", code)), "(Bloqueada)" if not unlocked else ""], 15, Color.WHITE))
		info.add_child(_panel_label("+%.0f%% velocidade" % speed_bonus, 13, Color("#d9e8f7")))
		info.add_child(_panel_label(str(def.get("desc", "Montaria de exploracao.")), 12, Color("#c8d3e0")))
		if unlocked:
			var equip_btn := Button.new()
			equip_btn.text = "Montada" if equipped else "Montar"
			equip_btn.disabled = equipped
			_style_panel_button(equip_btn)
			var character_mount_id: int = int(owned_mount.get("id", 0))
			equip_btn.pressed.connect(func() -> void:
				if online_mode and mmo_client != null:
					mmo_client.call("equip_mount", character_mount_id)
				else:
					_equip_local_mount(code)
					_show_mounts(true)
			)
			info.add_child(equip_btn)

func _show_dungeons(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "dungeons" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_dungeons")
	var box := _start_modal("Dungeons", "dungeons")
	var payload: Dictionary = mmo_cache.get("dungeons_state", {})
	var dungeons: Array = payload.get("dungeons", [])
	if dungeons.is_empty():
		box.add_child(_panel_label("Nenhuma dungeon configurada.", 14, Color("#d4d9e1")))
		return
	for dungeon in dungeons:
		if typeof(dungeon) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(820, 46)
		var dungeon_name: String = str(dungeon.get("name", "Dungeon"))
		var min_level: int = int(dungeon.get("min_level", 1))
		var time_limit: int = int(dungeon.get("time_limit_seconds", 1200))
		row.add_child(_panel_label("%s  |  Min Lv.%d  |  %d min" % [dungeon_name, min_level, int(time_limit / 60)], 15, Color.WHITE))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var start_btn := Button.new()
		start_btn.text = "Entrar"
		_style_panel_button(start_btn)
		var dungeon_code: String = str(dungeon.get("code", ""))
		start_btn.pressed.connect(func() -> void:
			if mmo_client != null:
				mmo_client.call("start_dungeon", dungeon_code)
		)
		row.add_child(start_btn)
		box.add_child(row)

func _show_rank(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "rank" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_rank", "top_level")
	var box := _start_modal("Rank", "rank")
	var tabs := HBoxContainer.new()
	for tab_name in RANK_KEYS.keys():
		var rank_key: String = str(RANK_KEYS[tab_name])
		var tab_button := Button.new()
		tab_button.text = str(tab_name)
		_style_panel_button(tab_button)
		tab_button.pressed.connect(func() -> void:
			if mmo_client != null:
				mmo_client.call("request_rank", rank_key)
		)
		tabs.add_child(tab_button)
	box.add_child(tabs)
	var payload: Dictionary = mmo_cache.get("rank_state", {})
	var rows: Array = payload.get("rows", [])
	if rows.is_empty():
		box.add_child(_panel_label("Ranking indisponivel ainda.", 14, Color("#d4d9e1")))
		return
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		box.add_child(_panel_label("%d. %s - %s" % [i + 1, str(row.get("name", "Jogador")), str(row.get("score", row.get("level", 0)))], 14, Color.WHITE))

func _show_market(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "market" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_market")
	var box := _start_modal("Mercado", "market")
	var actions := HBoxContainer.new()
	var refresh := Button.new()
	refresh.text = "Atualizar"
	_style_panel_button(refresh)
	refresh.pressed.connect(func() -> void:
		if mmo_client != null:
			mmo_client.call("request_market")
	)
	actions.add_child(refresh)
	var quick_list := Button.new()
	quick_list.text = "Anunciar Pocao"
	_style_panel_button(quick_list)
	quick_list.pressed.connect(func() -> void:
		if mmo_client != null:
			mmo_client.call("list_market_item", "Pocao pequena de vida", 1, 99, "consumivel", "common")
	)
	actions.add_child(quick_list)
	box.add_child(actions)
	var payload: Dictionary = mmo_cache.get("market_state", {})
	var listings: Array = payload.get("listings", [])
	if listings.is_empty():
		box.add_child(_panel_label("Sem ofertas no mercado.", 14, Color("#d4d9e1")))
		return
	for listing in listings:
		if typeof(listing) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(820, 44)
		row.add_child(_panel_label("%s x%d - %d ouro" % [str(listing.get("item_id", "item")), int(listing.get("quantity", 1)), int(listing.get("price", 0))], 14, Color.WHITE))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var buy_btn := Button.new()
		buy_btn.text = "Comprar"
		_style_panel_button(buy_btn)
		var listing_id: int = int(listing.get("id", 0))
		buy_btn.pressed.connect(func() -> void:
			if mmo_client != null and listing_id > 0:
				mmo_client.call("buy_market_item", listing_id)
		)
		row.add_child(buy_btn)
		box.add_child(row)

func _show_vip(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "vip" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_vip")
	var box := _start_modal("VIP", "vip")
	var payload: Dictionary = mmo_cache.get("vip_state", {})
	var vip: Dictionary = payload.get("vip", {})
	if vip.is_empty():
		box.add_child(_panel_label("VIP nao carregado.", 14, Color("#d4d9e1")))
		return
	box.add_child(_panel_label("Ativo: %s" % ("Sim" if bool(vip.get("vip_active", false)) else "Nao"), 16, Color.WHITE))
	box.add_child(_panel_label("Dias restantes: %d" % int(vip.get("vip_days", 0)), 16, Color("#ffd36b")))
	box.add_child(_panel_label("Beneficios: +10% XP geral, +10% XP profissao, +5 slots, cosmÃƒÂ©ticos.", 13, Color("#b8c3d1")))

func _show_achievements(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "achievements" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_achievements")
	var box := _start_modal("Conquistas", "achievements")
	var payload: Dictionary = mmo_cache.get("achievements_state", {})
	var achievements: Array = payload.get("achievements", [])
	if achievements.is_empty():
		box.add_child(_panel_label("Nenhuma conquista recebida.", 14, Color("#d4d9e1")))
		return
	for ach in achievements:
		if typeof(ach) != TYPE_DICTIONARY:
			continue
		var done: bool = bool(ach.get("completed", false))
		var progress: int = int(ach.get("progress", 0))
		var objective: int = max(1, int(ach.get("objective", 1)))
		box.add_child(_panel_label("%s %s" % [str(ach.get("name", "Conquista")), "(OK)" if done else ""], 14, Color("#eaf1ff")))
		box.add_child(_xp_bar_row("%d/%d" % [progress, objective], progress, objective, Color("#6ad87a")))

func _show_season(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "season" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_season")
	var box := _start_modal("Temporada", "season")
	var payload: Dictionary = mmo_cache.get("season_state", {})
	var season: Dictionary = payload.get("season", {})
	var progress: Dictionary = payload.get("progress", {})
	if season.is_empty():
		box.add_child(_panel_label("Sem temporada ativa.", 14, Color("#d4d9e1")))
		return
	box.add_child(_panel_label(str(season.get("name", "Temporada")), 18, Color("#ffd57e")))
	var level: int = int(progress.get("level", 1))
	var xp: int = int(progress.get("xp", 0))
	box.add_child(_panel_label("Nivel passe: %d" % level, 15, Color.WHITE))
	box.add_child(_panel_label("XP passe: %d" % xp, 15, Color.WHITE))
	var premium: bool = bool(progress.get("premium_unlocked", false))
	box.add_child(_panel_label("Passe premium: %s" % ("Liberado" if premium else "Nao"), 15, Color("#d6b56e")))

func _show_hud_editor(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "hud_editor" and not force_refresh:
		_hide_panel()
		return
	var box := _start_modal("Editor HUD", "hud_editor")
	box.add_child(_panel_label("Ajuste tamanho e local do HUD. As mudancas salvam automaticamente.", 13, Color("#b8c3d1")))
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	grid.add_child(_hud_editor_row("Barras HP/MP/XP", "status"))
	grid.add_child(_hud_editor_row("Mini mapa", "minimap"))
	grid.add_child(_hud_editor_row("Joystick", "joystick"))
	grid.add_child(_hud_editor_row("Botao ataque", "attack"))
	grid.add_child(_hud_editor_row("Habilidades", "skills"))
	grid.add_child(_hud_editor_row("Pocoes", "potions"))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var reset := _hud_small_button("Resetar HUD")
	reset.custom_minimum_size = Vector2(150, 38)
	reset.pressed.connect(func() -> void:
		_reset_hud_layout()
		_show_hud_editor(true)
	)
	actions.add_child(reset)
	var close := _hud_small_button("Salvar e fechar")
	close.custom_minimum_size = Vector2(160, 38)
	close.pressed.connect(func() -> void:
		_save_hud_layout()
		_hide_panel()
	)
	actions.add_child(close)

func _hud_editor_row(title: String, group: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := _panel_label(title, 14, Color("#f2ebd3"))
	label.custom_minimum_size = Vector2(150, 34)
	row.add_child(label)
	var left := _hud_small_button("<")
	left.pressed.connect(func() -> void:
		_nudge_hud_group(group, Vector2(-10, 0))
		_show_hud_editor(true)
	)
	row.add_child(left)
	var right := _hud_small_button(">")
	right.pressed.connect(func() -> void:
		_nudge_hud_group(group, Vector2(10, 0))
		_show_hud_editor(true)
	)
	row.add_child(right)
	var up := _hud_small_button("^")
	up.pressed.connect(func() -> void:
		_nudge_hud_group(group, Vector2(0, -10))
		_show_hud_editor(true)
	)
	row.add_child(up)
	var down := _hud_small_button("v")
	down.pressed.connect(func() -> void:
		_nudge_hud_group(group, Vector2(0, 10))
		_show_hud_editor(true)
	)
	row.add_child(down)
	var smaller := _hud_small_button("-")
	smaller.pressed.connect(func() -> void:
		_scale_hud_group(group, -0.05)
		_show_hud_editor(true)
	)
	row.add_child(smaller)
	var bigger := _hud_small_button("+")
	bigger.pressed.connect(func() -> void:
		_scale_hud_group(group, 0.05)
		_show_hud_editor(true)
	)
	row.add_child(bigger)
	var info := _panel_label(_hud_group_value(group), 12, Color("#9fb2c8"))
	info.custom_minimum_size = Vector2(210, 34)
	row.add_child(info)
	return row

func _hud_small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(42, 34)
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.045, 0.055, 0.95)
	normal.border_color = Color("#8a6a2f")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.10, 0.06, 0.98)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#f2ebd3"))
	button.add_theme_font_size_override("font_size", 13)
	return button

func _nudge_hud_group(group: String, delta: Vector2) -> void:
	match group:
		"status":
			hud_status_pos += delta
		"minimap":
			hud_minimap_frame_pos += delta
		"joystick":
			hud_joystick_center += delta
		"attack":
			hud_attack_pos += delta
		"skills":
			hud_skills_offset += delta
		"potions":
			hud_potions_offset += delta
	_apply_and_save_hud_layout()

func _scale_hud_group(group: String, amount: float) -> void:
	match group:
		"status":
			hud_status_scale = clampf(hud_status_scale + amount, 0.72, 1.32)
		"minimap":
			hud_minimap_scale = clampf(hud_minimap_scale + amount, 0.55, 1.55)
		"joystick":
			hud_joystick_scale = clampf(hud_joystick_scale + amount, 0.65, 1.55)
		"attack":
			hud_attack_scale = clampf(hud_attack_scale + amount, 0.65, 1.55)
		"skills":
			hud_skills_scale = clampf(hud_skills_scale + amount, 0.65, 1.55)
		"potions":
			hud_potions_scale = clampf(hud_potions_scale + amount, 0.65, 1.55)
	_apply_and_save_hud_layout()

func _apply_and_save_hud_layout() -> void:
	_layout_status_hud()
	_layout_minimap_hud()
	_apply_hud_layout_to_touch_controls()
	_save_hud_layout()
	_update_minimap()

func _hud_group_value(group: String) -> String:
	match group:
		"status":
			return "x%d y%d  %.0f%%" % [int(hud_status_pos.x), int(hud_status_pos.y), hud_status_scale * 100.0]
		"minimap":
			return "x%d y%d  %.0f%%" % [int(hud_minimap_frame_pos.x), int(hud_minimap_frame_pos.y), hud_minimap_scale * 100.0]
		"joystick":
			return "x%d y%d  %.0f%%" % [int(hud_joystick_center.x), int(hud_joystick_center.y), hud_joystick_scale * 100.0]
		"attack":
			return "x%d y%d  %.0f%%" % [int(hud_attack_pos.x), int(hud_attack_pos.y), hud_attack_scale * 100.0]
		"skills":
			return "dx%d dy%d  %.0f%%" % [int(hud_skills_offset.x), int(hud_skills_offset.y), hud_skills_scale * 100.0]
		"potions":
			return "dx%d dy%d  %.0f%%" % [int(hud_potions_offset.x), int(hud_potions_offset.y), hud_potions_scale * 100.0]
	return ""

func _show_world_map(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "world_map" and not force_refresh:
		_hide_panel()
		return
	var box := _start_modal("Mapa do Mundo", "world_map")
	box.add_child(_panel_label("Explore andando: o mapa vai revelando as areas visitadas.", 13, Color("#b8c3d1")))
	var canvas := PanelContainer.new()
	canvas.custom_minimum_size = Vector2(860, 430)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.98)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	canvas.add_theme_stylebox_override("panel", style)
	box.add_child(canvas)
	var map_data: Dictionary = maps.get(current_map, {})
	var map_size_arr: Array = map_data.get("size", [2200, 1400])
	var map_size := Vector2(float(map_size_arr[0]), float(map_size_arr[1]))
	var canvas_size := Vector2(850, 420)
	var bg := ColorRect.new()
	bg.position = Vector2(5, 5)
	bg.size = canvas_size
	bg.color = Color(map_data.get("color", "#2e3a3d"))
	canvas.add_child(bg)
	_draw_world_map_preview(canvas, current_map, map_size, canvas_size)
	for portal_data in map_data.get("portals", []):
		var pos_arr: Array = portal_data.get("pos", [0, 0])
		var portal_world_pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		if current_map == "forest_boars":
			portal_world_pos *= FOREST_WORLD_SCALE
		var dot := ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.color = Color("#9cd3ff")
		dot.position = Vector2(5, 5) + _map_canvas_pos(map_size, canvas_size, portal_world_pos) - Vector2(3, 3)
		canvas.add_child(dot)
	for npc_data in map_data.get("npcs", []):
		var pos_arr: Array = npc_data.get("pos", [0, 0])
		var npc_world_pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		if current_map == "forest_boars":
			npc_world_pos *= FOREST_WORLD_SCALE
		var dot := ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.color = Color("#74f29b")
		dot.position = Vector2(5, 5) + _map_canvas_pos(map_size, canvas_size, npc_world_pos) - Vector2(3, 3)
		canvas.add_child(dot)
	var player_dot := ColorRect.new()
	player_dot.size = Vector2(8, 8)
	player_dot.color = Color("#ffef8a")
	player_dot.position = Vector2(5, 5) + _map_canvas_pos(map_size, canvas_size, player.global_position) - Vector2(4, 4)
	canvas.add_child(player_dot)
	var exp: Dictionary = _ensure_map_exploration(current_map)
	var grid_w: int = int(exp.get("w", 1))
	var grid_h: int = int(exp.get("h", 1))
	var data: Array = exp.get("data", [])
	for gy in range(grid_h):
		for gx in range(grid_w):
			var idx := gy * grid_w + gx
			if idx < data.size() and int(data[idx]) == 1:
				continue
			var fog := ColorRect.new()
			fog.color = Color(0, 0, 0, 0.95)
			fog.position = Vector2(5, 5) + Vector2(gx * EXPLORATION_CELL * canvas_size.x / map_size.x, gy * EXPLORATION_CELL * canvas_size.y / map_size.y)
			fog.size = Vector2(EXPLORATION_CELL * canvas_size.x / map_size.x + 1, EXPLORATION_CELL * canvas_size.y / map_size.y + 1)
			canvas.add_child(fog)

func _set_panel_content(control: Control, panel_name: String = "") -> void:
	_close_chat_panel()
	for child in panel.get_children():
		child.queue_free()
	panel.add_child(control)
	_refresh_modal_layout()
	side_menu_visible = false
	if side_menu_panel != null:
		side_menu_panel.visible = false
		_sync_side_menu_mouse_filter()
	if panel_blocker != null:
		panel_blocker.visible = true
	if input_guard != null:
		input_guard.visible = false
	_set_game_controls_enabled(false)
	panel.visible = true
	current_panel = panel_name

func _start_modal(title: String, panel_name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(876, 520)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(_panel_title(title))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(52, 38)
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_filter = Control.MOUSE_FILTER_STOP
	close.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color("#9e1d24")
	close_style.border_color = Color(1, 0.55, 0.55, 0.85)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(6)
	close.add_theme_stylebox_override("normal", close_style)
	close.add_theme_stylebox_override("hover", close_style)
	close.add_theme_stylebox_override("pressed", close_style)
	close.add_theme_color_override("font_color", Color.WHITE)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func() -> void:
		_hide_panel()
	)
	header.add_child(close)
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(860, 470)
	root.add_child(body)
	_set_panel_content(margin, panel_name)
	return body

func _hide_panel() -> void:
	for child in panel.get_children():
		child.queue_free()
	panel.visible = false
	current_panel = ""
	ui_input_lock_until = float(Time.get_ticks_msec()) / 1000.0 + 0.45
	if input_guard != null:
		input_guard.visible = true
	if not is_inside_tree():
		return
	var tree := get_tree()
	tree.create_timer(0.45).timeout.connect(func() -> void:
		if panel_blocker != null:
			panel_blocker.visible = false
		if input_guard != null:
			input_guard.visible = false
		if not panel.visible:
			_set_game_controls_enabled(true)
	)

func _refresh_modal_layout() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var desired := Vector2(920, 560)
	var width: float = clampf(viewport_size.x * 0.92, 680.0, desired.x)
	var height: float = clampf(viewport_size.y * 0.86, 460.0, desired.y)
	panel.size = Vector2(width, height)
	panel.position = (viewport_size - panel.size) * 0.5
	# se o conteudo crescer alem da altura, mantem o topo (titulo e botao X) dentro da tela
	panel.position.y = maxf(panel.position.y, 8.0)
	panel.position.x = maxf(panel.position.x, 8.0)

func _set_game_controls_enabled(enabled: bool) -> void:
	ui_controls_enabled = enabled
	for b in touch_buttons:
		if b == null:
			continue
		b.disabled = not enabled
		b.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for item_name in potion_buttons.keys():
		var entry: Dictionary = potion_buttons[item_name]
		var b := entry.get("button", null) as Button
		if b != null:
			b.disabled = not enabled
			b.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if side_menu_toggle_button != null:
		side_menu_toggle_button.disabled = false
		side_menu_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if side_menu_panel != null:
		_sync_side_menu_mouse_filter()
	if enabled:
		_update_potion_buttons()

func _sync_side_menu_mouse_filter() -> void:
	if side_menu_panel == null:
		return
	var accepts_input := side_menu_panel.visible and not (panel != null and panel.visible)
	side_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP if accepts_input else Control.MOUSE_FILTER_IGNORE
	for button in side_menu_buttons:
		if button != null and is_instance_valid(button):
			button.disabled = not accepts_input
			button.mouse_filter = Control.MOUSE_FILTER_STOP

func _panel_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label

func _equipment_slot_button(slot: String, slot_data: Dictionary) -> Button:
	var item_name := str(player.inventory.equipment.get(slot, ""))
	var info: Dictionary = slot_data.get(slot, {})
	var fallback_icon := str(info.get("icon", "res://assets/sprites/icon_slot_weapon.png"))
	var button := Button.new()
	button.custom_minimum_size = Vector2(132, 78)
	button.text = ""
	_add_slot_icon(button, UIEquipmentWindow.slot_icon(item_db, item_name, fallback_icon), Vector2(50, 50), Vector2(66, 31))
	var caption := Label.new()
	caption.text = EquipmentSystem.slot_label(slot)
	caption.position = Vector2(0, 57)
	caption.size = Vector2(132, 18)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.55 if item_name.is_empty() else 0.95))
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 1)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	button.tooltip_text = UIEquipmentWindow.slot_tooltip(slot, item_name)
	_style_equipment_slot(button, item_name.is_empty())
	button.pressed.connect(func() -> void:
		if item_name.is_empty():
			_flash("Slot vazio: " + EquipmentSystem.slot_label(slot))
		else:
			_remove_equipped_item(slot)
			_show_equipment_window()
	)
	return button

func _add_slot_icon(button: Button, texture: Texture2D, max_size: Vector2, center: Vector2) -> void:
	if texture == null:
		return
	button.clip_contents = true
	var clipper := Control.new()
	clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clipper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clipper.clip_contents = true
	button.add_child(clipper)
	var icon := TextureRect.new()
	icon.texture = texture
	var texture_size := texture.get_size()
	var scale_factor: float = min(max_size.x / max(1.0, texture_size.x), max_size.y / max(1.0, texture_size.y))
	scale_factor = clamp(scale_factor, 0.0, 1.0)
	var draw_size := texture_size * scale_factor
	if draw_size.x > max_size.x:
		draw_size.x = max_size.x
	if draw_size.y > max_size.y:
		draw_size.y = max_size.y
	# expand_mode antes do tamanho: senao o TextureRect trava no tamanho da textura
	# (ex.: 512 px) e o icone vaza/some do quadrado.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ZERO
	icon.position = center - draw_size * 0.5
	icon.size = draw_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clipper.add_child(icon)

func _add_slot_count(button: Button, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(58, 8)
	label.size = Vector2(34, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

func _inventory_equipment_slot_button(slot: String, slot_data: Dictionary) -> Button:
	var item_name := str(player.inventory.equipment.get(slot, ""))
	var info: Dictionary = slot_data.get(slot, {})
	var fallback_icon := str(info.get("icon", "res://assets/sprites/icon_slot_weapon.png"))
	var button := Button.new()
	button.custom_minimum_size = Vector2(86, 62)
	button.text = ""
	_add_slot_icon(button, UIEquipmentWindow.slot_icon(item_db, item_name, fallback_icon), Vector2(42, 42), Vector2(43, 31))
	button.tooltip_text = "%s: %s" % [EquipmentSystem.slot_label(slot), item_name if not item_name.is_empty() else "vazio"]
	_style_equipment_slot(button, item_name.is_empty())
	button.pressed.connect(func() -> void:
		if item_name.is_empty():
			_flash("Slot vazio: " + EquipmentSystem.slot_label(slot))
		else:
			_remove_equipped_item(slot)
			_open_inventory_panel()
	)
	return button

func _skill_progress_row(skill_id: String, skill: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(820, 76)
	var icon := TextureRect.new()
	icon.texture = UISkillsWindow.icon_for(skill_id)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 68)
	row.add_child(box)
	var top := HBoxContainer.new()
	top.add_child(_panel_label(str(skill.get("name", skill_id)), 16, Color.WHITE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_panel_label(str(skill.get("level", 10)), 16, Color.WHITE))
	box.add_child(top)
	var percent := UISkillsWindow.percent(skill)
	box.add_child(_xp_bar_row("%d/%d  %d%%" % [int(skill.get("xp", 0)), int(skill.get("xp_required", 1)), percent], int(skill.get("xp", 0)), int(skill.get("xp_required", 1)), Color("#55d86a")))
	return row

func _enable_touch_scroll(scroll: ScrollContainer, content: Control) -> void:
	if scroll == null:
		return
	scroll.set_meta("dragging", false)
	scroll.set_meta("drag_start_pos", Vector2.ZERO)
	scroll.set_meta("drag_scroll_start", 0)
	scroll.set_meta("drag_threshold", 10.0)
	scroll.gui_input.connect(func(event: InputEvent) -> void:
		_handle_touch_scroll_input(scroll, content, event)
	)

func _set_scroll_buttons_mouse_filter(content: Control, filter_mode) -> void:
	for child in content.get_children():
		if child is BaseButton:
			(child as BaseButton).mouse_filter = filter_mode

func _handle_touch_scroll_input(scroll: ScrollContainer, content: Control, event: InputEvent) -> void:
	if scroll == null or content == null:
		return
	var dragging := bool(scroll.get_meta("dragging", false))
	var start_pos := scroll.get_meta("drag_start_pos", Vector2.ZERO) as Vector2
	var start_scroll := int(scroll.get_meta("drag_scroll_start", 0))
	var threshold := float(scroll.get_meta("drag_threshold", 10.0))
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			scroll.set_meta("drag_start_pos", touch.position)
			scroll.set_meta("drag_scroll_start", scroll.scroll_vertical)
			scroll.set_meta("dragging", false)
			_set_scroll_buttons_mouse_filter(content, Control.MOUSE_FILTER_PASS)
		elif dragging:
			scroll.set_meta("dragging", false)
			_set_scroll_buttons_mouse_filter(content, Control.MOUSE_FILTER_PASS)
			scroll.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var delta := drag.position - start_pos
		if not dragging and absf(delta.y) > threshold:
			scroll.set_meta("dragging", true)
			_set_scroll_buttons_mouse_filter(content, Control.MOUSE_FILTER_IGNORE)
			dragging = true
		if dragging:
			var bar := scroll.get_v_scroll_bar()
			var max_scroll := int(bar.max_value) if bar != null else 0
			scroll.scroll_vertical = clampi(start_scroll - int(delta.y), 0, max_scroll)
			scroll.accept_event()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			scroll.set_meta("drag_start_pos", mouse.position)
			scroll.set_meta("drag_scroll_start", scroll.scroll_vertical)
			scroll.set_meta("dragging", false)
			_set_scroll_buttons_mouse_filter(content, Control.MOUSE_FILTER_PASS)
		elif dragging:
			scroll.set_meta("dragging", false)
			_set_scroll_buttons_mouse_filter(content, Control.MOUSE_FILTER_PASS)
			scroll.accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var motion := event as InputEventMouseMotion
		var delta := motion.position - start_pos
		if not dragging and absf(delta.y) > threshold:
			scroll.set_meta("dragging", true)
			_set_scroll_buttons_mouse_filter(content, Control.MOUSE_FILTER_IGNORE)
			dragging = true
		if dragging:
			var bar := scroll.get_v_scroll_bar()
			var max_scroll := int(bar.max_value) if bar != null else 0
			scroll.scroll_vertical = clampi(start_scroll - int(delta.y), 0, max_scroll)

func _slot_label(slot: String) -> String:
	match slot:
		"cabeca":
			return "Cabeca"
		"peitoral":
			return "Peitoral"
		"luvas":
			return "Luvas"
		"calca":
			return "Calca"
		"botas":
			return "Botas"
		"arma":
			return "Arma"
		"joia_1":
			return "Joia 1"
		"joia_2":
			return "Joia 2"
		"joia_3":
			return "Joia 3"
	return slot

func _xp_bar_row(title: String, value: int, maximum: int, fill_color: Color) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(500, 42)
	box.add_child(_panel_label(title, 13, Color("#dce2ea")))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(500, 12)
	bar.max_value = max(1, maximum)
	bar.value = clamp(value, 0, maximum)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.025, 0.032, 0.96)
	bg.border_color = Color(1, 1, 1, 0.18)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return box

func _cycle_zoom() -> void:
	hud_zoom_index = (hud_zoom_index + 1) % CAMERA_ZOOMS.size()
	_apply_camera_zoom()
	_save_hud_layout()
	_flash("Zoom: %d%%" % int(round(100.0 * float(CAMERA_ZOOMS[hud_zoom_index]))))

func _update_hud() -> void:
	if player == null:
		return
	hud_label.text = "%s | %s | Ouro: %d" % [player.character_name, player.class_name_selected, player.ouro]
	xp_label.text = ""
	hp_label.text = "%d / %d" % [player.vida, player.vida_max]
	mana_label.text = "%d / %d" % [player.mana, player.mana_max]
	var xp_next: int = max(1, int(player.xp_to_next_level()))
	var xp_current: int = clampi(player.xp, 0, xp_next)
	var xp_percent := int(round(float(xp_current) / float(xp_next) * 100.0))
	xp_value_label.text = "Lv. %d %d%%" % [player.level, xp_percent]
	hp_bar.max_value = max(1, player.vida_max)
	hp_bar.value = clampi(player.vida, 0, player.vida_max)
	xp_bar.max_value = xp_next
	xp_bar.value = xp_current
	mana_bar.max_value = max(1, player.mana_max)
	mana_bar.value = clampi(player.mana, 0, player.mana_max)
	_update_potion_buttons()
	_update_skill_button_cooldowns()

func _update_potion_buttons() -> void:
	if player == null:
		return
	for item_name in potion_buttons.keys():
		var entry: Dictionary = potion_buttons[item_name]
		var button := entry["button"] as Button
		if button == null:
			continue
		var amount := int(player.inventory.items.get(item_name, 0))
		button.text = ""
		button.disabled = (amount <= 0) or (not ui_controls_enabled)
		var count_label := entry["count"] as Label
		if count_label != null:
			count_label.text = "x%d" % amount
			count_label.modulate = Color(1, 1, 1, 1.0 if amount > 0 else 0.42)
