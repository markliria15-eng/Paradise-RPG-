extends "res://scripts/main_partes/main_mundo.gd"

# Parte do main.gd (dividido em 2026-11-15 para ficar mais facil de manter).
# Combate: ataques, habilidades, efeitos, inimigos, drops e coleta.
# Cadeia: main_estado -> main_util -> main_mundo -> main_combate -> main_companheiros
#         -> main_interface -> scripts/main.gd (o no Main da cena usa main.gd).
# Cada parte so chama funcoes dela mesma ou das partes de baixo da cadeia.

func _prepare_skill_button_feedback(button: Button) -> void:
	if button == null:
		return
	var overlay := ColorRect.new()
	overlay.name = "CooldownOverlay"
	overlay.color = Color(0, 0, 0, 0.68)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	button.add_child(overlay)
	var label := Label.new()
	label.name = "CooldownLabel"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	button.add_child(label)

func _enemy_respawn_delay(enemy_name: String, spawn_data: Dictionary) -> float:
	var data: Dictionary = enemies_db.get(enemy_name, {})
	var is_boss := bool(data.get("boss", false)) or bool(spawn_data.get("boss", false))
	# Mobs comuns voltam mais devagar (multiplicador global); chefes mantem o tempo.
	var multiplier := 1.0 if is_boss else ENEMY_RESPAWN_MULTIPLIER
	if spawn_data.has("respawn"):
		return max(4.0, float(spawn_data.get("respawn", 10.0)) * multiplier)
	var level_value := int(data.get("level", 1))
	if is_boss:
		return 80.0 + float(level_value) * 5.0
	return clamp(6.0 + float(level_value) * 2.5, 8.0, 80.0) * multiplier

func _is_portal_blocked_by_boss(portal: Area2D) -> bool:
	if portal == null or not bool(portal.get_meta("requires_boss_clear", false)):
		return false
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var boss_name := str(portal.get_meta("boss_enemy", ""))
	if _is_boss_portal_permanently_open(current_map, boss_name):
		return false
	for node in tree.get_nodes_in_group("bosses"):
		if node is Enemy and is_instance_valid(node):
			var enemy := node as Enemy
			if enemy.vida > 0 and (boss_name.is_empty() or enemy.enemy_name == boss_name):
				return true
	return false

func _boss_portal_key(map_id: String, boss_name: String) -> String:
	return "%s:%s" % [map_id, boss_name]

func _cleared_boss_portals() -> Dictionary:
	var current: Variant = mmo_cache.get("cleared_boss_portals", {})
	if typeof(current) != TYPE_DICTIONARY:
		current = {}
		mmo_cache["cleared_boss_portals"] = current
	return current

func _is_boss_portal_permanently_open(map_id: String, boss_name: String) -> bool:
	return bool(_cleared_boss_portals().get(_boss_portal_key(map_id, boss_name), false))

func _open_boss_portal_permanently(map_id: String, boss_name: String) -> void:
	if boss_name.is_empty():
		return
	var cleared := _cleared_boss_portals()
	cleared[_boss_portal_key(map_id, boss_name)] = true
	mmo_cache["cleared_boss_portals"] = cleared

func _get_closest_enemy_in_range(radius: float) -> Enemy:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var best: Enemy = null
	var best_distance: float = INF
	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.vida <= 0:
			continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance <= radius and distance < best_distance:
			best = enemy
			best_distance = distance
	return best

func _update_current_target() -> void:
	if player == null:
		_set_current_target(null)
		return
	var target_radius := _auto_target_radius()
	_set_current_target(_get_closest_enemy_in_range(target_radius))

func _auto_target_radius() -> float:
	match player.class_name_selected:
		"Arqueiro":
			return 280.0
		"Mago":
			return 260.0
	return player.alcance

func _skill_data(skill_id: String) -> Dictionary:
	if player == null:
		return {}
	var skills: Array = player.class_data.get("skills", [])
	for entry in skills:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) == skill_id:
			return entry
	return {}

