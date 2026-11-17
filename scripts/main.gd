extends "res://scripts/main_partes/main_interface.gd"

# Orquestra o MVP: carrega dados, troca mapas, conecta combate, UI, drops,
# missoes e save sem esconder numeros de balanceamento dentro do codigo.
# O resto do codigo esta dividido em scripts/main_partes/ (veja o cabecalho de cada arquivo).

func _ready() -> void:
	randomize()
	world.y_sort_enabled = true
	maps = ItemDatabase.load_json("res://data/maps.json")
	enemies_db = ItemDatabase.load_json("res://data/enemies.json")
	pet_definitions = _load_json_array("res://data/mmo_pets.json")
	mount_definitions = _load_json_array("res://data/mmo_mounts.json")
	var rules_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_rules.json"))
	game_rules = rules_data if rules_data is Dictionary else {}
	quest_system.load_quests()
	_load_hud_layout()
	_build_ui()
	_setup_mmo_integration()
	if online_mode:
		_start_online_game_from_session()
		return
	var direct_boot_class := _consume_direct_launcher_offline_class()
	if not direct_boot_class.is_empty():
		launcher_boot_started = true
		_start_new_game(direct_boot_class)
		return
	var offline_boot := _consume_launcher_offline_boot()
	if bool(offline_boot.get("start_offline", false)):
		launcher_boot_started = true
		_start_new_game(str(offline_boot.get("class_name", "Guerreiro")))
		return
	if _consume_launcher_auto_start_offline():
		launcher_boot_started = true
		_start_new_game(_launcher_auto_class())
		return
	var save := SaveSystem.load_game()
	if save.is_empty():
		_show_class_selection()
	else:
		_spawn_player_from_save(save)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_refresh_modal_layout()

func _process(delta: float) -> void:
	if player == null:
		return
	_enforce_world_collision()
	_update_kit_vehicles(delta)
	regen_timer += delta
	if regen_timer >= 1.0:
		regen_timer = 0
		_apply_map_regen()
	_update_safe_zone_state()
	_update_map_exploration()
	_update_current_target()
	_update_nearby_portal()
	_sanitize_game_ui_interaction_state()
	_collect_nearby_drops(delta)
	_update_minimap()
	_update_remote_player_visuals(delta)
	_update_companion_visuals(delta)
	_update_pet_combat(delta)
	_update_hud()
	if online_mode and mmo_client != null:
		net_move_accumulator += delta
		if net_move_accumulator >= 0.12:
			net_move_accumulator = 0.0
			mmo_client.call("send_move", current_map, player.global_position)
		online_save_accumulator += delta
		if online_save_accumulator >= 8.0:
			online_save_accumulator = 0.0
			_send_online_save_state()

func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	# tocar no pet: atende o pedido dele ou faz carinho
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if pet_follower != null and is_instance_valid(pet_follower):
			var center := pet_follower.global_position + Vector2(0, -PET_TARGET_HEIGHT * 0.35)
			if get_global_mouse_position().distance_to(center) < 46.0:
				_interact_with_pet()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ESCAPE and panel != null and panel.visible:
				_hide_panel()
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				if panel == null or not panel.visible:
					_interact()
				get_viewport().set_input_as_handled()
				return
			if panel == null or not panel.visible:
				match key_event.keycode:
					KEY_F1:
						_use_potion_slot(0)
					KEY_F2:
						_use_potion_slot(1)
					KEY_F3:
						_use_potion_slot(2)
					KEY_F4:
						_use_potion_slot(3)
					KEY_R:
						_toggle_mount()
					_:
						pass
	if event.is_action_pressed("inventory"):
		_show_inventory()
	elif event.is_action_pressed("character"):
		_show_character()
	elif event.is_action_pressed("quests"):
		_show_quests()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("save_game"):
		if online_mode:
			_send_online_save_state()
			_flash("Modo online: progresso enviado ao servidor.")
		else:
			SaveSystem.save_game(player, quest_system, current_map, exploration_by_map, mmo_cache)
			_flash("Jogo salvo.")

func _input(event: InputEvent) -> void:
	if player == null:
		return
	if chat_panel != null and chat_panel.visible:
		if event is InputEventScreenTouch:
			var chat_touch := event as InputEventScreenTouch
			if chat_touch.pressed and _is_chat_panel_blocked(chat_touch.position):
				return
		elif event is InputEventScreenDrag:
			var chat_drag := event as InputEventScreenDrag
			if _is_chat_panel_blocked(chat_drag.position):
				return
		elif event is InputEventMouseButton:
			var chat_mouse := event as InputEventMouseButton
			if chat_mouse.pressed and _is_chat_panel_blocked(chat_mouse.position):
				return
	if _handle_touch_ui_event(event):
		get_viewport().set_input_as_handled()
		return
	if _is_ui_locked():
		if touch_move_index != -1:
			_release_touch_move()
		return
	if panel.visible:
		if touch_move_index != -1:
			_release_touch_move()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _is_move_touch(touch.position):
				touch_move_index = touch.index
				_update_touch_move(touch.position)
		elif touch.index == touch_move_index:
			_release_touch_move()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == touch_move_index:
			_update_touch_move(drag.position)

func _handle_touch_ui_event(event: InputEvent) -> bool:
	var pos := Vector2.ZERO
	var is_touch := event is InputEventScreenTouch
	if event is InputEventScreenTouch and event.pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	else:
		return false
	# Descarte o evento emulado apenas quando o primeiro ja acionou um controle do HUD.
	var now_ms := Time.get_ticks_msec()
	if is_touch != last_ui_tap_was_touch and now_ms - last_ui_tap_ms < 180 and pos.distance_to(last_ui_tap_pos) < 24.0:
		last_ui_tap_ms = -1000
		return true
	if panel.visible or _is_ui_locked() or not _activate_tap_controls(pos):
		return false
	last_ui_tap_ms = now_ms
	last_ui_tap_pos = pos
	last_ui_tap_was_touch = is_touch
	return true

func _sanitize_game_ui_interaction_state() -> void:
	if selected_npc != null and not is_instance_valid(selected_npc):
		selected_npc = null
	if selected_portal != null and not is_instance_valid(selected_portal):
		selected_portal = null
	if panel != null and panel.visible:
		return
	if panel_blocker != null and panel_blocker.visible:
		panel_blocker.visible = false
	if input_guard != null and input_guard.visible and not _is_ui_locked():
		input_guard.visible = false
	if not ui_controls_enabled:
		_set_game_controls_enabled(true)
	if side_menu_toggle_button != null:
		side_menu_toggle_button.disabled = false
		side_menu_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _activate_tap_controls(pos: Vector2) -> bool:
	if side_menu_visible and side_menu_panel != null and side_menu_panel.visible and side_menu_panel.get_global_rect().has_point(pos):
		for button in side_menu_buttons:
			if is_instance_valid(button) and button.get_global_rect().has_point(pos):
				_handle_side_menu(str(button.get_meta("menu_item", button.text)))
				return true
		return false
	for button in touch_buttons:
		if button == null or not is_instance_valid(button) or button.disabled or not button.visible:
			continue
		var button_rect := Rect2(button.global_position, button.size)
		if button_rect.has_point(pos):
			var callback: Variant = touch_button_callbacks.get(button, Callable())
			if callback is Callable and (callback as Callable).is_valid():
				(callback as Callable).call()
				return true
	if side_menu_toggle_button != null and Rect2(side_menu_toggle_button.global_position, side_menu_toggle_button.size).has_point(pos):
		_toggle_side_menu()
		return true
	if attack_button != null and Rect2(attack_button.global_position, attack_button.size).has_point(pos):
		player.basic_attack()
		return true
	if interact_button != null and Rect2(interact_button.global_position, interact_button.size).has_point(pos):
		_interact()
		return true
	if inventory_button != null and Rect2(inventory_button.global_position, inventory_button.size).has_point(pos):
		_show_inventory()
		return true
	if character_button != null and Rect2(character_button.global_position, character_button.size).has_point(pos):
		_show_skills_window()
		return true
	if quests_button != null and Rect2(quests_button.global_position, quests_button.size).has_point(pos):
		_show_quests()
		return true
	for i in range(skill_buttons.size()):
		var skill_btn := skill_buttons[i]
		if skill_btn != null and Rect2(skill_btn.global_position, skill_btn.size).has_point(pos):
			player.use_skill(i)
			return true
	for item_name in potion_buttons.keys():
		var entry: Dictionary = potion_buttons[item_name]
		var button := entry.get("button", null) as Button
		if button != null and Rect2(button.global_position, button.size).has_point(pos):
			_use_potion_item(str(entry.get("item", item_name)))
			return true
	return false

func _is_ui_locked() -> bool:
	return Time.get_ticks_msec() < int(ui_input_lock_until * 1000.0)

func _setup_mmo_integration() -> void:
	mmo_client = get_node_or_null("/root/MMOClient")
	if mmo_client == null:
		online_mode = false
		return
	online_mode = bool(mmo_client.get("online_enabled")) and not str(mmo_client.get("token")).is_empty()
	if not online_mode:
		return
	if not mmo_client.is_connected("world_message", Callable(self, "_on_mmo_world_message")):
		mmo_client.connect("world_message", Callable(self, "_on_mmo_world_message"))
	_flash("Modo MMO online ativo.")