func _start_area_dot(center: Vector2, radius: float, skill_id: String, power: float, duration: float, tick_interval: float) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var elapsed := 0.0
	while elapsed < duration and player != null:
		if not is_inside_tree():
			return
		await tree.create_timer(tick_interval).timeout
		if player.in_safe_zone:
			return
		elapsed += tick_interval
		_spawn_area_effect(center, radius, skill_id)
		for node in tree.get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy == null or enemy.vida <= 0:
				continue
			if _is_point_in_safe_zone(enemy.global_position):
				continue
			if center.distance_to(enemy.global_position) > radius:
				continue
			var attack_value: float = player.get_attack_value()
			if skill_id == "arrow_rain":
				attack_value += player.ataque_distancia
			elif skill_id == "fire_hurricane":
				attack_value += player.ataque_magico
			var damage := CombatSystem.physical_damage(attack_value, enemy.defesa, power * player.damage_multiplier_for(skill_id), player.physical_damage_pct)
			enemy.receive_damage(damage)
			CombatJuice.on_enemy_hit(self, player_camera, enemy, center, enemy.vida <= 0, false, true)
			_spawn_floating_text(enemy.global_position + Vector2(0, -34), "-%d" % damage, Color("#ff7c3f") if skill_id == "fire_hurricane" else Color("#e8f0ff"))
			player.on_hit_enemy(skill_id)

func _set_current_target(enemy: Enemy) -> void:
	if current_target != null and is_instance_valid(current_target) and current_target != enemy:
		current_target.set_targeted(false)
	current_target = enemy
	if current_target != null and is_instance_valid(current_target):
		current_target.set_targeted(true)