func _start_online_game_from_session() -> void:
	if mmo_client == null:
		_show_class_selection()
		return
	var payload: Dictionary = mmo_client.get("account_payload")
	var character := _pick_online_character(payload)
	if character.is_empty():
		_flash("Nenhum personagem online selecionado, abrindo modo offline.")
		online_mode = false
		_show_class_selection()
		return
	var class_id := str(character.get("class", "Guerreiro"))
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.setup(class_id, class_db.get_class_data(class_id), item_db)
	player.character_name = str(character.get("name", "Aventureiro"))
	player.set_meta("character_id", int(character.get("id", 0)))
	player.level = int(character.get("level", 1))
	player.xp = int(character.get("xp", 0))
	player.ouro = int(character.get("gold", 0))
	player.diamantes = int(character.get("diamantes", character.get("diamonds", 0)))
	player.vida = int(character.get("hp", player.vida_max))
	player.mana = int(character.get("mana", player.mana_max))
	if character.has("skills") and typeof(character["skills"]) == TYPE_DICTIONARY:
		player.skills = character["skills"]
		_normalize_player_skills()
	player.recalculate_equipment()
	_connect_player()
	_update_action_icons()
	var map_id := _resolve_map_id(str(character.get("map", FOREST_PRIMARY_MAP_ID)))
	var spawn := Vector2(float(character.get("pos_x", 1100.0)), float(character.get("pos_y", 700.0)))
	if not maps.has(map_id):
		map_id = FOREST_PRIMARY_MAP_ID
		spawn = Vector2(1100.0, 700.0)
	if maps.has("city_eldoria"):
		_load_home_city()
	else:
		_load_map(map_id, spawn)
	flash_online_help()

func flash_online_help() -> void:
	_flash("Online conectado. Outros jogadores serao sincronizados automaticamente.")

func _send_online_save_state() -> void:
	if not online_mode or mmo_client == null or player == null:
		return
	mmo_client.call("send_character_save", {
		"level": player.level,
		"xp": player.xp,
		"hp": player.vida,
		"mana": player.mana,
		"gold": player.ouro,
		"diamantes": player.diamantes,
		"map": current_map,
		"pos": {"x": player.global_position.x, "y": player.global_position.y},
		"skills": player.skills
	})

func _normalize_player_skills() -> void:
	if player == null:
		return
	var defaults := SkillProgressionSystem.default_skills()
	for skill_id in defaults.keys():
		var base: Dictionary = defaults[skill_id]
		var current: Dictionary = player.skills.get(skill_id, {})
		current["name"] = str(current.get("name", base.get("name", skill_id)))
		current["level"] = int(current.get("level", base.get("level", 10)))
		current["xp"] = int(current.get("xp", base.get("xp", 0)))
		current["xp_required"] = SkillProgressionSystem.xp_required(int(current["level"]))
		player.skills[skill_id] = current

func _pick_online_character(payload: Dictionary) -> Dictionary:
	var selected_id := int(mmo_client.get("selected_character_id"))
	var chars: Array = payload.get("characters", [])
	for ch in chars:
		if typeof(ch) == TYPE_DICTIONARY and int(ch.get("id", 0)) == selected_id:
			return ch
	if payload.has("character") and typeof(payload["character"]) == TYPE_DICTIONARY:
		return payload["character"]
	if not chars.is_empty() and typeof(chars[0]) == TYPE_DICTIONARY:
		return chars[0]
	return {}

func _on_mmo_world_message(payload: Dictionary) -> void:
	var msg_type := str(payload.get("type", ""))
	match msg_type:
		"world_snapshot":
			_apply_online_snapshot(payload.get("players", []))
		"player_joined":
			_spawn_or_update_remote(payload.get("player", {}))
		"player_left":
			_remove_remote_player(int(payload.get("characterId", 0)))
		"entity_hp_sync":
			_update_remote_hp(int(payload.get("characterId", 0)), int(payload.get("hp", 0)))
		"chat_message":
			var channel := str(payload.get("channel", "global"))
			var from_name := str(payload.get("from", "?"))
			var text := str(payload.get("text", ""))
			var is_self := player != null and from_name == str(player.character_name)
			var now := float(Time.get_ticks_msec()) / 1000.0
			if is_self and channel == chat_last_sent_channel and text == chat_last_sent_text and now - chat_last_sent_at <= 1.5:
				_flash("[%s] %s: %s" % [channel, from_name, text])
				return
			_append_chat_message(channel, from_name, text)
			_flash("[%s] %s: %s" % [channel, from_name, text])
		"chat_error":
			var chat_error_text := str(payload.get("text", "Erro de chat."))
			_append_chat_system_message(chat_error_text, Color("#ff6b6b"))
			_flash_red(chat_error_text)
		"system_event":
			_flash(str(payload.get("text", "Evento global.")))
		"professions_state", "crafting_recipes", "pets_state", "mounts_state", "dungeons_state", "rank_state", "market_state", "vip_state", "achievements_state", "season_state":
			mmo_cache[msg_type] = payload
			_refresh_mmo_panel_from_cache(msg_type)
		"crafting_result":
			var success: bool = bool(payload.get("success", false))
			_flash("Crafting: %s" % ("Sucesso!" if success else "Falhou."))
			if current_panel == "crafting":
				_show_crafting_window(true)
		"market_buy_result":
			_flash("Mercado: compra concluida.")
			if current_panel == "market":
				if mmo_client != null:
					mmo_client.call("request_market")
		"market_listing_created":
			_flash("Mercado: item anunciado.")
			if current_panel == "market":
				if mmo_client != null:
					mmo_client.call("request_market")
		"character_saved":
			if bool(payload.get("ok", false)):
				_flash("Progresso online salvo.")
		"dungeon_started":
			_flash("Dungeon iniciada: %s" % str(payload.get("dungeon", {}).get("name", "instancia")))
		"error":
			_flash("Online: " + str(payload.get("message", "erro")))
		"pvp_damage_taken":
			if player != null:
				var dmg := int(payload.get("damage", 0))
				player.receive_damage(dmg)
		_:
			pass

func _refresh_mmo_panel_from_cache(msg_type: String) -> void:
	match msg_type:
		"professions_state":
			if current_panel == "professions":
				_show_professions(true)
		"crafting_recipes":
			if current_panel == "crafting":
				_show_crafting_window(true)
		"pets_state":
			if current_panel == "pets":
				_show_pets(true)
		"mounts_state":
			if current_panel == "mounts":
				_show_mounts(true)
		"dungeons_state":
			if current_panel == "dungeons":
				_show_dungeons(true)
		"rank_state":
			if current_panel == "rank":
				_show_rank(true)
		"market_state":
			if current_panel == "market":
				_show_market(true)
		"vip_state":
			if current_panel == "vip":
				_show_vip(true)
		"achievements_state":
			if current_panel == "achievements":
				_show_achievements(true)
		"season_state":
			if current_panel == "season":
				_show_season(true)

func _apply_online_snapshot(players_data: Array) -> void:
	var seen: Dictionary = {}
	for entry in players_data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var character_id := int(entry.get("characterId", 0))
		if player != null and character_id == int(player.get_meta("character_id", 0)):
			continue
		if character_id <= 0:
			continue
		seen[character_id] = true
		_spawn_or_update_remote(entry)
	var keys := remote_players.keys()
	for character_id in keys:
		if not seen.has(character_id):
			_remove_remote_player(int(character_id))

func _spawn_or_update_remote(data: Dictionary) -> void:
	var character_id := int(data.get("characterId", 0))
	if character_id <= 0:
		return
	if player != null and character_id == int(player.get_meta("character_id", 0)):
		return
	var remote: Node2D = remote_players.get(character_id, null)
	if remote != null and not is_instance_valid(remote):
		remote_players.erase(character_id)
		remote = null
	var created := false
	if remote == null:
		remote = _create_remote_player_node(data)
		remote_players[character_id] = remote
		world.add_child(remote)
		created = true
	var previous_position := remote.global_position
	remote.global_position = Vector2(float(data.get("pos", {}).get("x", 0.0)), float(data.get("pos", {}).get("y", 0.0)))
	remote.z_index = clampi(int(remote.global_position.y), -1024, 1024)
	var remote_map := str(data.get("map", current_map))
	remote.set_meta("map", remote_map)
	remote.set_meta("class_name", str(data.get("className", "Guerreiro")))
	remote.set_meta("last_position", remote.global_position)
	remote.set_meta("moving_until", 0.0)
	if not created and remote.global_position.distance_to(previous_position) > 1.0:
		remote.set_meta("moving_until", _now_seconds() + 0.28)
		_update_remote_player_motion(remote, previous_position, remote.global_position)
	remote.visible = remote_map == current_map
	var name_label: Label = remote.get_node("NameLabel")
	name_label.text = "Lv %d %s" % [int(data.get("level", 1)), str(data.get("name", "Jogador"))]
	_update_remote_hp(character_id, int(data.get("hp", 100)))

func _create_remote_player_node(data: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.name = "RemotePlayer_%d" % int(data.get("characterId", 0))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = _remote_load_texture(_player_sprite_path_from_class(str(data.get("className", "Guerreiro"))))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite.texture != null:
		# mesmo tamanho do jogador local (Player.HD_PLAYER_TARGET_HEIGHT, pack frames_192)
		var target_height := 119.0
		var texture_height: float = maxf(1.0, float(sprite.texture.get_height()))
		var sprite_scale: float = target_height / texture_height
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		sprite.position = Vector2(0, -35)
	else:
		sprite.scale = Vector2(1.58, 1.58)
	node.add_child(sprite)
	var label := Label.new()
	label.name = "NameLabel"
	label.position = Vector2(-88, -86)
	label.size = Vector2(176, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#e7f2ff"))
	label.add_theme_font_size_override("font_size", 11)
	node.add_child(label)
	var hp := ProgressBar.new()
	hp.name = "HP"
	hp.position = Vector2(-42, -56)
	hp.size = Vector2(84, 6)
	hp.max_value = 100
	hp.value = 100
	hp.show_percentage = false
	node.add_child(hp)
	node.set_meta("class_name", str(data.get("className", "Guerreiro")))
	node.set_meta("walk_frame", 0)
	node.set_meta("walk_time", 0.0)
	node.set_meta("moving_until", 0.0)
	node.set_meta("visual_direction", "front")
	node.set_meta("visual_flip_h", false)
	node.set_meta("last_position", Vector2.ZERO)
	_update_remote_player_sprite(node, false)
	return node

func _update_remote_hp(character_id: int, hp_value: int) -> void:
	var remote: Node2D = remote_players.get(character_id, null)
	if remote == null:
		return
	var hp := remote.get_node("HP") as ProgressBar
	if hp == null:
		return
	hp.max_value = max(1, hp.max_value)
	hp.value = clamp(hp_value, 0, hp.max_value)

func _update_remote_player_visuals(delta: float) -> void:
	var now := _now_seconds()
	for character_id in remote_players.keys():
		var remote: Node2D = remote_players[character_id]
		if remote == null or not is_instance_valid(remote):
			continue
		if not remote.visible:
			continue
		var moving_until := float(remote.get_meta("moving_until", 0.0))
		var is_moving := now <= moving_until
		if is_moving:
			var walk_time := float(remote.get_meta("walk_time", 0.0)) + delta
			var remote_class := str(remote.get_meta("class_name", "Guerreiro"))
			var direction := str(remote.get_meta("visual_direction", "front"))
			var frame_count := _remote_walk_frame_count(remote_class, direction)
			if frame_count <= 0:
				frame_count = 1
			while walk_time >= 0.085:
				walk_time -= 0.085
				var frame := int(remote.get_meta("walk_frame", 0))
				frame = (frame + 1) % frame_count
				remote.set_meta("walk_frame", frame)
			remote.set_meta("walk_time", walk_time)
			_update_remote_player_sprite(remote, true)
		else:
			remote.set_meta("walk_time", 0.0)
			remote.set_meta("walk_frame", 0)
			_update_remote_player_sprite(remote, false)

func _update_remote_player_motion(remote: Node2D, previous_position: Vector2, current_position: Vector2) -> void:
	var delta := current_position - previous_position
	if delta.length() <= 1.0:
		return
	var direction := "front"
	var flip_h := false
	if abs(delta.y) > abs(delta.x):
		direction = "back" if delta.y < 0 else "front"
	else:
		# o pack frames_192 tem a linha "right" desenhada; nao espelhar
		direction = "right" if delta.x > 0 else "left"
	remote.set_meta("visual_direction", direction)
	remote.set_meta("visual_flip_h", flip_h)
	remote.set_meta("walk_time", 0.0)
	remote.set_meta("walk_frame", 0)
	_update_remote_player_sprite(remote, true)

func _update_remote_player_sprite(remote: Node2D, moving: bool) -> void:
	if remote == null or not is_instance_valid(remote):
		return
	var sprite := remote.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var remote_class := str(remote.get_meta("class_name", "Guerreiro"))
	var direction := str(remote.get_meta("visual_direction", "front"))
	var flip_h := bool(remote.get_meta("visual_flip_h", false))
	var path := ""
	if moving:
		var frames := _remote_walk_frames(remote_class, direction)
		if not frames.is_empty():
			var frame_index := int(remote.get_meta("walk_frame", 0)) % frames.size()
			path = str(frames[frame_index])
		else:
			path = _player_direction_sprite_path(remote_class, direction, "_walk_1")
	if path.is_empty() or not ResourceLoader.exists(path):
		path = _player_direction_sprite_path(remote_class, direction)
	if path.is_empty() or not ResourceLoader.exists(path):
		path = _player_sprite_path_from_class(remote_class)
	var texture := _remote_load_texture(path)
	if texture == null:
		return
	sprite.texture = texture
	sprite.flip_h = flip_h
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _remote_walk_frames(player_class: String, direction: String) -> Array:
	var key := "%s|%s" % [player_class, direction]
	if remote_walk_frame_cache.has(key):
		return remote_walk_frame_cache[key]
	var frames: Array[String] = []
	var normalized_direction := direction
	if normalized_direction == "side":
		normalized_direction = "left"
	for i in range(1, 13):
		var path := _class_pack_walk_path(player_class, normalized_direction, i)
		if not ResourceLoader.exists(path):
			path = _player_direction_sprite_path(player_class, normalized_direction, "_walk_%d" % i)
		if ResourceLoader.exists(path):
			frames.append(path)
	remote_walk_frame_cache[key] = frames
	return frames

func _player_direction_sprite_path(player_class: String, direction: String, suffix: String = "") -> String:
	var normalized_direction := direction
	if normalized_direction == "side":
		normalized_direction = "left"
	var pack_path := _class_pack_path_by_folder(_class_pack_folder_from_class(player_class), normalized_direction, suffix)
	if not pack_path.is_empty() and ResourceLoader.exists(pack_path):
		return pack_path
	var prefix := ""
	match player_class:
		"Guerreiro":
			prefix = "guerreiro"
		"Mago":
			prefix = "mago"
		"Arqueiro":
			prefix = "arqueiro"
		_:
			prefix = "guerreiro"
	if prefix.is_empty():
		return ""
	return "res://assets/sprites/player_%s_art_%s%s.png" % [prefix, direction, suffix]

func _remote_walk_frame_count(player_class: String, direction: String) -> int:
	return _remote_walk_frames(player_class, direction).size()

func _remote_load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if remote_texture_cache.has(path):
		return remote_texture_cache[path]
	var texture := load(path) as Texture2D
	if texture != null:
		remote_texture_cache[path] = texture
	return texture

func _remove_remote_player(character_id: int) -> void:
	var remote: Node2D = remote_players.get(character_id, null)
	if remote != null and is_instance_valid(remote):
		remote.queue_free()
	remote_players.erase(character_id)

func _player_sprite_path_from_class(class_id: String) -> String:
	var pack_idle := _class_pack_idle_path(class_id, "front")
	if ResourceLoader.exists(pack_idle):
		return pack_idle
	match class_id:
		"Guerreiro":
			if ResourceLoader.exists("res://assets/sprites/player_guerreiro_art_front.png"):
				return "res://assets/sprites/player_guerreiro_art_front.png"
			return "res://assets/sprites/player_guerreiro.png"
		"Mago":
			if ResourceLoader.exists("res://assets/sprites/player_mago_art_front.png"):
				return "res://assets/sprites/player_mago_art_front.png"
			return "res://assets/sprites/player_mago.png"
		"Arqueiro":
			if ResourceLoader.exists("res://assets/sprites/player_arqueiro_art_front.png"):
				return "res://assets/sprites/player_arqueiro_art_front.png"
			return "res://assets/sprites/player_arqueiro.png"
	return "res://assets/sprites/player_guerreiro.png"

func _class_pack_folder_from_class(chosen_class: String) -> String:
	match chosen_class:
		"Guerreiro":
			return "guerreiro"
		"Mago":
			return "maga_de_fogo"
		"Maga de Fogo":
			return "maga_de_fogo"
		"Maga":
			return "maga_de_fogo"
		"Arqueiro":
			return "arqueiro"
	return ""

func _class_pack_base_path(chosen_class: String) -> String:
	var folder := _class_pack_folder_from_class(chosen_class)
	if folder.is_empty():
		return ""
	return "%s/%s/frames_192/%s" % [WALK_CLASS_ASSET_ROOT, folder, folder]

func _class_pack_path_by_folder(folder: String, direction: String, suffix: String = "") -> String:
	if folder.is_empty():
		return ""
	var base := "%s/%s/frames_192/%s" % [WALK_CLASS_ASSET_ROOT, folder, folder]
	if suffix.is_empty():
		return "%s_idle_%s.png" % [base, direction]
	var frame_text := suffix.trim_prefix("_walk_")
	if frame_text.is_valid_int():
		return "%s_walk_%s_%d.png" % [base, direction, int(frame_text)]
	return "%s%s.png" % [base, suffix]

func _class_pack_idle_path(chosen_class: String, direction: String) -> String:
	var base := _class_pack_base_path(chosen_class)
	if base.is_empty():
		return ""
	return "%s_idle_%s.png" % [base, direction]

func _class_pack_walk_path(chosen_class: String, direction: String, frame: int) -> String:
	var base := _class_pack_base_path(chosen_class)
	if base.is_empty():
		return ""
	return "%s_walk_%s_%d.png" % [base, direction, frame]

func _build_ui() -> void:
	hud_frame = Panel.new()
	hud_frame.position = Vector2(8, 8)
	hud_frame.size = Vector2(354, 132)
	hud_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_frame.z_index = 90
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0, 0, 0, 0)
	hud_style.border_color = Color(0, 0, 0, 0)
	hud_style.set_border_width_all(0)
	hud_frame.add_theme_stylebox_override("panel", hud_style)
	ui.add_child(hud_frame)
	hud_skin_rect = _make_texture_rect("res://assets/ui/hud/bars/player_status_panel_clean.png", HUD_PANEL_POS, HUD_PANEL_SIZE)
	hud_skin_rect.z_index = 89

	hud_label = Label.new()
	hud_label.z_index = 95
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_label.clip_text = true
	hud_label.add_theme_color_override("font_color", Color("#f7e6b1"))
	hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud_label.add_theme_constant_override("shadow_offset_x", 1)
	hud_label.add_theme_constant_override("shadow_offset_y", 1)
	hud_label.add_theme_font_size_override("font_size", 12)
	ui.add_child(hud_label)
	xp_label = Label.new()
	xp_label.visible = false
	xp_label.position = Vector2.ZERO
	xp_label.size = Vector2.ZERO
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.z_index = 91
	xp_label.add_theme_color_override("font_color", Color("#fff2bf"))
	xp_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	xp_label.add_theme_constant_override("shadow_offset_x", 1)
	xp_label.add_theme_constant_override("shadow_offset_y", 1)
	xp_label.add_theme_font_size_override("font_size", 15)
	ui.add_child(xp_label)
	hp_label = Label.new()
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.clip_text = true
	hp_label.z_index = 94
	hp_label.add_theme_color_override("font_color", Color("#ffd9d9"))
	hp_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hp_label.add_theme_constant_override("shadow_offset_x", 1)
	hp_label.add_theme_constant_override("shadow_offset_y", 1)
	hp_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(hp_label)
	hp_bar = _make_texture_progress_bar_layers("hp", HUD_HP_BAR_POS, HUD_BAR_SIZE, 92)
	mana_label = Label.new()
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mana_label.clip_text = true
	mana_label.z_index = 94
	mana_label.add_theme_color_override("font_color", Color("#d8e5ff"))
	mana_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	mana_label.add_theme_constant_override("shadow_offset_x", 1)
	mana_label.add_theme_constant_override("shadow_offset_y", 1)
	mana_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(mana_label)
	mana_bar = _make_texture_progress_bar_layers("mp", HUD_MP_BAR_POS, HUD_BAR_SIZE, 92)
	xp_value_label = Label.new()
	xp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_value_label.clip_text = true
	xp_value_label.z_index = 94
	xp_value_label.add_theme_color_override("font_color", Color("#f8e4aa"))
	xp_value_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	xp_value_label.add_theme_constant_override("shadow_offset_x", 1)
	xp_value_label.add_theme_constant_override("shadow_offset_y", 1)
	xp_value_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(xp_value_label)
	xp_bar = _make_texture_progress_bar_layers("xp", HUD_XP_BAR_POS, HUD_BAR_SIZE, 92)
	message_label = Label.new()
	message_label.position = Vector2(410, 18)
	message_label.size = Vector2(460, 30)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.z_index = 181
	message_label.add_theme_color_override("font_color", Color("#ffe8a3"))
	ui.add_child(message_label)
	minimap_panel = PanelContainer.new()
	minimap_panel.position = MINIMAP_CANVAS_POS
	minimap_panel.size = MINIMAP_SIZE
	minimap_panel.z_index = 149
	var minimap_style := StyleBoxFlat.new()
	minimap_style.bg_color = Color(0, 0, 0, 0)
	minimap_style.border_color = Color(0, 0, 0, 0)
	minimap_style.set_border_width_all(0)
	minimap_panel.add_theme_stylebox_override("panel", minimap_style)
	ui.add_child(minimap_panel)
	minimap_frame_rect = _make_texture_rect("res://assets/ui/hud/minimap_frame.png", MINIMAP_FRAME_POS, MINIMAP_FRAME_SIZE)
	minimap_frame_rect.z_index = 151
	minimap_canvas = Control.new()
	minimap_canvas.position = MINIMAP_CANVAS_POS
	minimap_canvas.size = MINIMAP_SIZE
	minimap_canvas.clip_contents = true
	minimap_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_canvas.z_index = 150
	ui.add_child(minimap_canvas)
	_layout_status_hud()
	_layout_minimap_hud()
	panel_blocker = ColorRect.new()
	panel_blocker.color = Color(0, 0, 0, 0.28)
	panel_blocker.anchor_left = 0.0
	panel_blocker.anchor_top = 0.0
	panel_blocker.anchor_right = 1.0
	panel_blocker.anchor_bottom = 1.0
	panel_blocker.offset_left = 0.0
	panel_blocker.offset_top = 0.0
	panel_blocker.offset_right = 0.0
	panel_blocker.offset_bottom = 0.0
	panel_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_blocker.visible = false
	panel_blocker.z_index = 900
	ui.add_child(panel_blocker)
	panel = PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(180, 72)
	panel.size = Vector2(920, 560)
	panel.custom_minimum_size = Vector2(920, 560)
	panel.z_index = 901
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.018, 0.023, 0.94)
	panel_style.border_color = Color(1, 1, 1, 0.30)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(panel)
	input_guard = ColorRect.new()
	input_guard.color = Color(0, 0, 0, 0)
	input_guard.anchor_left = 0.0
	input_guard.anchor_top = 0.0
	input_guard.anchor_right = 1.0
	input_guard.anchor_bottom = 1.0
	input_guard.offset_left = 0.0
	input_guard.offset_top = 0.0
	input_guard.offset_right = 0.0
	input_guard.offset_bottom = 0.0
	input_guard.mouse_filter = Control.MOUSE_FILTER_STOP
	input_guard.visible = false
	input_guard.z_index = 899
	ui.add_child(input_guard)
	_build_potion_bar()
	_build_touch_controls()
	_build_chat_panel()
	_build_side_menu()
	game_extras = GameExtras.new()
	game_extras.name = "GameExtras"
	add_child(game_extras)
	game_extras.setup(self)
	_apply_hud_layout_to_touch_controls()
	_refresh_modal_layout()