func _spawn_basic_attack_effect(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	match player.class_name_selected:
		"Mago":
			_spawn_travel_projectile("basic_magic", enemy, "res://assets/sprites/effect_arcane_projectile.png", 0.20)
		"Arqueiro":
			_spawn_travel_projectile("basic_arrow", enemy, "res://assets/sprites/effect_arrow_projectile.png", 0.15)
		_:
			_spawn_travel_projectile("basic_slash", enemy, "res://assets/sprites/effect_slash_projectile.png", 0.13)

func _spawn_skill_projectile(skill_id: String, enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var travel_time := 0.24
	if skill_id in ["stun_shot", "arrow_rain"]:
		travel_time = 0.18
	elif skill_id in ["blue_meteor"]:
		travel_time = 0.32
	_spawn_travel_projectile(skill_id, enemy, _projectile_texture_for(skill_id), travel_time)

func _spawn_travel_projectile(skill_id: String, enemy: Enemy, texture_path: String, travel_time: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var start := player.global_position + Vector2(0, -22)
	var finish := enemy.global_position + Vector2(0, -12)
	var projectile := Sprite2D.new()
	projectile.texture = load(texture_path)
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.global_position = start
	projectile.rotation = (finish - start).angle()
	var projectile_scale := 0.92
	if skill_id in ["burning_fireball", "fire_hurricane", "blue_meteor", "basic_magic"]:
		projectile_scale = 1.08
	projectile.scale = Vector2(projectile_scale, projectile_scale)
	projectile.z_index = 90
	world.add_child(projectile)
	var glow := Sprite2D.new()
	glow.texture = projectile.texture
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.global_position = start
	glow.rotation = projectile.rotation
	glow.scale = projectile.scale * 1.55
	glow.modulate = _skill_color(skill_id).lerp(Color.WHITE, 0.18)
	glow.modulate.a = 0.34
	glow.z_index = 88
	world.add_child(glow)
	var trail := Line2D.new()
	trail.width = 7.0 if skill_id in ["burning_fireball", "fire_hurricane", "blue_meteor"] else 5.0
	trail.default_color = _skill_color(skill_id)
	trail.z_index = 89
	world.add_child(trail)
	var tween := create_tween()
	tween.tween_method(func(value) -> void:
		if is_instance_valid(projectile):
			projectile.global_position = value
		if is_instance_valid(glow):
			glow.global_position = value
			glow.rotation += 0.18
		if is_instance_valid(trail):
			trail.add_point(value)
			while trail.get_point_count() > 10:
				trail.remove_point(0)
	, start, finish, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(projectile, "scale", Vector2(projectile_scale + 0.25, projectile_scale + 0.25), travel_time)
	tween.parallel().tween_property(glow, "modulate", Color(glow.modulate.r, glow.modulate.g, glow.modulate.b, 0.08), travel_time)
	tween.tween_callback(func() -> void:
		_spawn_impact_effect(finish, skill_id)
		if is_instance_valid(projectile):
			projectile.queue_free()
		if is_instance_valid(glow):
			glow.queue_free()
		if is_instance_valid(trail):
			trail.queue_free()
	)

func _projectile_texture_for(skill_id: String) -> String:
	if skill_id in ["blue_meteor"]:
		return "res://assets/sprites/effect_blue_meteor_projectile.png"
	if skill_id in ["fireball", "burning_fireball", "fire_hurricane"]:
		return "res://assets/sprites/effect_fireball_projectile.png"
	if skill_id in ["arcane_blast", "mystic_shield"]:
		return "res://assets/sprites/effect_arcane_projectile.png"
	if skill_id in ["arrow_rain", "precise_shot", "stun_shot", "quick_jump", "agility"]:
		return "res://assets/sprites/effect_arrow_projectile.png"
	return "res://assets/sprites/effect_slash_projectile.png"

func _spawn_impact_effect(pos: Vector2, skill_id: String) -> void:
	var icon_path := _impact_texture_for(skill_id)
	var hit := Sprite2D.new()
	hit.texture = load(icon_path)
	hit.global_position = pos
	hit.scale = Vector2(0.42, 0.42)
	hit.modulate = Color(1, 1, 1, 0.82)
	hit.z_index = 81
	world.add_child(hit)
	var tween := create_tween()
	tween.tween_property(hit, "scale", Vector2(1.15, 1.15), 0.28)
	tween.parallel().tween_property(hit, "modulate", Color(1, 1, 1, 0), 0.28)
	if skill_id in ["burning_fireball", "fire_hurricane", "blue_meteor", "stun_shot", "soul_reaper"]:
		var ring := Line2D.new()
		ring.width = 5.0
		ring.closed = true
		ring.default_color = _skill_color(skill_id)
		ring.z_index = 80
		for i in range(36):
			var angle := TAU * float(i) / 36.0
			ring.add_point(Vector2(cos(angle), sin(angle)) * 28.0)
		ring.global_position = pos
		ring.scale = Vector2(0.25, 0.25)
		world.add_child(ring)
		var ring_tween := create_tween()
		ring_tween.tween_property(ring, "scale", Vector2(1.25, 1.25), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ring_tween.parallel().tween_property(ring, "modulate", Color(1, 1, 1, 0), 0.30)
		ring_tween.tween_callback(func() -> void:
			if is_instance_valid(ring):
				ring.queue_free()
		)
	tween.tween_callback(func() -> void:
		if is_instance_valid(hit):
			hit.queue_free()
	)

func _impact_texture_for(skill_id: String) -> String:
	if skill_id in ["fireball", "burning_fireball", "fire_hurricane"]:
		return "res://assets/sprites/effect_impact_fire.png"
	if skill_id in ["arcane_blast", "mystic_shield", "blue_meteor", "basic_magic"]:
		return "res://assets/sprites/effect_impact_blue.png"
	if skill_id in ["arrow_rain", "precise_shot", "stun_shot", "quick_jump", "agility", "basic_arrow"]:
		return "res://assets/sprites/effect_impact_arrow.png"
	return "res://assets/sprites/effect_impact_slash.png"

func _spawn_area_effect(center: Vector2, radius: float, skill_id: String) -> void:
	var line := Line2D.new()
	line.width = 5.0
	line.closed = true
	line.default_color = _skill_color(skill_id)
	line.z_index = 79
	for i in range(40):
		var angle := TAU * float(i) / 40.0
		line.add_point(Vector2(cos(angle), sin(angle)) * radius)
	line.global_position = center
	line.scale = Vector2(0.18, 0.18)
	world.add_child(line)
	var pulse := Sprite2D.new()
	pulse.texture = load(_impact_texture_for(skill_id))
	pulse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pulse.global_position = center
	pulse.scale = Vector2(0.46, 0.46)
	pulse.modulate = Color(1, 1, 1, 0.70)
	pulse.z_index = 78
	world.add_child(pulse)
	var tween := create_tween()
	tween.tween_property(line, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(line, "modulate", Color(1, 1, 1, 0), 0.36)
	tween.parallel().tween_property(pulse, "scale", Vector2(maxf(0.85, radius / 70.0), maxf(0.85, radius / 70.0)), 0.36)
	tween.parallel().tween_property(pulse, "modulate", Color(1, 1, 1, 0), 0.36)
	tween.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
		if is_instance_valid(pulse):
			pulse.queue_free()
	)

func _spawn_self_effect(skill_id: String) -> void:
	var icon_path := str(SKILL_ICON_BY_ID.get(skill_id, ""))
	if icon_path.is_empty():
		return
	var effect := Sprite2D.new()
	effect.texture = load(icon_path)
	effect.global_position = player.global_position + Vector2(0, -34)
	effect.scale = Vector2(0.55, 0.55)
	effect.z_index = 90
	world.add_child(effect)
	var tween := create_tween()
	tween.tween_property(effect, "global_position", effect.global_position + Vector2(0, -28), 0.48)
	tween.parallel().tween_property(effect, "modulate", Color(1, 1, 1, 0), 0.48)
	tween.tween_callback(func() -> void:
		if is_instance_valid(effect):
			effect.queue_free()
	)
	if skill_id == "mystic_shield":
		_spawn_area_effect(player.global_position, 52, skill_id)
	elif skill_id in ["hero_hour", "war_cry", "agility"]:
		_spawn_area_effect(player.global_position, 54, skill_id)

func _spawn_dash_effect(from: Vector2, to: Vector2, skill_id: String) -> void:
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = _skill_color(skill_id)
	line.z_index = 75
	line.add_point(from)
	line.add_point(to)
	world.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate", Color(1, 1, 1, 0), 0.28)
	tween.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)

func _spawn_map_collectibles(map_data: Dictionary) -> void:
	for entry in map_data.get("collectibles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_name := str(entry.get("item", ""))
		var pos_data: Array = entry.get("pos", [])
		if item_name.is_empty() or pos_data.size() < 2:
			continue
		var amount: int = max(1, int(entry.get("amount", 1)))
		var pos: Vector2 = _resolve_unblocked_spawn(_map_data_point(pos_data), current_map == "forest_boars" or current_map == "bat_cave")
		var collectible: ItemDrop = DROP_SCENE.instantiate()
		var local_collectible: ItemDrop = collectible
		world.add_child(collectible)
		collectible.setup(item_name, amount)
		collectible.set_meta("manual_collect", true)
		collectible.global_position = pos
		collectible.body_entered.connect(func(body: Node) -> void:
			if body == player:
				_flash("OK: colher " + local_collectible.item_name)
		)

func _update_minimap() -> void:
	if minimap_canvas == null or player == null:
		return
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	for child in minimap_canvas.get_children():
		child.queue_free()
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = minimap_canvas.size
	bg.color = _minimap_base_color()
	bg.z_index = 0
	minimap_canvas.add_child(bg)
	if _use_eldoria_image_minimap():
		_add_eldoria_minimap_background()
	elif _use_valdoria_image_minimap():
		_add_valdoria_minimap_background()
	elif _use_forest_image_minimap():
		_add_forest_minimap_background()
	elif _use_cave_image_minimap():
		_add_cave_minimap_background()
	else:
		_add_minimap_terrain()
		_add_minimap_obstacles()
	for enemy in _minimap_enemy_nodes():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not _is_world_pos_in_minimap(enemy.global_position):
			continue
		_add_minimap_dot(_minimap_pos(enemy.global_position), Color("#ff4a4a"), 3.0)
	for npc in tree.get_nodes_in_group("npcs"):
		if npc == null or not is_instance_valid(npc):
			continue
		if not _is_world_pos_in_minimap(npc.global_position):
			continue
		_add_minimap_dot(_minimap_pos(npc.global_position), Color("#4dff8d"), 3.0)
	for portal in tree.get_nodes_in_group("portals"):
		if portal == null or not is_instance_valid(portal):
			continue
		if not _is_world_pos_in_minimap(portal.global_position):
			continue
		_add_minimap_dot(_minimap_pos(portal.global_position), Color("#b970ff"), 3.5)
	_add_minimap_player_marker()

func _minimap_enemy_nodes() -> Array:
	if not is_inside_tree():
		return []
	var tree := get_tree()
	if tree == null:
		return []
	var nodes: Array = tree.get_nodes_in_group("enemies")
	if world == null:
		return nodes
	for child in world.get_children():
		if child is Enemy and not nodes.has(child):
			nodes.append(child)
	return nodes

func _update_skill_button_cooldowns() -> void:
	if player == null:
		return
	var skills: Array = player.class_data.get("skills", [])
	for i in range(skill_buttons.size()):
		var button := skill_buttons[i]
		if button == null:
			continue
		var overlay := button.get_node_or_null("CooldownOverlay") as ColorRect
		var label := button.get_node_or_null("CooldownLabel") as Label
		if i >= skills.size():
			if overlay != null:
				overlay.visible = true
			if label != null:
				label.visible = false
			button.modulate = Color(0.5, 0.5, 0.55, 1.0)
			continue
		var skill: Dictionary = skills[i]
		var cooldown_left := SkillSystem.cooldown_left(skill)
		var mana_cost := int(skill.get("mana_cost", skill.get("mana", 0)))
		var lacks_mana := player.mana < mana_cost
		var ready := cooldown_left <= 0.05 and not lacks_mana
		if overlay != null:
			overlay.visible = not ready
			overlay.color = Color(0, 0, 0, 0.72 if cooldown_left > 0.05 else 0.48)
		if label != null:
			label.visible = not ready
			label.text = "%0.1f" % cooldown_left if cooldown_left > 0.05 else "MP"
		button.modulate = Color(1, 1, 1, 1) if ready else Color(0.45, 0.45, 0.50, 1)