func _build_touch_controls() -> void:
	_build_joystick()
	attack_button = _make_tap_button("ATK", hud_attack_pos, Vector2(116, 86), func() -> void:
		if player != null:
			player.basic_attack()
	)
	_add_shortcut_badge(attack_button, "1")
	skill_buttons.clear()
	var skill_1 := _make_tap_button("2", SKILL_BUTTON_POSITIONS[0], SKILL_BUTTON_SIZE, func() -> void:
		if player != null:
			player.use_skill(0)
	)
	_prepare_skill_button_feedback(skill_1)
	_add_shortcut_badge(skill_1, "2")
	skill_buttons.append(skill_1)
	var skill_2 := _make_tap_button("3", SKILL_BUTTON_POSITIONS[1], SKILL_BUTTON_SIZE, func() -> void:
		if player != null:
			player.use_skill(1)
	)
	_prepare_skill_button_feedback(skill_2)
	_add_shortcut_badge(skill_2, "3")
	skill_buttons.append(skill_2)
	var skill_3 := _make_tap_button("4", SKILL_BUTTON_POSITIONS[2], SKILL_BUTTON_SIZE, func() -> void:
		if player != null:
			player.use_skill(2)
	)
	_prepare_skill_button_feedback(skill_3)
	_add_shortcut_badge(skill_3, "4")
	skill_buttons.append(skill_3)
	pet_button = _make_tap_button("", PET_BUTTON_POS, MOUNT_BUTTON_SIZE, func() -> void:
		_interact_with_pet()
	)
	pet_button.expand_icon = true
	pet_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pet_button_label = Label.new()
	pet_button_label.position = Vector2(0, 38)
	pet_button_label.size = Vector2(64, 18)
	pet_button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pet_button_label.add_theme_font_size_override("font_size", 13)
	pet_button_label.add_theme_color_override("font_color", Color("#ffb3c8"))
	pet_button_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	pet_button_label.add_theme_constant_override("shadow_offset_x", 1)
	pet_button_label.add_theme_constant_override("shadow_offset_y", 1)
	pet_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet_button.add_child(pet_button_label)
	pet_button.visible = false
	mount_button = _make_tap_button("", MOUNT_BUTTON_POS, MOUNT_BUTTON_SIZE, _toggle_mount)
	mount_button.expand_icon = true
	mount_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prepare_skill_button_feedback(mount_button)
	_add_shortcut_badge(mount_button, "R")
	mount_button.visible = false
	interact_button = _make_tap_button("OK", INTERACT_BUTTON_POS, INTERACT_BUTTON_SIZE, _interact)
	_style_interact_button(interact_button)
	inventory_button = _make_tap_button("", QUICK_TOP_BUTTON_POSITIONS[0], QUICK_TOP_BUTTON_SIZE, _show_inventory)
	character_button = _make_tap_button("", QUICK_TOP_BUTTON_POSITIONS[1], QUICK_TOP_BUTTON_SIZE, _show_skills_window)
	quests_button = _make_tap_button("", QUICK_TOP_BUTTON_POSITIONS[2], QUICK_TOP_BUTTON_SIZE, _show_quests)
	chat_button = _make_tap_button("CHAT", QUICK_TOP_BUTTON_POSITIONS[3], QUICK_TOP_BUTTON_SIZE, _toggle_chat_panel)
	_style_quick_top_button(inventory_button, "res://assets/ui/buttons/btn_inventory.png", "Bolsa")
	_style_quick_top_button(character_button, "res://assets/ui/buttons/btn_character.png", "Habilidades")
	_style_quick_top_button(quests_button, "res://assets/ui/buttons/btn_quest.png", "Missoes")
	_style_quick_top_button(chat_button, "res://assets/ui/buttons/btn_chat.png", "Chat")
	chat_button.text = ""

func _build_side_menu() -> void:
	side_menu_buttons.clear()
	side_menu_toggle_button = Button.new()
	side_menu_toggle_button.text = ""
	side_menu_toggle_button.position = Vector2(1128, 8)
	side_menu_toggle_button.size = Vector2(66, 54)
	side_menu_toggle_button.custom_minimum_size = side_menu_toggle_button.size
	side_menu_toggle_button.focus_mode = Control.FOCUS_NONE
	side_menu_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	side_menu_toggle_button.z_index = 940
	_apply_texture_button_style(side_menu_toggle_button)
	_apply_button_icon(side_menu_toggle_button, "res://assets/ui/buttons/btn_menu.png", "MENU", "Menu")
	side_menu_toggle_button.pressed.connect(func() -> void:
		_toggle_side_menu()
	)
	touch_button_callbacks[side_menu_toggle_button] = Callable(self, "_toggle_side_menu")
	touch_buttons.append(side_menu_toggle_button)
	ui.add_child(side_menu_toggle_button)

	side_menu_panel = PanelContainer.new()
	side_menu_panel.position = Vector2(1272 - SIDE_MENU_PANEL_SIZE.x, 54)
	side_menu_panel.size = SIDE_MENU_PANEL_SIZE
	side_menu_panel.visible = false
	side_menu_panel.z_index = 941
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.016, 0.014, 0.94)
	style.border_color = Color("#c49b3f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	side_menu_panel.add_theme_stylebox_override("panel", style)
	var scroller := ScrollContainer.new()
	scroller.custom_minimum_size = SIDE_MENU_PANEL_SIZE - Vector2(12, 12)
	scroller.size = SIDE_MENU_PANEL_SIZE - Vector2(12, 12)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	side_menu_panel.add_child(scroller)
	var list := GridContainer.new()
	list.columns = 2
	list.add_theme_constant_override("h_separation", 8)
	list.add_theme_constant_override("v_separation", 8)
	scroller.add_child(list)
	for item in UISideMenu.MENU_ITEMS:
		var item_label := str(item)
		var button := Button.new()
		button.text = item_label
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var tab_path := "res://assets/ui/menu_tabs/%s.png" % item_label
		if ResourceLoader.exists(tab_path):
			_style_side_menu_tab(button, load(tab_path) as Texture2D, item_label)
		else:
			var icon_path := str(UISideMenu.MENU_ICON_BY_ITEM.get(item_label, ""))
			if not icon_path.is_empty():
				button.icon = load(icon_path)
				button.expand_icon = true
			UISideMenu.style_button(button)
			button.custom_minimum_size = SIDE_MENU_TAB_SIZE
		button.set_meta("menu_item", item_label)
		button.pressed.connect(Callable(self, "_handle_side_menu").bind(item_label))
		list.add_child(button)
		side_menu_buttons.append(button)
	ui.add_child(side_menu_panel)
	_sync_side_menu_mouse_filter()

func _handle_side_menu(item: String) -> void:
	AudioManager.play_sfx("clique")
	match item:
		"Habilidades":
			_show_skills_window()
		"Roupa":
			_show_equipment_window()
		"Bolsa":
			_show_inventory()
		"Mapa":
			_show_world_map()
		"Missoes":
			_show_quests()
		"Banco":
			_show_bank()
		"Profissoes":
			_show_professions()
		"Pets":
			_show_pets()
		"Montarias":
			_show_mounts()
		"Dungeon":
			_show_dungeons()
		"Rank":
			if not online_mode and game_extras != null:  # offline: recordes locais contra chefes
				game_extras.show_records()
			else:
				_show_rank()
		"Mercado":
			_show_market()
		"VIP":
			_show_vip()
		"Conquistas":
			_show_achievements()
		"Diarias":
			if game_extras != null:
				game_extras.show_daily()
		"Colecao":
			if game_extras != null:
				game_extras.show_collection()
		"Talentos":
			if game_extras != null:
				game_extras.show_talents()
		"Eventos":
			if game_extras != null:
				game_extras.show_events()
		"Foto":
			if game_extras != null:
				_toggle_side_menu()
				game_extras.toggle_photo_mode()
		"Temporada":
			_show_season()
		"HUD":
			_show_hud_editor()
		"Wikipedia":
			_show_wikipedia()
		"Manual":
			_show_wikipedia()
		"Configuracoes":
			if game_extras != null:
				game_extras.show_settings()
			else:
				_flash("Sistema de configuracoes ainda em desenvolvimento.")
		"Deslogar":
			_logout_to_start()
		_:
			_flash("Sistema ainda em desenvolvimento.")

func _logout_to_start() -> void:
	if player != null:
		if online_mode:
			_send_online_save_state()
		else:
			SaveSystem.save_game(player, quest_system, current_map, exploration_by_map, mmo_cache)
	for child in world.get_children():
		child.queue_free()
	player = null
	current_target = null
	selected_npc = null
	selected_portal = null
	current_map = FOREST_PRIMARY_MAP_ID
	last_valid_player_position = Vector2.ZERO
	side_menu_visible = false
	if side_menu_panel != null:
		side_menu_panel.visible = false
	if panel.visible:
		_hide_panel()
	_close_chat_panel()
	online_mode = false
	if mmo_client != null:
		mmo_client.set("online_enabled", false)
		mmo_client.set("token", "")
	chat_last_sent_channel = ""
	chat_last_sent_text = ""
	chat_last_sent_at = 0.0
	_show_class_selection()
	_flash("Deslogado. Escolha a classe para entrar novamente.")

func _activate_touch_region(pos: Vector2) -> void:
	if Rect2(Vector2(1080, 535), Vector2(170, 150)).has_point(pos):
		player.basic_attack()
	elif Rect2(Vector2(0, 72), Vector2(415, 58)).has_point(pos):
		_activate_potion_region(pos)
	elif Rect2(Vector2(875, 565), Vector2(105, 95)).has_point(pos):
		player.use_skill(0)
	elif Rect2(Vector2(950, 505), Vector2(105, 95)).has_point(pos):
		player.use_skill(1)
	elif Rect2(Vector2(1025, 445), Vector2(105, 95)).has_point(pos):
		player.use_skill(2)
	elif Rect2(Vector2(1140, 430), Vector2(105, 95)).has_point(pos):
		_interact()
	elif Rect2(Vector2(1015, 60), Vector2(85, 90)).has_point(pos):
		_show_inventory()
	elif Rect2(Vector2(1080, 60), Vector2(85, 90)).has_point(pos):
		_show_character()
	elif Rect2(Vector2(1140, 60), Vector2(95, 90)).has_point(pos):
		_show_quests()

func _show_class_selection() -> void:
	if online_mode:
		_flash("Modo online ativo: escolha de classe e personagem no launcher.")
		return
	if launcher_boot_started:
		return
	var backdrop := ColorRect.new()
	backdrop.name = "ClassSelectionBackdrop"
	backdrop.anchor_left = 0.0
	backdrop.anchor_top = 0.0
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = 0.0
	backdrop.offset_bottom = 0.0
	backdrop.color = Color(0.06, 0.06, 0.08, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(backdrop)
	var box := PanelContainer.new()
	box.name = "ClassSelectionBox"
	box.custom_minimum_size = Vector2(420, 380)
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -210.0
	box.offset_top = -190.0
	box.offset_right = 210.0
	box.offset_bottom = 190.0
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(box)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	box.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Arcadia Realms 2D\nEscolha sua classe"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)
	for class_label in class_db.all_classes():
		var btn := Button.new()
		btn.text = str(class_label)
		btn.custom_minimum_size = Vector2(360, 64)
		btn.pressed.connect(func() -> void:
			if panel_blocker != null:
				panel_blocker.visible = false
			backdrop.queue_free()
			box.queue_free()
			_start_new_game(str(class_label))
		)
		vbox.add_child(btn)

func _start_new_game(chosen_class: String) -> void:
	if online_mode:
		_flash("Use o launcher MMO para iniciar online.")
		return
	if player != null and is_instance_valid(player):
		return
	launcher_boot_started = true
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.setup(chosen_class, class_db.get_class_data(chosen_class), item_db)
	mmo_cache = {}
	_ensure_local_companion_state()
	_ensure_beginner_quests()
	_connect_player()
	_update_action_icons()
	_load_home_city()
	_flash("Mapa base carregado. Vamos reconstruir do zero.")

func launcher_boot_offline(chosen_class: String = "Guerreiro") -> void:
	if online_mode:
		return
	if player != null and is_instance_valid(player):
		return
	launcher_boot_started = true
	_start_new_game(chosen_class)

func _spawn_player_from_save(save: Dictionary) -> void:
	if online_mode:
		_flash("Save local desativado no modo online.")
		return
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.from_save(save.get("player", {}), item_db, class_db)
	quest_system.from_save(save.get("quests", {}))
	exploration_by_map = save.get("exploration", {})
	mmo_cache = save.get("mmo_cache", {})
	_ensure_local_companion_state()
	_ensure_beginner_quests()
	_connect_player()
	_update_action_icons()
	_apply_companion_bonuses()
	# O jogo sempre comeca na cidade base (Eldoria, ou Valdoria depois de chegar la).
	_load_home_city()
	_flash("Save carregado.")

func _connect_player() -> void:
	player.attack_requested.connect(_player_attack)
	player.skill_area_requested.connect(_player_area_attack)
	player.dash_requested.connect(_player_dash)
	player.self_effect_requested.connect(_player_self_effect)
	player.damage_taken.connect(func(amount: int) -> void:
		if _mount_absorbs_hit():
			mount_combat_until = _now_s() + float(_rule(["montaria", "espera_remontar_s"], MOUNT_REMOUNT_DELAY))
			_flash("A couraca da montaria aguentou o golpe!")
		else:
			_enter_combat_dismount("Voce desceu da montaria ao tomar dano.")
		_spawn_floating_text(player.global_position + Vector2(0, -42), "-%d" % amount, Color("#ff4f4f"))
	)
	player.healed.connect(func(amount: int) -> void:
		_spawn_floating_text(player.global_position + Vector2(0, -56), "+%d" % amount, Color("#69ff7c"))
	)
	player.message_requested.connect(_flash)
	player.died.connect(_player_died)
	player.dodge_cfg = _rule(["esquiva"], {})
	if not mmo_cache.has("talentos") or typeof(mmo_cache["talentos"]) != TYPE_DICTIONARY:
		mmo_cache["talentos"] = {}
	player.talents = mmo_cache["talentos"]
	player.talent_tree = _rule(["talentos", player.class_name_selected], [])
	player.recalculate_equipment()
	_ensure_player_camera()

func _ensure_beginner_quests() -> void:
	for quest_id in BEGINNER_QUESTS:
		if quest_system.completed.has(quest_id):
			continue
		if not quest_system.active.has(quest_id):
			quest_system.accept(quest_id)

func _load_home_city() -> void:
	_load_map(_home_city())

func _load_map(map_id: String, spawn_position: Vector2 = Vector2.ZERO) -> void:
	var resolved_map_id := _resolve_map_id(map_id)
	current_map = resolved_map_id
	if resolved_map_id == "city_valdoria" and quest_system != null and not _has_world_flag("chegou_valdoria"):
		quest_system.completed.append("flag:chegou_valdoria")
	_ensure_map_exploration(resolved_map_id)
	safe_zone_nodes.clear()
	solid_obstacles.clear()
	portal_passage_rects.clear()
	portal_nodes.clear()
	kit_vehicles.clear()
	for child in world.get_children():
		if child != player:
			child.queue_free()
	remote_players.clear()
	var map_data: Dictionary = maps.get(resolved_map_id, maps.get(FOREST_PRIMARY_MAP_ID, {}))
	var size_data: Array = map_data.get("size", [int(DEFAULT_MAP_SIZE.x), int(DEFAULT_MAP_SIZE.y)])
	current_map_size = Vector2(float(size_data[0]), float(size_data[1]))
	if _is_new_eldoria_map():
		current_map_size = ELDORIA_WORLD_SIZE
	elif _valdoria_v2_active():
		var valdoria_size: Array = _get_valdoria_kit_data().get("world_size", [6400, 5760])
		current_map_size = Vector2(float(valdoria_size[0]), float(valdoria_size[1]))
	elif _is_new_valdoria_map():
		current_map_size = VALDORIA_WORLD_SIZE
	elif _is_forest_runtime_map() and _forest_chunks_available():
		current_map_size = FOREST_WORLD_SIZE
	elif _cave_v2_active():
		var cave_size: Array = _get_cave_kit_data().get("world_size", [4800, 3840])
		current_map_size = Vector2(float(cave_size[0]), float(cave_size[1]))
	elif current_map == "bat_cave" and _cave_background_available():
		current_map_size = CAVE_SOURCE_SIZE
	_draw_map_background(map_data)
	if player != null:
		var spawn: Array = map_data.get("spawn", [1080, 760])
		var desired_spawn := spawn_position if spawn_position != Vector2.ZERO else _map_data_point(spawn)
		if _is_new_eldoria_map() and spawn_position == Vector2.ZERO:
			desired_spawn = Vector2(2508, 2720)
		elif _is_new_valdoria_map() and spawn_position == Vector2.ZERO:
			desired_spawn = _valdoria_point(627, 1096)
		player.global_position = _resolve_unblocked_spawn(desired_spawn)
		last_valid_player_position = player.global_position
		quest_system.register_visit(resolved_map_id)
	_spawn_npcs(map_data)
	_spawn_portals(map_data)
	_spawn_safe_zones(map_data)
	_spawn_enemies(map_data)
	_spawn_map_collectibles(map_data)
	_update_safe_zone_state()
	_update_camera_limits()
	_cleanup_remote_players_for_map()
	_flash(str(map_data.get("name", resolved_map_id)))

func _consume_launcher_auto_start_offline() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	if not bool(tree.get_meta("launcher_auto_start_offline", false)):
		return false
	tree.remove_meta("launcher_auto_start_offline")
	return true

func _consume_launcher_offline_boot() -> Dictionary:
	if mmo_client == null or not mmo_client.has_method("consume_offline_start"):
		return {}
	var payload = mmo_client.call("consume_offline_start")
	if typeof(payload) != TYPE_DICTIONARY:
		return {}
	return payload

func _launcher_auto_class() -> String:
	var tree := get_tree()
	if tree == null:
		return "Guerreiro"
	var chosen := str(tree.get_meta("launcher_auto_class", "Guerreiro"))
	tree.remove_meta("launcher_auto_class")
	if chosen.is_empty():
		return "Guerreiro"
	return chosen

func _consume_direct_launcher_offline_class() -> String:
	if not has_meta("launcher_force_offline_class"):
		return ""
	var chosen := str(get_meta("launcher_force_offline_class", "Guerreiro"))
	remove_meta("launcher_force_offline_class")
	if chosen.is_empty():
		return "Guerreiro"
	return chosen

func _spawn_enemies(map_data: Dictionary) -> void:
	var occupied_spawn_positions: Array[Vector2] = []
	for spawn in map_data.get("spawns", []):
		var spawn_count: int = max(1, int(spawn.get("count", 1)))
		for i in range(spawn_count):
			_spawn_enemy_from_spawn(spawn, i, spawn_count, occupied_spawn_positions)

func _spawn_enemy_from_spawn(spawn: Dictionary, spawn_index: int = 0, spawn_total: int = 1, occupied_spawn_positions: Array[Vector2] = []) -> void:
	var enemy_name := str(spawn.get("enemy", ""))
	if enemy_name.is_empty():
		return
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	world.add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.setup(enemy_name, enemies_db.get(enemy_name, {}), player)
	enemy.safe_zone_checker = Callable(self, "_is_point_in_safe_zone")
	enemy.obstacle_checker = Callable(self, "_is_point_blocked")
	enemy.summon_callback = Callable(self, "_spawn_boss_minion")
	enemy.global_position = _random_enemy_spawn_position(spawn, spawn_index, spawn_total, occupied_spawn_positions)
	enemy.z_index = clampi(int(enemy.global_position.y), -1024, 1024)
	occupied_spawn_positions.append(enemy.global_position)
	enemy.set_meta("spawn_data", spawn.duplicate(true))
	enemy.set_meta("spawn_map", current_map)
	if bool(spawn.get("boss", false)):
		enemy.add_to_group("bosses")
	enemy.killed.connect(_enemy_killed)

# Lacaio chamado por golpe de chefe ("invocar"): nao renasce (sem spawn_data) e da XP/drop normal.
func _spawn_boss_minion(enemy_name: String, pos: Vector2) -> Variant:
	if not enemies_db.has(enemy_name) or _is_point_blocked(pos) or _is_point_in_safe_zone(pos):
		return null
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	world.add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.setup(enemy_name, enemies_db.get(enemy_name, {}), player)
	enemy.safe_zone_checker = Callable(self, "_is_point_in_safe_zone")
	enemy.obstacle_checker = Callable(self, "_is_point_blocked")
	enemy.global_position = pos
	enemy.z_index = clampi(int(pos.y), -1024, 1024)
	enemy.set_meta("spawn_map", current_map)
	enemy.killed.connect(_enemy_killed)
	return enemy

# Chefe de evento (game_rules.json -> chefes_evento): entra no grupo "bosses" e nao renasce
func _spawn_event_boss(enemy_name: String, pos: Vector2) -> Enemy:
	var enemy: Variant = _spawn_boss_minion(enemy_name, pos)
	if enemy == null:
		return null
	(enemy as Enemy).add_to_group("bosses")
	return enemy

func _spawn_position_is_clear(pos: Vector2, occupied_positions: Array[Vector2], min_distance: float) -> bool:
	for other_pos in occupied_positions:
		if pos.distance_to(other_pos) < min_distance:
			return false
	return true

func _random_enemy_spawn_position(spawn: Dictionary = {}, spawn_index: int = 0, spawn_total: int = 1, occupied_positions: Array[Vector2] = []) -> Vector2:
	var zone: Array = spawn.get("zone", [])
	var pos := Vector2(randf_range(120, current_map_size.x - 120), randf_range(120, current_map_size.y - 120))
	var min_spacing := 96.0
	if current_map == "forest_boars":
		min_spacing = 132.0
	if zone.size() >= 4:
		var zone_scale := FOREST_WORLD_SCALE if current_map == "forest_boars" else 1.0
		var zone_origin := Vector2(float(zone[0]), float(zone[1])) * zone_scale
		var zone_size := Vector2(float(zone[2]), float(zone[3])) * zone_scale
		var columns := clampi(int(ceil(sqrt(float(spawn_total)))), 1, 4)
		var rows := maxi(1, int(ceil(float(spawn_total) / float(columns))))
		var col := spawn_index % columns
		var row := spawn_index / columns
		var step_x := zone_size.x / float(columns + 1)
		var step_y := zone_size.y / float(rows + 1)
		pos = zone_origin + Vector2(step_x * float(col + 1), step_y * float(row + 1))
		if current_map == "forest_boars":
			var jitter_x := sin(float(spawn_index + 1) * 2.137) * zone_size.x * 0.06
			var jitter_y := cos(float(spawn_index + 2) * 1.781) * zone_size.y * 0.06
			pos += Vector2(jitter_x, jitter_y)
	var retries := 0
	while (_is_point_in_safe_zone(pos) or _is_point_blocked(pos) or not _spawn_position_is_clear(pos, occupied_positions, min_spacing)) and retries < 32:
		if zone.size() >= 4:
			var zone_scale := FOREST_WORLD_SCALE if current_map == "forest_boars" else 1.0
			var zone_origin := Vector2(float(zone[0]), float(zone[1])) * zone_scale
			var zone_size := Vector2(float(zone[2]), float(zone[3])) * zone_scale
			var base_columns := clampi(int(ceil(sqrt(float(spawn_total)))), 1, 4)
			var base_rows := maxi(1, int(ceil(float(spawn_total) / float(base_columns))))
			var base_col := retries % base_columns
			var base_row := int(retries / base_columns) % base_rows
			var base_step_x := zone_size.x / float(base_columns + 1)
			var base_step_y := zone_size.y / float(base_rows + 1)
			pos = zone_origin + Vector2(base_step_x * float(base_col + 1), base_step_y * float(base_row + 1))
			if current_map == "forest_boars":
				var retry_jitter_x := sin(float(retries + 1) * 1.913) * zone_size.x * 0.08
				var retry_jitter_y := cos(float(retries + 3) * 2.117) * zone_size.y * 0.08
				pos += Vector2(retry_jitter_x, retry_jitter_y)
		else:
			pos = Vector2(randf_range(120, current_map_size.x - 120), randf_range(120, current_map_size.y - 120))
		retries += 1
	if current_map == "forest_boars" and (_is_point_in_safe_zone(pos) or _is_point_blocked(pos)):
		var safe_center := _map_data_point([200, 190])
		var outward := (pos - safe_center).normalized()
		if outward == Vector2.ZERO:
			outward = Vector2.RIGHT
		pos = safe_center + outward * (_map_data_radius(190.0) + 160.0)
		if zone.size() >= 4:
			var zone_scale := FOREST_WORLD_SCALE if current_map == "forest_boars" else 1.0
			var zone_origin := Vector2(float(zone[0]), float(zone[1])) * zone_scale
			var zone_size := Vector2(float(zone[2]), float(zone[3])) * zone_scale
			pos = pos.clamp(zone_origin + Vector2(36, 36), zone_origin + zone_size - Vector2(36, 36))
	if _is_point_in_safe_zone(pos) or _is_point_blocked(pos):
		pos = _resolve_unblocked_spawn(pos, true)
	return pos

func _schedule_enemy_respawn(enemy_name: String, spawn_data: Dictionary, map_id: String) -> void:
	var delay := _enemy_respawn_delay(enemy_name, spawn_data)
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(delay).timeout
	if current_map != map_id or player == null:
		return
	_spawn_enemy_from_spawn(spawn_data)

func _enemy_killed(enemy: Enemy) -> void:
	if pet_allowed_target == enemy:
		pet_allowed_target = null
	if pet_need == "espadas" and is_instance_valid(enemy) and pet_pos.distance_to(enemy.global_position) < 520.0:
		_finish_pet_need(true)
	var spawn_data: Dictionary = enemy.get_meta("spawn_data", {})
	var spawn_map := str(enemy.get_meta("spawn_map", current_map))
	var was_boss := bool(enemy.boss) or bool(spawn_data.get("boss", false))
	var result := drop_system.roll(enemy.enemy_name)
	if game_extras != null:
		if was_boss:
			game_extras.note_boss_fight(enemy)
		game_extras.on_kill(enemy.enemy_name, was_boss)
	player.gain_xp(int(result["xp"]))
	player.on_enemy_killed()
	quest_system.register_kill(enemy.enemy_name)
	var gold := int(result["ouro"])
	if gold > 0:
		_spawn_coin_drop(gold, enemy.global_position + Vector2(randf_range(-18, 18), randf_range(-18, 18)))
	for item_name in result["items"]:
		_spawn_drop(str(item_name), enemy.global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24)))
	if was_boss:
		_open_boss_portal_permanently(spawn_map, enemy.enemy_name)
		if online_mode:
			_send_online_save_state()
		else:
			SaveSystem.save_game(player, quest_system, current_map, exploration_by_map, mmo_cache)
		_flash("Boss derrotado: portal liberado permanentemente.")
	else:
		_flash("+%d XP, moedas e drops no chao" % int(result["xp"]))
	if not spawn_data.is_empty():
		_schedule_enemy_respawn(enemy.enemy_name, spawn_data, spawn_map)

func _interact() -> void:
	if selected_npc != null and not is_instance_valid(selected_npc):
		selected_npc = null
	# pet pedindo algo e perto do heroi: E/OK atende o pet
	if selected_npc == null and not pet_need.is_empty() and player != null and pet_pos.distance_to(player.global_position) < 220.0:
		_interact_with_pet()
		return
	if selected_npc != null:
		if game_extras != null:
			game_extras.on_npc(selected_npc)
		_deliver_quest_talk(selected_npc)
		if _offer_npc_quests(selected_npc):
			return
		match selected_npc.role:
			"healer":
				_use_healer()
			"shop":
				_show_shop("Loja do %s" % selected_npc.npc_name.get_slice(",", 0).strip_edges())
			"forge":
				_show_forge()
			"rare_forge":
				_show_forge("rare")
			"pet_shop":
				_show_pet_shop()
			"mount_shop":
				_show_mount_shop()
			"class_master":
				_flash("Marcos: treine usando ataque, defesa e velocidade em combate real.")
			"quest":
				_handle_quest_npc(selected_npc.quest_id)
			"talk":
				# NPC so de conversa (Mineiro Perdido, Maga Selene): repete a fala dele.
				var line := str(selected_npc.get_meta("greeting", ""))
				if not line.is_empty():
					_show_npc_bubble(selected_npc, line)
			"harbor":
				_use_harbor_master(selected_npc)
		return
	if _collect_nearest_manual_drop():
		return
	if selected_portal == null:
		_update_nearby_portal()
	if selected_portal != null:
		if _is_portal_blocked_by_boss(selected_portal):
			var boss_name := str(selected_portal.get_meta("boss_enemy"))
			_flash_red("Derrote %s para liberar este portal." % boss_name)
			return
		var spawn := Vector2.ZERO
		var spawn_data = selected_portal.get_meta("target_spawn")
		if typeof(spawn_data) == TYPE_ARRAY and spawn_data.size() >= 2:
			spawn = Vector2(float(spawn_data[0]), float(spawn_data[1]))
		_load_map(str(selected_portal.get_meta("target")), spawn)
		if online_mode and mmo_client != null and player != null:
			net_move_accumulator = 0.0
			mmo_client.call("send_move", current_map, player.global_position)
			_send_online_save_state()
		return
	_hide_panel()

# Mestre do porto (Valdoria): a primeira conversa libera a rota entre as cidades
# e ja abre o portal de volta no mapa atual.
func _use_harbor_master(npc: Npc) -> void:
	var flag := str(npc.get_meta("unlock_flag", ""))
	if flag.is_empty():
		return
	if _has_world_flag(flag):
		_show_npc_bubble(npc, str(npc.get_meta("unlocked_text", "A rota ja esta aberta.")))
		return
	_set_world_flag(flag)
	_show_npc_bubble(npc, str(npc.get_meta("unlock_text", "Rota liberada!")))
	_flash("Rota liberada: portal entre Eldoria e Valdoria aberto!")
	if not PORTALS_FREE_ACCESS:  # com acesso livre o portal ja existe; nao duplica
		_spawn_portals(maps.get(current_map, {}), flag)

func _use_healer() -> void:
	var healer_name := "Helena"
	var shop_title := ""
	if selected_npc != null and is_instance_valid(selected_npc) and current_map == "city_eldoria":
		healer_name = selected_npc.npc_name.get_slice(",", 0)
		shop_title = "Pocoes de %s" % healer_name
	var cost := 0 if player.level <= 5 else 10
	if player.ouro >= cost:
		player.ouro -= cost
		player.vida = player.vida_max
		player.mana = player.mana_max
		player.stats_changed.emit()
		_flash("%s curou voce." % healer_name)
		if selected_npc != null and is_instance_valid(selected_npc):
			_spawn_floating_text(player.global_position + Vector2(0, -60), "+VIDA +MANA", Color("#7dff9a"))
	else:
		_flash("%s cobra 10 ouro depois do level 5." % healer_name)
	if not shop_title.is_empty():
		_show_shop(shop_title)

# Missoes com objetivo "talk" (recado/entrega): falar com o NPC certo depois de cumprir o resto
func _deliver_quest_talk(npc: Npc) -> void:
	if quest_system == null or npc == null:
		return
	for quest_id in quest_system.register_talk(npc.npc_name):
		var quest: Dictionary = quest_system.quests.get(quest_id, {})
		var giver := str(quest.get("npc", "")).get_slice(",", 0)
		_flash("Recado entregue a %s! Volte para %s." % [npc.npc_name.get_slice(",", 0), giver])
		_spawn_floating_text(npc.global_position + Vector2(0, -90), "RECADO ENTREGUE", Color("#ffd36b"))

# ---- missoes por NPC (qualquer NPC pode dar missoes: campo "npc" do quests.json) ----
# "requires" no quests.json = missao anterior da cadeia (A Jornada).
func _npc_quest_ids(npc_name: String) -> Array:
	var ids: Array = []
	if quest_system == null:
		return ids
	for quest_id in quest_system.quests:
		if str(quest_system.quests[quest_id].get("npc", "")) == npc_name:
			ids.append(quest_id)
	return ids

func _quest_available(quest_id: String) -> bool:
	if quest_system.active.has(quest_id) or quest_system.completed.has(quest_id):
		return false
	var req := str(quest_system.quests.get(quest_id, {}).get("requires", ""))
	return req.is_empty() or quest_system.completed.has(req)

# "ready" (pode entregar), "available" (missao nova), "progress" (em andamento) ou ""
func _npc_quest_state(npc_name: String) -> String:
	var state := ""
	for quest_id in _npc_quest_ids(npc_name):
		if quest_system.active.has(quest_id) and quest_system.is_ready(quest_id):
			return "ready"
		if _quest_available(quest_id):
			state = "available"
		elif quest_system.active.has(quest_id) and state.is_empty():
			state = "progress"
	return state

var npc_quest_offer_toggle: Dictionary = {}

# mapa onde fica o NPC (maps.json ou os NPCs fixos de Eldoria)
func _npc_home_map(npc_name: String) -> String:
	for npc_id in ELDORIA_ACTIVE_NPCS:
		if str(ELDORIA_FUTURE_NPC_LOCATIONS.get(npc_id, {}).get("name", "")) == npc_name:
			return "city_eldoria"
	for map_id in maps:
		for npc in maps[map_id].get("npcs", []):
			if str(npc.get("name", "")) == npc_name:
				return str(map_id)
	return ""

# Entrega missao pronta ou oferece missao nova. NPC com outra funcao (loja, cura, porto...)
# alterna: uma conversa mostra a missao, a seguinte abre a funcao normal dele.
func _offer_npc_quests(npc: Npc) -> bool:
	var ids := _npc_quest_ids(npc.npc_name)
	if ids.is_empty():
		return false
	for quest_id in ids:
		if quest_system.active.has(quest_id) and quest_system.is_ready(quest_id):
			_handle_quest_npc(quest_id)
			return true
	var quest_only := npc.role == "quest" or npc.role == "talk"
	if not quest_only and bool(npc_quest_offer_toggle.get(npc.npc_name, false)):
		npc_quest_offer_toggle[npc.npc_name] = false  # mostrou missao na ultima conversa: agora a funcao normal
		return false
	for quest_id in ids:
		if _quest_available(quest_id):
			npc_quest_offer_toggle[npc.npc_name] = true
			_handle_quest_npc(quest_id)
			return true
	if quest_only:
		for quest_id in ids:
			if quest_system.active.has(quest_id):
				_handle_quest_npc(quest_id)
				return true
	return false

func _handle_quest_npc(quest_id: String) -> void:
	if selected_npc != null:
		_show_npc_bubble(selected_npc, _quest_intro_text(quest_id))
	if quest_system.completed.has(quest_id):
		_show_quest_dialog(quest_id, "Missao ja concluida. Obrigado pela ajuda, aventureiro.", false)
	elif quest_system.active.has(quest_id) and quest_system.is_ready(quest_id):
		var rewards := quest_system.complete(quest_id)
		AudioManager.play_sfx("missao_concluida")
		player.gain_xp(int(rewards.get("xp", 0)))
		player.ouro += int(rewards.get("ouro", 0))
		for item_name in rewards.get("items", []):
			player.inventory.add_item(str(item_name), 1)
		var done_text := str(quest_system.quests.get(quest_id, {}).get("done", "Voce voltou com tudo que eu precisava. Aqui esta sua recompensa."))
		if selected_npc != null:
			_show_npc_bubble(selected_npc, done_text)
		_show_quest_dialog(quest_id, done_text, false)
	elif quest_system.active.has(quest_id):
		_show_quest_dialog(quest_id, _quest_intro_text(quest_id), false)
	else:
		_show_quest_dialog(quest_id, _quest_intro_text(quest_id), true)

func _quest_intro_text(quest_id: String) -> String:
	var intro := str(quest_system.quests.get(quest_id, {}).get("intro", "")) if quest_system != null else ""
	if not intro.is_empty():
		return intro
	match quest_id:
		"furia_javalis":
			return "Preciso de couro e presas para preparar uma pocao de cura para minha esposa. Traga os materiais e eu lhe recompensarei."
		"cristal_quebrado":
			return "As ruinas estao liberando orbes arcanos instaveis. Derrote os espiritos, recolha fragmentos e salve Eldoria."
		"sombras_caverna":
			return "A caverna acordou. Morcegos e aranhas estao atacando viajantes. Limpe o caminho e traga asas como prova."
		"tutorial_forest":
			return "Primeiro conheca a floresta. Derrote monstros fracos, recolha moedas e volte mais forte."
		"tutorial_ruins":
			return "As ruinas mostram como inimigos magicos lutam. Explore com cuidado e complete seu treino."
		"tutorial_cave":
			return "A caverna ensina perigo real: veneno, mobs rapidos e alvos mais fortes. Va preparado."
	return "Tenho uma tarefa para voce. Aceite a missao e acompanhe os objetivos."

func _update_pet_combat(delta: float) -> void:
	if player == null or pet_allowed_target == null or not is_instance_valid(pet_allowed_target):
		return
	if player.in_safe_zone or _is_point_in_safe_zone(pet_allowed_target.global_position):
		return
	if pet_allowed_target.vida <= 0:
		pet_allowed_target = null
		return
	var pet_code := _current_equipped_pet_code()
	if pet_code.is_empty():
		return
	var pet_def := _definition_by_code(pet_definitions, pet_code)
	if pet_def.is_empty():
		return
	var distance := player.global_position.distance_to(pet_allowed_target.global_position)
	if distance > 330.0:
		return
	pet_attack_timer -= delta
	if pet_attack_timer > 0:
		return
	pet_attack_timer = max(0.65, float(pet_def.get("attack_interval", 1.6)))
	var pet_entry := _current_equipped_pet_entry()
	var pet_level := int(pet_entry.get("level", 1))
	var damage: int = max(1, int(round(float(pet_def.get("attack", 5)) + float(pet_level - 1) * 1.5 - float(pet_allowed_target.defesa) * 0.25)))
	var from := player.global_position + Vector2(-28, 18)
	if pet_follower != null and is_instance_valid(pet_follower):
		from = pet_follower.global_position
	var effects := PetCombatVisuals.options("pets", pet_code)
	if effects.is_empty():
		_spawn_pet_attack_line(from, pet_allowed_target.global_position)
	else:
		# efeito no meio do corpo do alvo e do tamanho dele (antes ficava pequeno e atras de alvos grandes)
		var hit_pos := pet_allowed_target.global_position + Vector2(0, -30)
		var hit_size := 140.0
		var target_sprite := pet_allowed_target.get("sprite") as Sprite2D
		if target_sprite != null and target_sprite.texture != null:
			var body_rect := target_sprite.get_rect()
			var body_scale := target_sprite.global_scale.abs()
			hit_pos = target_sprite.global_position + body_rect.get_center() * body_scale
			hit_size = clampf(maxf(body_rect.size.x * body_scale.x, body_rect.size.y * body_scale.y) * 0.85, 110.0, 240.0)
		PetCombatVisuals.play(world, str(effects[pet_special_visual_index % effects.size()]), hit_pos, pet_allowed_target.global_position.x > from.x, hit_size, true, pet_allowed_target.global_position.y)
		pet_special_visual_index += 1
	pet_attack_visual_timer = 0.42
	# o golpe pode matar o alvo e _enemy_killed zera pet_allowed_target: guarda antes
	var target := pet_allowed_target
	var target_pos := target.global_position
	target.receive_damage(damage)
	_spawn_floating_text(target_pos + Vector2(0, -48), "-%d pet" % damage, Color("#8eea77"))
	var debuff: Dictionary = pet_def.get("debuff", {})
	if not debuff.is_empty() and is_instance_valid(target) and pet_allowed_target == target:
		target.apply_pet_debuff(str(debuff.get("type", "")), float(debuff.get("amount", 0.0)), float(debuff.get("duration", 2.0)))
		_spawn_floating_text(target_pos + Vector2(0, -64), "debuff", Color("#b68cff"))

func _player_died() -> void:
	var killer: Dictionary = player.last_hit.duplicate()
	player.last_hit = {}
	if game_extras != null:
		game_extras.call_deferred("show_death", killer)
	player.revive_in_city()
	_load_home_city()
	_flash("Voce morreu, perdeu 5%% do ouro e voltou para %s." % ("Valdoria" if current_map == "city_valdoria" else "Eldoria"))
