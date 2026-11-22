extends "res://scripts/main_partes/main_combate.gd"

# Parte do main.gd (dividido em 2026-11-15 para ficar mais facil de manter).
# Companheiros: pets (passeio, personalidade, afinidade, pedidos) e montarias (heroi montado, bonus).
# Cadeia: main_estado -> main_util -> main_mundo -> main_combate -> main_companheiros
#         -> main_interface -> scripts/main.gd (o no Main da cena usa main.gd).
# Cada parte so chama funcoes dela mesma ou das partes de baixo da cadeia.

func _ensure_local_companion_state() -> void:
	if online_mode:
		return
	if not mmo_cache.has("pets_state") or typeof(mmo_cache.get("pets_state")) != TYPE_DICTIONARY:
		mmo_cache["pets_state"] = {"pets": []}
	if not mmo_cache.has("mounts_state") or typeof(mmo_cache.get("mounts_state")) != TYPE_DICTIONARY:
		mmo_cache["mounts_state"] = {"mounts": []}

func _buy_local_pet(code: String) -> bool:
	_ensure_local_companion_state()
	if not _owned_entry("pets_state", "pets", code).is_empty():
		_equip_local_pet(code)
		return true
	var def := _definition_by_code(pet_definitions, code)
	if def.is_empty():
		return false
	var price := int(def.get("price", 0))
	if player.ouro < price:
		return false
	player.ouro -= price
	var payload: Dictionary = mmo_cache["pets_state"]
	var owned: Array = payload.get("pets", [])
	owned.append({"id": owned.size() + 1, "code": code, "level": 1, "xp": 0, "equipped": owned.is_empty()})
	payload["pets"] = owned
	mmo_cache["pets_state"] = payload
	_apply_companion_bonuses()
	return true

func _equip_local_pet(code: String) -> void:
	_ensure_local_companion_state()
	var payload: Dictionary = mmo_cache["pets_state"]
	var owned: Array = payload.get("pets", [])
	for i in range(owned.size()):
		if typeof(owned[i]) == TYPE_DICTIONARY:
			owned[i]["equipped"] = str(owned[i].get("code", "")) == code
	payload["pets"] = owned
	mmo_cache["pets_state"] = payload
	pet_attack_timer = 0.0
	_apply_companion_bonuses()

func _buy_local_mount(code: String) -> bool:
	_ensure_local_companion_state()
	if not _owned_entry("mounts_state", "mounts", code).is_empty():
		_equip_local_mount(code)
		return true
	var def := _definition_by_code(mount_definitions, code)
	if def.is_empty():
		return false
	var price := int(def.get("price", 0))
	if player.ouro < price:
		return false
	player.ouro -= price
	var payload: Dictionary = mmo_cache["mounts_state"]
	var owned: Array = payload.get("mounts", [])
	owned.append({"id": owned.size() + 1, "code": code, "equipped": owned.is_empty()})
	payload["mounts"] = owned
	mmo_cache["mounts_state"] = payload
	_apply_companion_bonuses()
	return true

func _equip_local_mount(code: String) -> void:
	_ensure_local_companion_state()
	var payload: Dictionary = mmo_cache["mounts_state"]
	var owned: Array = payload.get("mounts", [])
	for i in range(owned.size()):
		if typeof(owned[i]) == TYPE_DICTIONARY:
			owned[i]["equipped"] = str(owned[i].get("code", "")) == code
	payload["mounts"] = owned
	mmo_cache["mounts_state"] = payload
	_apply_companion_bonuses()

func _dismount_current_mount(reason: String = "") -> void:
	var code := _current_equipped_mount_code()
	if code.is_empty():
		return
	mount_last_code = code
	var payload: Dictionary = mmo_cache.get("mounts_state", {})
	var owned: Array = payload.get("mounts", [])
	for i in range(owned.size()):
		if typeof(owned[i]) == TYPE_DICTIONARY:
			owned[i]["equipped"] = false
	payload["mounts"] = owned
	mmo_cache["mounts_state"] = payload
	_apply_companion_bonuses()
	if not reason.is_empty():
		_flash(reason)

func _pet_emote(kind: String, force: bool = false) -> void:
	if pet_follower == null or not is_instance_valid(pet_follower):
		return
	if not force and _now_s() < pet_emote_ready_at:
		return
	var tex := load("res://assets/sprites/pets/emotes/%s.png" % kind) as Texture2D
	if tex == null:
		return
	pet_emote_ready_at = _now_s() + PET_EMOTE_GAP
	var bubble := Sprite2D.new()
	bubble.texture = tex
	bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# acima da cabeca do pet; filho dele para acompanhar enquanto anda
	pet_follower.add_child(bubble)
	var s := 1.0 / maxf(0.01, pet_follower.scale.x)
	bubble.z_index = 50
	bubble.position = pet_follower.offset + Vector2(18.0 * s, -pet_follower.texture.get_height() * 0.36)
	bubble.scale = Vector2.ZERO
	var tween := bubble.create_tween()
	tween.tween_property(bubble, "scale", Vector2(s, s) * 1.15, 0.14)
	tween.tween_property(bubble, "scale", Vector2(s, s), 0.08)
	tween.tween_interval(1.1)
	tween.parallel().tween_property(bubble, "position:y", bubble.position.y - 10.0 * s, 1.1)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tween.tween_callback(bubble.queue_free)

# reacoes do pet ao que acontece com o heroi
func _update_pet_mood(delta: float) -> void:
	var code := _current_equipped_pet_code()
	if code.is_empty():
		pet_last_code_seen = ""
		return
	if code != pet_last_code_seen:
		pet_last_code_seen = code
		_pet_emote("coracao", true)  # pet novo/trocado
	if pet_last_level < 0:
		pet_last_level = player.level
	elif player.level > pet_last_level:
		pet_last_level = player.level
		_pet_emote("nota", true)
	if player.vida > 0 and float(player.vida) < float(player.vida_max) * 0.3:
		if _now_s() >= pet_low_hp_next:
			pet_low_hp_next = _now_s() + 5.0
			_pet_emote("preocupado", true)
	pet_idle_time = pet_idle_time + delta if player.velocity.length() < 4.0 else 0.0
	if pet_idle_time > 12.0:
		pet_idle_time = 4.0  # repete a cada ~8 s enquanto o heroi fica parado
		_pet_emote("sono")

func _pet_affinity_store() -> Dictionary:
	if not mmo_cache.has("pet_affinity") or typeof(mmo_cache["pet_affinity"]) != TYPE_DICTIONARY:
		mmo_cache["pet_affinity"] = {}
	return mmo_cache["pet_affinity"]

func _pet_affinity(code: String = "") -> float:
	if code.is_empty():
		code = _current_equipped_pet_code()
	var entry = _pet_affinity_store().get(code, {})
	var start := float(_rule(["afinidade", "inicial"], 50.0))
	return float(entry.get("value", start)) if typeof(entry) == TYPE_DICTIONARY else start

func _pet_affinity_tier(value: float) -> float:
	var bands: Variant = _rule(["afinidade", "faixas"], null)
	if typeof(bands) == TYPE_ARRAY and not (bands as Array).is_empty():
		var best := 0.0
		for band in bands:
			if typeof(band) == TYPE_DICTIONARY and value >= float(band.get("min", 0.0)):
				best = maxf(best, float(band.get("bonus", 0.0)))
		return best
	if value >= 100.0:
		return 0.10
	if value >= 80.0:
		return 0.06
	if value >= 50.0:
		return 0.03
	return 0.0

# pets de ataque ganham dano; os outros (tartaruga, espirito, fada...) ganham defesa
func _pet_affinity_kind(code: String) -> String:
	var def := _definition_by_code(pet_definitions, code)
	var bonus: Dictionary = def.get("base_bonus", {})
	for key in ["physical_attack_pct", "magic_damage_pct", "attack_speed_pct"]:
		if float(bonus.get(key, 0.0)) > 0.0:
			return "dano"
	return "defesa"

func _change_pet_affinity(delta_value: float, reason: String = "") -> void:
	var code := _current_equipped_pet_code()
	if code.is_empty():
		return
	var store := _pet_affinity_store()
	var before := _pet_affinity(code)
	var after := clampf(before + delta_value, 0.0, 100.0)
	store[code] = {"value": after, "last_seen": Time.get_unix_time_from_system()}
	if _pet_affinity_tier(after) != _pet_affinity_tier(before):
		_apply_companion_bonuses()
		var tier := int(round(_pet_affinity_tier(after) * 100.0))
		if after > before:
			_flash("Afinidade %d%%! Seu pet agora te da +%d%% de %s." % [int(after), tier, _pet_affinity_kind(code)])
			_pet_emote("coracao", true)
		else:
			_flash_red("A afinidade com seu pet caiu para %d%%." % int(after))
	elif not reason.is_empty():
		_flash("%s (afinidade %d%%)" % [reason, int(after)])

# ao abrir o jogo: tira afinidade pelos dias sem jogar
func _apply_pet_affinity_absence() -> void:
	var now := Time.get_unix_time_from_system()
	var store := _pet_affinity_store()
	for code in store.keys():
		var entry = store[code]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var last := float(entry.get("last_seen", now))
		var days := (now - last) / 86400.0
		if days >= 1.0:
			entry["value"] = clampf(float(entry.get("value", 50.0)) - floorf(days) * float(_rule(["afinidade", "perda_por_dia_sem_jogar"], PET_AFFINITY_DECAY_PER_DAY)), 0.0, 100.0)
		entry["last_seen"] = now
		store[code] = entry

func _show_pet_need_bubble() -> void:
	if pet_need_bubble != null and is_instance_valid(pet_need_bubble):
		pet_need_bubble.queue_free()
	pet_need_bubble = null
	if pet_need.is_empty() or pet_follower == null or not is_instance_valid(pet_follower):
		return
	var tex := load("res://assets/sprites/pets/emotes/%s.png" % pet_need) as Texture2D
	if tex == null:
		return
	pet_need_bubble = Sprite2D.new()
	pet_need_bubble.texture = tex
	pet_need_bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pet_need_bubble.z_index = 50
	pet_follower.add_child(pet_need_bubble)

func _finish_pet_need(satisfied: bool) -> void:
	var need := pet_need
	pet_need = ""
	_show_pet_need_bubble()
	pet_next_need_at = _now_s() + _rule_range(["pedidos", "intervalo_s"], 50.0, 100.0)
	if satisfied:
		_change_pet_affinity(float(_rule(["afinidade", "ganho_pedido"], 8.0)), "Seu pet ficou feliz!")
		if game_extras != null:
			game_extras.daily_progress("pet_need")
		_pet_emote("coracao" if need != "bola" else "nota", true)
	else:
		_change_pet_affinity(-float(_rule(["afinidade", "perda_pedido_ignorado"], 5.0)), "Seu pet ficou triste: ninguem atendeu o pedido.")
		_pet_emote("preocupado", true)

# Tocar no pet, no botao do pet ou apertar E perto dele: atende o pedido ou faz carinho
func _interact_with_pet() -> bool:
	var code := _current_equipped_pet_code()
	if code.is_empty() or pet_follower == null or not is_instance_valid(pet_follower):
		return false
	var pet_name := str(_definition_by_code(pet_definitions, code).get("name", "Seu pet"))
	match pet_need:
		"maca":
			if not player.inventory.remove_item(PET_FOOD, 1):
				_flash_red("%s esta com fome. Consiga %s nos javalis da floresta." % [pet_name, PET_FOOD])
				return true
			_finish_pet_need(true)
		"bola":
			pet_play_until = _now_s() + 1.6
			_finish_pet_need(true)
		"carinho":
			_finish_pet_need(true)
		"espadas":
			_flash("%s quer lutar: derrote um monstro com ele por perto." % pet_name)
		_:
			if _now_s() >= pet_pet_cooldown_until:
				pet_pet_cooldown_until = _now_s() + float(_rule(["afinidade", "carinho_cooldown_s"], 30.0))
				_change_pet_affinity(float(_rule(["afinidade", "carinho_ganho"], 1.0)), "Voce fez carinho no %s." % pet_name)
			_pet_emote("coracao", true)
	return true

func _pick_pet_need() -> String:
	var weights: Variant = _rule(["pedidos", "pesos"], {})
	var total := 0.0
	for need in PET_NEEDS:
		total += float((weights as Dictionary).get(need, 1.0)) if typeof(weights) == TYPE_DICTIONARY else 1.0
	var roll := randf() * total
	for need in PET_NEEDS:
		roll -= float((weights as Dictionary).get(need, 1.0)) if typeof(weights) == TYPE_DICTIONARY else 1.0
		if roll <= 0.0:
			return need
	return PET_NEEDS[0]

func _update_pet_affinity(delta: float) -> void:
	var code := _current_equipped_pet_code()
	if code.is_empty():
		if not pet_need.is_empty():
			pet_need = ""
			_show_pet_need_bubble()
		return
	if not pet_affinity_checked:
		pet_affinity_checked = true
		_apply_pet_affinity_absence()
		pet_next_need_at = _now_s() + _rule_range(["pedidos", "primeiro_apos_s"], 25.0, 50.0)
		_apply_companion_bonuses()
	# jogar junto: +1 a cada 3 minutos
	pet_together_time += delta
	if pet_together_time >= float(_rule(["afinidade", "jogar_junto_intervalo_s"], 180.0)):
		pet_together_time = 0.0
		_change_pet_affinity(float(_rule(["afinidade", "jogar_junto_ganho"], 1.0)))
	if pet_need.is_empty():
		if _now_s() >= pet_next_need_at:
			pet_need = _pick_pet_need()
			pet_need_until = _now_s() + float(_rule(["pedidos", "tempo_para_atender_s"], PET_NEED_TIMEOUT))
			_show_pet_need_bubble()
			var pet_name := str(_definition_by_code(pet_definitions, code).get("name", "Seu pet"))
			_flash("%s %s. Toque no pet ou no botao dele." % [pet_name, str(PET_NEED_TEXT.get(pet_need, ""))])
	elif _now_s() >= pet_need_until:
		_finish_pet_need(false)
	if pet_need_bubble != null and is_instance_valid(pet_need_bubble) and pet_follower != null and is_instance_valid(pet_follower):
		var s := 1.0 / maxf(0.01, pet_follower.scale.x)
		pet_need_bubble.scale = Vector2(s, s)
		pet_need_bubble.position = pet_follower.offset + Vector2(-16.0 * s, -pet_follower.texture.get_height() * 0.36 + sin(companion_anim_time * 4.0) * 3.0 * s)
	# brincando: o pet da pulinhos
	if pet_follower != null and is_instance_valid(pet_follower) and _now_s() < pet_play_until:
		pet_follower.global_position.y -= absf(sin((pet_play_until - _now_s()) * 9.0)) * 22.0
	_update_pet_button()

func _update_pet_button() -> void:
	if pet_button == null or not is_instance_valid(pet_button):
		return
	var code := _current_equipped_pet_code()
	pet_button.visible = not code.is_empty()
	if code.is_empty():
		return
	if pet_button.get_meta("icon_code", "") != code:
		pet_button.set_meta("icon_code", code)
		pet_button.icon = load(_pet_icon_path(code))
	if pet_button_label != null:
		pet_button_label.text = "%d%%" % int(_pet_affinity(code))
	pet_button.modulate = Color(1.0, 0.85, 0.5) if not pet_need.is_empty() else Color.WHITE
	pet_button.tooltip_text = "Pet: atender pedido / carinho [E perto dele]"

func _mount_perk(code: String) -> Dictionary:
	var from_rules: Variant = _rule(["montaria", "vantagens", code], null)
	if typeof(from_rules) == TYPE_DICTIONARY:
		return from_rules
	return MOUNT_PERKS.get(code, {})

# Atacou, usou habilidade ou apanhou: desce da montaria e so pode montar de novo depois de um tempo
func _enter_combat_dismount(reason: String) -> void:
	var code := _current_equipped_mount_code()
	if code.is_empty():
		code = mount_last_code
	mount_combat_until = _now_s() + float(_mount_perk(code).get("remount", _rule(["montaria", "espera_remontar_s"], MOUNT_REMOUNT_DELAY)))
	_dismount_current_mount(reason)

func _owned_mount_codes() -> Array:
	var codes: Array = []
	var payload: Dictionary = mmo_cache.get("mounts_state", {})
	for entry in payload.get("mounts", []):
		if typeof(entry) == TYPE_DICTIONARY and not str(entry.get("code", "")).is_empty():
			codes.append(str(entry.get("code", "")))
	return codes

# Botao rapido (tecla R): montado desce; a pe monta na ultima montaria usada
func _toggle_mount() -> void:
	if player == null:
		return
	_ensure_local_companion_state()
	if not _current_equipped_mount_code().is_empty():
		_dismount_current_mount("Voce desceu da montaria.")
		return
	var owned := _owned_mount_codes()
	if owned.is_empty():
		_flash("Voce ainda nao tem montaria. Compre uma no Mercado de Montarias.")
		return
	var wait := mount_combat_until - _now_s()
	if wait > 0.0:
		_flash_red("Em luta: da para montar em %.1f s" % wait)
		return
	var code := mount_last_code if owned.has(mount_last_code) else str(owned[0])
	_equip_local_mount(code)
	var def := _definition_by_code(mount_definitions, code)
	_flash("Montou: %s" % str(def.get("name", code)))
	_pet_emote("nota")

func _update_mount_button() -> void:
	if mount_button == null or not is_instance_valid(mount_button):
		return
	var owned := _owned_mount_codes()
	var current := _current_equipped_mount_code()
	var code := current if not current.is_empty() else (mount_last_code if owned.has(mount_last_code) else (str(owned[0]) if not owned.is_empty() else ""))
	mount_button.visible = not code.is_empty()
	if code.is_empty():
		return
	if mount_button.get_meta("icon_code", "") != code:
		mount_button.set_meta("icon_code", code)
		mount_button.icon = load(_mount_icon_path(code))
	var wait := mount_combat_until - _now_s()
	var locked := current.is_empty() and wait > 0.0
	mount_button.modulate = Color(1, 1, 1, 0.45) if locked else (Color(1, 1, 1, 1) if current.is_empty() else Color(1.0, 0.9, 0.55, 1))
	var label := mount_button.get_node_or_null("CooldownLabel") as Label
	if label != null:
		label.visible = locked
		label.text = "%.0f" % ceilf(wait)
	mount_button.tooltip_text = "Descer da montaria [R]" if not current.is_empty() else "Montar [R]"

# Couraca (javali/pantera) segura um golpe; regeneracao do cervo
func _mount_absorbs_hit() -> bool:
	var code := _current_equipped_mount_code()
	if code.is_empty() or not bool(_mount_perk(code).get("armor", false)):
		return false
	if _now_s() < mount_armor_ready_at:
		return false
	mount_armor_ready_at = _now_s() + float(_rule(["montaria", "golpe_recarga_s"], MOUNT_ARMOR_RECHARGE))
	return true

func _update_mount_perks(delta: float) -> void:
	var code := _current_equipped_mount_code()
	var regen := float(_mount_perk(code).get("regen", 0.0))
	if code.is_empty() or regen <= 0.0 or _now_s() < mount_combat_until or player.vida >= player.vida_max:
		mount_regen_acc = 0.0
		return
	mount_regen_acc += float(player.vida_max) * regen * delta
	if mount_regen_acc >= 1.0:
		var amount := int(mount_regen_acc)
		mount_regen_acc -= amount
		player.vida = mini(player.vida_max, player.vida + amount)
		if player.has_method("_update_health_bar"):
			player._update_health_bar()
		player.stats_changed.emit()

func _apply_companion_bonuses() -> void:
	if player == null:
		return
	player.companion_physical_damage_pct = 0.0
	player.companion_mana_regen_pct = 0.0
	player.companion_attack_speed_pct = 0.0
	player.companion_move_speed_pct = 0.0
	player.companion_vida_max_pct = 0.0
	var pet_def := _definition_by_code(pet_definitions, _current_equipped_pet_code())
	var pet_bonus: Dictionary = pet_def.get("base_bonus", {})
	player.companion_physical_damage_pct += float(pet_bonus.get("physical_attack_pct", 0.0))
	player.companion_physical_damage_pct += float(pet_bonus.get("magic_damage_pct", 0.0))
	player.companion_mana_regen_pct += float(pet_bonus.get("mana_regen_pct", 0.0))
	player.companion_attack_speed_pct += float(pet_bonus.get("attack_speed_pct", 0.0))
	player.companion_vida_max_pct += float(pet_bonus.get("max_hp_pct", 0.0))
	player.companion_move_speed_pct += float(pet_bonus.get("move_speed_pct", 0.0))
	var mount_def := _definition_by_code(mount_definitions, _current_equipped_mount_code())
	player.companion_move_speed_pct += float(mount_def.get("speed_bonus", 0.0))
	if not mount_def.is_empty() and game_extras != null:
		player.companion_move_speed_pct += game_extras.mount_care_bonus()  # estabulo
	# afinidade: 50% = +3%, 80% = +6%, 100% = +10% de dano (pets de ataque) ou de defesa
	player.companion_defense_pct = 0.0
	var pet_code := _current_equipped_pet_code()
	if not pet_code.is_empty():
		var tier := _pet_affinity_tier(_pet_affinity(pet_code))
		if _pet_affinity_kind(pet_code) == "dano":
			player.companion_physical_damage_pct += tier
		else:
			player.companion_defense_pct += tier
	if profissoes != null:
		profissoes.aplicar_bonus(player)  # comida com bonus (dano/defesa/vida)
	player.recalculate_equipment()

func _update_kit_vehicles(delta: float) -> void:
	for state in kit_vehicles:
		var sprite := state.get("node") as AnimatedSprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		var route: Array = state["route"]
		if float(state["wait"]) > 0.0:
			state["wait"] = float(state["wait"]) - delta
			var idle_name := "idle_%s" % str(state["facing"])
			if sprite.sprite_frames.has_animation(idle_name):
				_set_kit_vehicle_anim(state, idle_name)
			else:
				sprite.pause()
				state["anim"] = ""
			continue
		var next_index := (int(state["index"]) + 1) % route.size()
		var target_data: Array = route[next_index]
		var target := Vector2(float(target_data[0]), float(target_data[1]))
		var to_target := target - sprite.position
		var step := float(state["speed"]) * delta
		var direction := ""
		if abs(to_target.x) >= abs(to_target.y):
			direction = "left" if to_target.x < 0.0 else "right"
			state["facing"] = direction
		else:
			direction = "up" if to_target.y < 0.0 else "down"
		var move_name := "move_%s" % direction
		if not sprite.sprite_frames.has_animation(move_name):
			move_name = "move_%s" % str(state["facing"])
		_set_kit_vehicle_anim(state, move_name)
		if not sprite.is_playing():
			sprite.play()
		var next_pos := target if to_target.length() <= step else sprite.position + to_target.normalized() * step
		if not bool(state["flying"]) and player != null:
			var hero_rect := _hero_footprint(player.global_position)
			var next_rect := _kit_vehicle_rect(state, next_pos)
			if next_rect.intersects(hero_rect) and next_rect.get_center().distance_to(hero_rect.get_center()) < _kit_vehicle_rect(state, sprite.position).get_center().distance_to(hero_rect.get_center()):
				# o heroi (ou a montaria) esta no caminho: espera parado ate ele sair
				var wait_name := "idle_%s" % str(state["facing"])
				if sprite.sprite_frames.has_animation(wait_name):
					_set_kit_vehicle_anim(state, wait_name)
				else:
					sprite.pause()
					state["anim"] = ""
				continue
		if to_target.length() <= step:
			sprite.position = target
			state["index"] = next_index
			state["wait"] = float(target_data[2]) if target_data.size() > 2 else 0.0
		else:
			sprite.position += to_target.normalized() * step
		sprite.z_index = 1100 if bool(state["flying"]) else clampi(int(sprite.position.y), -1024, 1024)

func _enforce_world_collision() -> void:
	if player == null:
		return
	if last_valid_player_position == Vector2.ZERO:
		last_valid_player_position = player.global_position
	var old := last_valid_player_position
	var new_pos := player.global_position
	if new_pos == old:
		return
	hero_bump_actor = {}
	if not _hero_move_blocked(old, new_pos):
		last_valid_player_position = new_pos
		return
	if not hero_bump_actor.is_empty() and game_extras != null:
		game_extras.on_bump(hero_bump_actor, _hero_mounted_visual())
	# esbarrou: tenta deslizar so na horizontal ou so na vertical
	for slide in [Vector2(new_pos.x, old.y), Vector2(old.x, new_pos.y)]:
		if slide != old and not _hero_move_blocked(old, slide):
			player.global_position = slide
			last_valid_player_position = slide
			return
	player.global_position = old

# Regras de mundo do heroi: o ponto dele (mascara/solidos como antes) e, montado, a pegada da
# montaria inteira; e nao atravessa NPCs nem pedestres/carrocas. Se ja estava preso (montou
# encostado numa parede, um pedestre chegou nele), deixa sair.
func _hero_move_blocked(old: Vector2, new_pos: Vector2) -> bool:
	if _is_point_blocked(new_pos):
		return true
	if _hero_mounted_visual() and _footprint_blocked(new_pos) and not _footprint_blocked(old):
		return true
	var foot_old := _hero_footprint(old)
	var foot_new := _hero_footprint(new_pos)
	for actor in _world_actors():
		var rect: Rect2 = actor["rect"]
		if foot_new.intersects(rect) and (not foot_old.intersects(rect) or foot_new.get_center().distance_to(rect.get_center()) < foot_old.get_center().distance_to(rect.get_center())):
			hero_bump_actor = actor
			return true
	return false

func _hero_mounted_visual() -> bool:
	return mount_back_sprite != null and is_instance_valid(mount_back_sprite) and mount_back_sprite.texture != null

# pegada no chao (linha dos pes) do heroi, ou da montaria quando montado, com o player em pos
func _hero_footprint(pos: Vector2) -> Rect2:
	var foot := pos.y + MOUNT_GROUND_Y
	if _hero_mounted_visual():
		var w := float(mount_back_sprite.texture.get_width())
		if mount_view == "side":
			var left := pos.x + mount_back_sprite.position.x + w * 0.12
			return Rect2(left, foot - 12.0, w * 0.76, 24.0)
		# de frente/costas o corpo ocupa o chao na profundidade (para cima da linha dos pes)
		return Rect2(pos.x - w * 0.28, foot - 44.0, w * 0.56, 54.0)
	return Rect2(pos.x - 14.0, foot - 8.0, 28.0, 16.0)

# pontos da pegada da montaria testados na mascara andavel (no mesmo referencial do player)
func _footprint_blocked(pos: Vector2) -> bool:
	var rect := _hero_footprint(pos)
	var cy := rect.get_center().y - MOUNT_GROUND_Y
	var points: Array[Vector2] = [Vector2(rect.position.x, cy), Vector2(rect.end.x, cy), Vector2(rect.get_center().x, cy),
		Vector2(rect.position.x + rect.size.x * 0.25, cy), Vector2(rect.position.x + rect.size.x * 0.75, cy),
		Vector2(pos.x, rect.position.y - MOUNT_GROUND_Y), Vector2(pos.x, rect.end.y - MOUNT_GROUND_Y)]
	for point in points:
		if _is_point_blocked(point):
			return true
	# props solidos (fonte, estatuas, bancas): o desenho e mais largo que a colisao; a montaria
	# nao encosta pelos lados para nao sumir por baixo do desenho
	var body := Rect2(rect.position - Vector2(0, MOUNT_GROUND_Y), rect.size)
	for obstacle in solid_obstacles:
		if str(obstacle.get("type", "rect")) == "circle":
			var center: Vector2 = obstacle.get("center", Vector2.ZERO)
			var radius := float(obstacle.get("radius", 0.0)) + 30.0
			var nearest := Vector2(clampf(center.x, body.position.x, body.end.x), clampf(center.y, body.position.y, body.end.y))
			if nearest.distance_to(center) < radius:
				return true
		else:
			var solid: Rect2 = obstacle.get("rect", Rect2())
			# so props (muros e agua longos nao: portoes estreitos continuam passaveis)
			if solid.size.x < 700.0 and solid.size.y < 700.0 and solid.grow_individual(40.0, 60.0, 40.0, 10.0).intersects(body):
				return true
	return false

func _player_attack(power: float, radius: float, skill_id: String) -> void:
	if not is_inside_tree():
		return
	if player.in_safe_zone:
		_flash_red("Nao pode atacar em zona segura")
		return
	# atacar sempre tira da montaria, mesmo errando o golpe
	_enter_combat_dismount("Voce desceu da montaria para lutar.")
	var multiplier := power
	var crit := false
	if player.class_name_selected == "Arqueiro":
		var crit_mult := CombatSystem.roll_critical(0.10, 1.5)
		crit = crit_mult > 1.0
		multiplier *= crit_mult
	var enemy := _get_closest_enemy_in_range(radius)
	if enemy == null:
		_flash("Ataque errou: aproxime-se ou mire melhor.")
		return
	if _is_point_in_safe_zone(enemy.global_position):
		_flash_red("Nao pode atacar em zona segura")
		return
	_dismount_current_mount("Voce desceu da montaria para lutar.")
	_set_current_target(enemy)
	pet_allowed_target = enemy
	if skill_id == "basic_attack":
		_spawn_basic_attack_effect(enemy)
	else:
		_spawn_skill_projectile(skill_id, enemy)
	multiplier *= player.damage_multiplier_for(skill_id)
	var attack_value: float = player.get_attack_value()
	if player.class_name_selected == "Arqueiro" or skill_id in ["precise_shot", "arrow_rain", "stun_shot"]:
		attack_value += player.ataque_distancia
	if skill_id in ["fireball", "arcane_blast", "blue_meteor", "burning_fireball", "fire_hurricane"]:
		attack_value += player.ataque_magico
	var damage := CombatSystem.physical_damage(attack_value, enemy.defesa, multiplier, player.physical_damage_pct)
	enemy.receive_damage(damage)
	CombatJuice.on_enemy_hit(self, player_camera, enemy, player.global_position, enemy.vida <= 0, skill_id != "basic_attack")
	if crit:
		_spawn_floating_text(enemy.global_position + Vector2(0, -44), "-%d!" % damage, Color("#ffd23f"), true)
	else:
		_spawn_floating_text(enemy.global_position + Vector2(0, -34), "-%d" % damage, Color("#ffffff") if skill_id == "basic_attack" else Color("#ff9d4a"), skill_id != "basic_attack")
	var skill_data := _skill_data(skill_id)
	if skill_id == "burning_fireball":
		enemy.apply_burn(int(skill_data.get("burn_damage", 4)), float(skill_data.get("burn_duration", 4.0)))
		_spawn_floating_text(enemy.global_position + Vector2(0, -52), "queimando", Color("#ff9a38"))
	if skill_id == "stun_shot":
		enemy.apply_stun(float(skill_data.get("stun_duration", 2.0)))
		_spawn_floating_text(enemy.global_position + Vector2(0, -52), "stun", Color("#8fd7ff"))
	player.on_hit_enemy(skill_id)

func _player_area_attack(power: float, radius: float, skill_id: String) -> void:
	if not is_inside_tree():
		return
	if player.in_safe_zone:
		_flash_red("Nao pode atacar em zona segura")
		return
	_enter_combat_dismount("Voce desceu da montaria para lutar.")
	var hits := 0
	var center := player.global_position
	if skill_id in ["arrow_rain", "fire_hurricane"]:
		var target := _get_closest_enemy_in_range(_auto_target_radius())
		if target != null:
			if _is_point_in_safe_zone(target.global_position):
				_flash_red("Nao pode atacar em zona segura")
				return
			center = target.global_position
			_set_current_target(target)
			pet_allowed_target = target
	_dismount_current_mount("Voce desceu da montaria para lutar.")
	_spawn_area_effect(center, radius, skill_id)
	var tree := get_tree()
	if tree == null:
		return
	for enemy in tree.get_nodes_in_group("enemies"):
		if _is_point_in_safe_zone(enemy.global_position):
			continue
		if center.distance_to(enemy.global_position) <= radius:
			var attack_value: float = player.get_attack_value()
			if skill_id == "arrow_rain":
				attack_value += player.ataque_distancia
			if skill_id in ["arcane_blast", "fire_hurricane"]:
				attack_value += player.ataque_magico
			var damage := CombatSystem.physical_damage(attack_value, enemy.defesa, power * player.damage_multiplier_for(skill_id), player.physical_damage_pct)
			enemy.receive_damage(damage)
			CombatJuice.on_enemy_hit(self, player_camera, enemy, center, enemy.vida <= 0, false, true)
			_spawn_floating_text(enemy.global_position + Vector2(0, -34), "-%d" % damage, Color("#ff4c4c"))
			player.on_hit_enemy(skill_id)
			if pet_allowed_target == null:
				pet_allowed_target = enemy
			hits += 1
	if skill_id == "fire_hurricane":
		_start_area_dot(center, radius, skill_id, power, 3.0, 0.75)
	elif skill_id == "arrow_rain":
		_start_area_dot(center, radius, skill_id, power * 0.7, 1.5, 0.5)
	_flash("Habilidade acertou %d alvo(s)." % hits)

func _player_dash(distance: float, skill_id: String) -> void:
	_enter_combat_dismount("Voce desceu da montaria para lutar.")
	var start: Vector2 = player.global_position
	var dir: Vector2 = -player.global_position.direction_to(get_global_mouse_position())
	if dir.length() == 0:
		dir = Vector2.DOWN
	player.global_position += dir.normalized() * distance
	_spawn_dash_effect(start, player.global_position, skill_id)

func _player_self_effect(skill_id: String) -> void:
	_enter_combat_dismount("Voce desceu da montaria para lutar.")
	if skill_id in ["war_cry", "mystic_shield", "hero_hour", "agility"]:
		if skill_id in ["hero_hour"]:
			_dismount_current_mount("Voce desceu da montaria para lutar.")
		_spawn_self_effect(skill_id)

func _spawn_coin_drop(amount: int, pos: Vector2) -> void:
	var drop: ItemDrop = DROP_SCENE.instantiate()
	world.add_child(drop)
	drop.setup_coin(amount)
	drop.global_position = pos
	drop.body_entered.connect(func(body: Node) -> void:
		if body == player:
			_collect_drop(drop)
	)

func _spawn_drop(item_name: String, pos: Vector2) -> void:
	var drop: ItemDrop = DROP_SCENE.instantiate()
	world.add_child(drop)
	drop.setup(item_name, 1)
	drop.global_position = pos
	drop.body_entered.connect(func(body: Node) -> void:
		if body == player:
			_collect_drop(drop)
	)

func _collect_nearby_drops(delta: float) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("drops"):
		var drop := node as ItemDrop
		if drop == null or not is_instance_valid(drop) or not drop.can_auto_collect():
			continue
		if bool(drop.get_meta("manual_collect", false)):
			continue
		var distance := player.global_position.distance_to(drop.global_position)
		if distance <= DROP_PICKUP_RADIUS:
			drop.global_position = drop.global_position.move_toward(player.global_position, DROP_MAGNET_SPEED * delta)
		if distance <= DROP_COLLECT_RADIUS:
			_collect_drop(drop)

func _collect_nearest_manual_drop(max_distance: float = 72.0) -> bool:
	if player == null or not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var nearest: ItemDrop = null
	var nearest_distance := max_distance
	for node in tree.get_nodes_in_group("drops"):
		var drop := node as ItemDrop
		if drop == null or not is_instance_valid(drop):
			continue
		if not bool(drop.get_meta("manual_collect", false)):
			continue
		var distance := player.global_position.distance_to(drop.global_position)
		if distance <= nearest_distance:
			nearest = drop
			nearest_distance = distance
	if nearest != null:
		return _collect_drop(nearest)
	return false

func _collect_drop(drop: ItemDrop) -> bool:
	if drop == null or not is_instance_valid(drop):
		return false
	if drop.is_coin:
		player.ouro += drop.amount
		AudioManager.play_sfx("moeda")
		drop.queue_free()
		_flash("+%d ouro" % drop.amount)
		_pet_emote("brilho")
		return true
	if player.inventory.add_item(drop.item_name, drop.amount):
		quest_system.register_collect(drop.item_name, drop.amount)
		if game_extras != null:
			game_extras.daily_progress("collect", drop.amount, drop.item_name)
		drop.queue_free()
		AudioManager.play_sfx("item")
		_flash("Coletado: " + drop.item_name)
		_pet_emote("alerta")
		return true
	return false

func _spawn_pet_attack_line(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color("#8eea77")
	line.z_index = 92
	line.add_point(from)
	line.add_point(to)
	world.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate", Color(1, 1, 1, 0), 0.26)
	tween.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)

func _current_equipped_pet_entry() -> Dictionary:
	var payload: Dictionary = mmo_cache.get("pets_state", {})
	for pet in payload.get("pets", []):
		if typeof(pet) == TYPE_DICTIONARY and bool(pet.get("equipped", false)):
			return pet
	return {}

func _pet_icon_path(code: String) -> String:
	var asset := _pet_asset_name(code)
	if not asset.is_empty():
		for direction in ["left", "front", "right", "back"]:
			var frame_path := _pet_frame_path(asset, "idle", direction, 1)
			if ResourceLoader.exists(frame_path):
				return frame_path
	return "res://assets/sprites/drop_bag.png"

func _pet_bonus_text(bonus: Dictionary) -> String:
	if bonus.has("physical_attack_pct"):
		return "+%d%% ataque fisico" % int(round(float(bonus.get("physical_attack_pct", 0.0)) * 100.0))
	if bonus.has("mana_regen_pct"):
		return "+%d%% regen mana" % int(round(float(bonus.get("mana_regen_pct", 0.0)) * 100.0))
	if bonus.has("attack_speed_pct"):
		return "+%d%% vel. ataque" % int(round(float(bonus.get("attack_speed_pct", 0.0)) * 100.0))
	if bonus.has("max_hp_pct"):
		return "+%d%% vida maxima" % int(round(float(bonus.get("max_hp_pct", 0.0)) * 100.0))
	return "Bonus desconhecido"

func _mount_icon_path(code: String) -> String:
	# arte propria da montaria (assets/sprites/mounts/<code>.png, gerada no ChatGPT); sem ela, os provisorios
	var own := "res://assets/sprites/mounts/%s.png" % code
	if ResourceLoader.exists(own):
		return own
	match code:
		"brown_horse":
			var horse := "res://assets/maps/valdoria_v2/anim/horse_idle_right/0.png"
			if ResourceLoader.exists(horse):
				return horse
			return "res://assets/sprites/enemy_lobo.png"
		"gray_wolf":
			return "res://assets/sprites/enemy_lobo.png"
		"war_boar":
			return "res://assets/sprites/enemy_javali.png"
		"shadow_panther":
			return "res://assets/sprites/enemy_lobo.png"
		"crystal_stag":
			return "res://assets/sprites/decor_crystal.png"
	return "res://assets/sprites/drop_bag.png"

func _pet_asset_name(code: String) -> String:
	return str(PET_ASSET_BY_CODE.get(code, ""))

func _pet_move_animation(asset: String) -> String:
	return "walk"

func _pet_frame_path(asset: String, animation: String, direction: String, frame: int) -> String:
	return "res://assets/sprites/pets/%s/%s_%s/%s_%s_%s_%02d.png" % [asset, animation, direction, asset, animation, direction, frame]

func _pet_animation_frames(asset: String, animation: String, direction: String) -> Array:
	var key := "%s|%s|%s" % [asset, animation, direction]
	if pet_animation_cache.has(key):
		return pet_animation_cache[key]
	var frames: Array = []
	for i in range(1, 25):
		var path := _pet_frame_path(asset, animation, direction, i)
		if not ResourceLoader.exists(path):
			break
		var texture := load(path)
		if texture != null:
			frames.append(texture)
	pet_animation_cache[key] = frames
	return frames

# O pet anda sozinho em volta do heroi: escolhe um ponto perto dele de tempos em tempos,
# corre atras quando o heroi se afasta e chega perto do alvo quando esta atacando.
func _pet_is_ground() -> bool:
	return not PET_FLYING_ASSETS.has(_pet_asset_name(_current_equipped_pet_code()))

func _hero_foot_y() -> float:
	return player.global_position.y + MOUNT_GROUND_Y

# x da esquerda e da direita do corpo do heroi (ou da montaria) no mundo
func _hero_body_span() -> Vector2:
	var x := player.global_position.x
	if mount_back_sprite != null and is_instance_valid(mount_back_sprite) and mount_back_sprite.texture != null:
		var w := float(mount_back_sprite.texture.get_width())
		var left := x + mount_back_sprite.position.x
		return Vector2(left + w * 0.08, left + w * 0.92)
	return Vector2(x - 28.0, x + 28.0)

# na frente do heroi/montaria e perto o bastante para o pet ficar desenhado por cima dele
func _pet_in_front_zone(p: Vector2) -> bool:
	var span := _hero_body_span()
	var foot := _hero_foot_y()
	return p.x > span.x - PET_HALF_WIDTH and p.x < span.y + PET_HALF_WIDTH and p.y > foot and p.y < foot + PET_FRONT_DEPTH

func _update_pet_wander(delta: float) -> void:
	var ground := _pet_is_ground()
	pet_wander_timer -= delta
	if pet_wander_timer <= 0.0:
		var span := _hero_body_span()
		var half := (span.y - span.x) * 0.5
		var r_min := maxf(70.0, half + PET_HALF_WIDTH + 8.0)
		for attempt in range(12):
			var angle := randf() * TAU
			var radius := randf_range(r_min, r_min + 60.0)
			pet_wander_offset = Vector2(cos(angle) * radius, sin(angle) * radius * 0.55 + 20.0)
			var spot := player.global_position + pet_wander_offset
			if (not ground or not _pet_in_front_zone(spot)) and not _pet_point_blocked(spot):
				break
			if attempt == 11:
				pet_wander_offset = Vector2(signf(pet_wander_offset.x + 0.01) * r_min, MOUNT_GROUND_Y)
		pet_wander_timer = randf_range(1.8, 3.6)
	var desired := player.global_position + pet_wander_offset
	var fighting := pet_attack_visual_timer > 0.0 and pet_allowed_target != null and is_instance_valid(pet_allowed_target)
	if fighting:
		var from_target := player.global_position - pet_allowed_target.global_position
		desired = pet_allowed_target.global_position + from_target.normalized() * 85.0 + Vector2(0, 10)
	var to := desired - pet_pos
	var dist := to.length()
	if dist > 900.0:  # trocou de mapa / teleportou: aparece do lado do heroi
		pet_pos = desired
		to = Vector2.ZERO
		dist = 0.0
	var speed := clampf(dist * 2.2, 70.0, 460.0)
	var step := minf(dist, speed * delta)
	var moved := to.normalized() * step if dist > 0.5 else Vector2.ZERO
	pet_pos += moved
	if dist <= 900.0:
		var before := pet_pos - moved
		pet_pos = _pet_world_rules(before, pet_pos)
		# preso atras de parede/fonte enquanto o heroi se afasta: reaparece do lado dele
		pet_stuck_time = pet_stuck_time + delta if dist > 220.0 and pet_pos.distance_to(before) < 0.5 else 0.0
		if pet_stuck_time > 1.2:
			pet_stuck_time = 0.0
			for spot in [desired, player.global_position + Vector2(-90, 20), player.global_position + Vector2(90, 20), player.global_position + Vector2(0, -40)]:
				if not _pet_point_blocked(spot) and not _pet_actor_hit(spot).has_area():
					pet_pos = spot
					break
	if ground and dist <= 900.0:
		pet_pos = _pet_keep_off_hero(pet_pos, desired, speed * delta)
	pet_was_behind = pet_pos.y <= _hero_foot_y()
	pet_moving = dist > 6.0 and step > 0.4
	var face := moved
	if fighting:
		face = pet_allowed_target.global_position - pet_pos
	if face.length() > 0.5 and (pet_moving or fighting):
		if abs(face.x) >= abs(face.y) * 0.8:
			pet_last_direction = "right" if face.x > 0.0 else "left"
		else:
			pet_last_direction = "back" if face.y < 0.0 else "front"

# Pets seguem as regras do mundo: nao passam por paredes, agua, fonte e solidos (mascara andavel),
# e esbarram em NPCs e pedestres; se algo andou para cima dele, ele sai pelo lado mais perto.
func _pet_point_blocked(p: Vector2) -> bool:
	# a mascara andavel e calibrada para o centro do heroi; os pes do pet ficam ~MOUNT_GROUND_Y abaixo
	return _is_point_blocked(p - Vector2(0, MOUNT_GROUND_Y))

func _pet_actor_hit(p: Vector2) -> Rect2:
	for actor in _world_actor_rects():
		var rect: Rect2 = actor
		if rect.grow(10.0).has_point(p):
			return rect.grow(10.0)
	return Rect2()

func _pet_world_rules(old: Vector2, new_pos: Vector2) -> Vector2:
	var old_blocked := _pet_point_blocked(old)
	var candidates: Array[Vector2] = [new_pos, Vector2(new_pos.x, old.y), Vector2(old.x, new_pos.y)]
	var result := old
	for c in candidates:
		if old_blocked or not _pet_point_blocked(c):
			var hit := _pet_actor_hit(c)
			if not hit.has_area() or _pet_actor_hit(old).has_area():
				result = c
				break
	# um pedestre/NPC chegou em cima do pet: sai pela borda mais perto
	var inside := _pet_actor_hit(result)
	if inside.has_area():
		var exits: Array[Vector2] = [Vector2(inside.position.x - 1.0, result.y), Vector2(inside.end.x + 1.0, result.y),
			Vector2(result.x, inside.position.y - 1.0), Vector2(result.x, inside.end.y + 1.0)]
		var best := exits[0]
		for e in exits:
			if e.distance_to(result) < best.distance_to(result) and not _pet_point_blocked(e):
				best = e
		result = result.move_toward(best, 6.0)
	return result

# Empurra o pet de chao para fora da frente do heroi/montaria pelo caminho mais curto. Quem
# estava atras pode encostar na linha dos pes (fica atras); quem estava na frente e barrado
# pelo corpo e contorna pelo lado mais perto quando quer passar para tras.
func _pet_keep_off_hero(p: Vector2, desired: Vector2, step: float) -> Vector2:
	if not _pet_in_front_zone(p):
		return p
	var span := _hero_body_span()
	var foot := _hero_foot_y()
	var options: Array = [
		[p.x - (span.x - PET_HALF_WIDTH), Vector2(span.x - PET_HALF_WIDTH, p.y)],
		[(span.y + PET_HALF_WIDTH) - p.x, Vector2(span.y + PET_HALF_WIDTH, p.y)],
	]
	if pet_was_behind:
		options.append([p.y - foot, Vector2(p.x, foot)])
	else:
		options.append([foot + PET_FRONT_DEPTH - p.y, Vector2(p.x, foot + PET_FRONT_DEPTH)])
	var best: Array = options[0]
	for option in options:
		if float(option[0]) < float(best[0]):
			best = option
	var out: Vector2 = best[1]
	# barrado em cima/embaixo mas o destino esta do outro lado: anda de lado ate sair do corpo
	if absf(out.x - p.x) < 0.01 and (desired.y <= foot) != pet_was_behind:
		var middle := (span.x + span.y) * 0.5
		out.x += -step if p.x < middle else step
	return out

func _pet_direction_from_player() -> String:
	if player == null:
		return pet_last_direction
	var v := player.velocity
	if v.length() <= 8.0:
		return pet_last_direction
	if abs(v.x) >= abs(v.y):
		pet_last_direction = "right" if v.x > 0.0 else "left"
	else:
		pet_last_direction = "back" if v.y < 0.0 else "front"
	return pet_last_direction

func _pet_animation_texture(code: String, delta: float) -> Texture2D:
	var asset := _pet_asset_name(code)
	if asset.is_empty():
		return null
	var direction := pet_last_direction
	if pet_attack_visual_timer > 0.0:
		pet_attack_visual_timer -= delta
	var moving := pet_moving
	var animation := "attack" if pet_attack_visual_timer > 0.0 else (_pet_move_animation(asset) if moving else "idle")
	var requested_direction := direction
	var frame_direction := "left" if requested_direction == "right" else requested_direction
	var frames := _pet_animation_frames(asset, animation, frame_direction)
	var actual_direction := frame_direction
	if frames.is_empty():
		for fallback_direction in ["left", "front", "right", "back"]:
			if fallback_direction == frame_direction:
				continue
			frames = _pet_animation_frames(asset, animation, fallback_direction)
			if not frames.is_empty():
				actual_direction = fallback_direction
				break
	if frames.is_empty() and animation != "idle":
		actual_direction = frame_direction
		frames = _pet_animation_frames(asset, "idle", frame_direction)
		if frames.is_empty():
			for fallback_direction in ["left", "front", "right", "back"]:
				if fallback_direction == frame_direction:
					continue
				frames = _pet_animation_frames(asset, "idle", fallback_direction)
				if not frames.is_empty():
					actual_direction = fallback_direction
					break
	if frames.is_empty():
		return null
	pet_animation_actual_direction = actual_direction
	var key := "%s|%s|%s" % [asset, animation, actual_direction]
	if key != pet_animation_key:
		pet_animation_key = key
		pet_animation_frame = 0
		pet_animation_timer = 0.0
	var fps := 12.0 if animation == "attack" else (10.0 if moving else 6.0)
	pet_animation_timer += delta
	if pet_animation_timer >= 1.0 / fps:
		pet_animation_timer = 0.0
		pet_animation_frame = (pet_animation_frame + 1) % frames.size()
	return frames[pet_animation_frame % frames.size()]

func _update_companion_visuals(delta: float) -> void:
	if player == null:
		return
	_update_mount_button()
	_update_mount_perks(delta)
	if game_extras != null:
		game_extras.process(delta)
	_update_pet_mood(delta)
	_update_pet_affinity(delta)
	companion_anim_time += delta
	var bob := sin(companion_anim_time * 8.0) * 3.0
	var pet_code := _current_equipped_pet_code()
	if not pet_code.is_empty():
		if pet_follower == null or not is_instance_valid(pet_follower):
			pet_follower = Sprite2D.new()
			pet_follower.z_index = 14
			pet_follower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			world.add_child(pet_follower)
			pet_pos = player.global_position + pet_wander_offset
		_update_pet_wander(delta)
		var texture := _pet_animation_texture(pet_code, delta)
		if texture != null:
			pet_follower.texture = texture
		else:
			pet_follower.texture = load(_pet_icon_path(pet_code))
		if pet_follower.texture != null:
			var height := maxf(1.0, float(pet_follower.texture.get_height()))
			var scale_value: float = PET_TARGET_HEIGHT / height
			pet_follower.scale = Vector2(scale_value, scale_value)
			pet_follower.centered = true
			pet_follower.offset = Vector2(0, -height * 0.5)
		pet_follower.flip_h = pet_last_direction == "right" and pet_animation_actual_direction == "left"
		pet_follower.global_position = pet_pos
		# voadores ficam no ar balancando, com a sombra no chao mostrando onde estao
		var flying := not _pet_is_ground()
		if flying:
			pet_follower.global_position.y -= 30.0 + sin(companion_anim_time * 3.0) * 5.0
			if pet_shadow == null or not is_instance_valid(pet_shadow):
				pet_shadow = Sprite2D.new()
				pet_shadow.texture = load("res://assets/sprites/decor_shadow_soft.png")
				pet_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				pet_shadow.modulate = Color(1, 1, 1, 0.45)
				world.add_child(pet_shadow)
			var lift := 30.0 + sin(companion_anim_time * 3.0) * 5.0
			pet_shadow.global_position = pet_pos
			pet_shadow.scale = Vector2(0.5, 0.24) * (1.0 - (lift - 25.0) / 60.0)
			pet_shadow.z_index = clampi(int(pet_pos.y) - 1, -1024, 1024)
		elif pet_shadow != null and is_instance_valid(pet_shadow):
			pet_shadow.queue_free()
			pet_shadow = null
		# profundidade pela linha dos pes, igual ao player e aos props
		var pet_z := clampi(int(pet_pos.y), -1024, 1024)
		if _pet_is_ground() and absf(pet_pos.x - player.global_position.x) < 260.0 and absf(pet_pos.y - _hero_foot_y()) < 140.0:
			# perto do heroi decide sem empate: atras da montaria (z do player - 1) ou na frente do cavaleiro (+1)
			pet_z = player.z_index - 2 if pet_pos.y <= _hero_foot_y() else player.z_index + 2
		pet_follower.z_index = pet_z
	else:
		if pet_follower != null and is_instance_valid(pet_follower):
			pet_follower.queue_free()
			pet_follower = null
		if pet_shadow != null and is_instance_valid(pet_shadow):
			pet_shadow.queue_free()
			pet_shadow = null
	var mount_code := _current_equipped_mount_code()
	if not mount_code.is_empty() and _mount_rig(mount_code).is_empty():
		# montaria sem animacao: imagem parada embaixo do heroi (provisorio)
		_clear_mount_rider()
		if mount_follower == null or not is_instance_valid(mount_follower):
			mount_follower = Sprite2D.new()
			mount_follower.z_index = 13
			world.add_child(mount_follower)
		mount_follower.texture = load(_mount_icon_path(mount_code))
		var mount_height := 96.0
		if mount_follower.texture != null:
			mount_height = maxf(1.0, float(mount_follower.texture.get_height()))
		mount_follower.scale = Vector2.ONE * (140.0 / mount_height)
		mount_follower.modulate = Color(1, 1, 1, 0.65)
		mount_follower.flip_h = player.velocity.x > 8.0
		mount_follower.global_position = player.global_position + Vector2(0, 30 + bob * 0.4)
	else:
		if mount_follower != null and is_instance_valid(mount_follower):
			mount_follower.queue_free()
			mount_follower = null
		if mount_code.is_empty():
			_clear_mount_rider()
		else:
			_update_mount_rider(mount_code, delta)

func _mount_rig(code: String) -> Dictionary:
	if mount_rig_cache.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/mounts/mounts_rig.json"))
		mount_rig_cache = data if data is Dictionary else {"_": {}}
	var rig = mount_rig_cache.get(code, {})
	if rig is Dictionary and rig.has("seat") and ResourceLoader.exists("res://assets/sprites/mounts/%s/walk/0.png" % code):
		return rig
	return {}

func _mount_frames(code: String, anim: String, front_cut: int) -> Array:
	var key := "%s|%s|%d" % [code, anim, front_cut]
	if mount_frames_cache.has(key):
		return mount_frames_cache[key]
	var frames: Array = []
	for i in range(16):
		var path := "res://assets/sprites/mounts/%s/%s/%d.png" % [code, anim, i]
		if not ResourceLoader.exists(path):
			break
		var tex := load(path) as Texture2D
		if front_cut > 0:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(0, front_cut, tex.get_width(), tex.get_height() - front_cut)
			frames.append(atlas)
		else:
			frames.append(tex)
	mount_frames_cache[key] = frames
	return frames

func _mount_rider_info(view: String = "side") -> Dictionary:
	# quadros do heroi montado da classe atual na vista pedida:
	# {"frames": [Texture2D], "frame": [w, h], "seat": [x, y], "head_y": y}
	var folder: String = player._class_pack_folder(player.class_name_selected) if player != null and player.has_method("_class_pack_folder") else ""
	var key := folder + "|" + view
	if mount_riders_cache.has(key):
		return mount_riders_cache[key]
	var info: Dictionary = {}
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/mounts/riders/riders.json"))
	if not folder.is_empty() and data is Dictionary and data.has(folder):
		var entry: Dictionary = data[folder]
		if view != "side":
			entry = entry.get(view, {})
		var base := "res://assets/sprites/mounts/riders/%s/" % folder + ("" if view == "side" else view + "/")
		var frames: Array = []
		for i in range(8):
			var path := base + "%d.png" % i
			if not ResourceLoader.exists(path):
				break
			frames.append(load(path))
		if not frames.is_empty() and entry.has("seat"):
			info = entry.duplicate()
			info["frames"] = frames
	mount_riders_cache[key] = info
	return info

# vista da montaria pelo movimento: subindo = de costas, descendo = de frente, para os lados = de lado
func _mount_view_for(code: String) -> String:
	var v := player.velocity
	var view := mount_view
	if v.length() > 8.0:
		if absf(v.y) > absf(v.x) * 1.1:
			view = "back" if v.y < 0.0 else "front"
		else:
			view = "side"
	if view != "side":
		var rig := _mount_rig(code)
		if not (rig.get(view, {}) as Dictionary).has("seat") or not ResourceLoader.exists("res://assets/sprites/mounts/%s/walk_%s/0.png" % [code, view]) or _mount_rider_info(view).is_empty():
			view = "side"
	return view

func _update_mount_rider(code: String, delta: float) -> void:
	var rig := _mount_rig(code)
	mount_view = _mount_view_for(code)
	var view_rig: Dictionary = rig if mount_view == "side" else rig.get(mount_view, {})
	var frame_size: Array = view_rig.get("frame", [160, 160])
	var w := float(frame_size[0])
	var feet_y := float(view_rig.get("feet_y", frame_size[1]))
	var seat: Array = view_rig.get("seat", [w * 0.5, feet_y * 0.4])
	var seat_x := float(seat[0])
	var seat_y := float(seat[1])
	if mount_back_sprite == null or not is_instance_valid(mount_back_sprite):
		mount_back_sprite = Sprite2D.new()
		mount_back_sprite.centered = false
		mount_back_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mount_back_sprite.z_index = -1
		player.add_child(mount_back_sprite)
		mount_rider_sprite = Sprite2D.new()
		mount_rider_sprite.centered = false
		mount_rider_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mount_rider_sprite.z_index = 1
		player.add_child(mount_rider_sprite)
	if player.velocity.x > 8.0:
		mount_facing_right = true
	elif player.velocity.x < -8.0:
		mount_facing_right = false
	var moving := player.velocity.length() > 8.0
	var anim := "walk" if moving else "idle"
	if mount_view != "side":
		anim += "_" + mount_view
	var back_frames := _mount_frames(code, anim, 0)
	if back_frames.is_empty():
		return
	mount_anim_time += delta
	var fps := 10.0 if moving else 5.0
	var index := int(mount_anim_time * fps) % back_frames.size()
	mount_back_sprite.texture = back_frames[index]
	# de lado a arte olha para a esquerda; virada para a direita espelha em volta da sela
	var flip := mount_facing_right and mount_view == "side"
	var anchor_x := (w - seat_x) if flip else seat_x
	mount_back_sprite.flip_h = flip
	mount_back_sprite.position = Vector2(-anchor_x, MOUNT_GROUND_Y - feet_y)
	var seat_local_y := MOUNT_GROUND_Y - feet_y + seat_y
	var rider := _mount_rider_info(mount_view)
	if rider.is_empty():
		# classe sem arte montada: heroi normal em cima da sela
		mount_rider_sprite.visible = false
		player.set_mount_lift(maxf(0.0, (feet_y - seat_y) - HERO_HIP_TO_FEET))
		return
	var rider_frames: Array = rider["frames"]
	var rider_size: Array = rider.get("frame", [96, 120])
	var rider_seat: Array = rider.get("seat", [48, 80])
	# o cavaleiro balanca junto com a passada (2 quadros da montaria por quadro dele)
	var rider_index := (index / 2) % rider_frames.size() if moving else int(mount_anim_time * 2.5) % rider_frames.size()
	mount_rider_sprite.visible = true
	mount_rider_sprite.texture = rider_frames[rider_index]
	mount_rider_sprite.flip_h = flip
	# de frente o cavaleiro fica atras da cabeca/peito da montaria; de lado e de costas, na frente
	mount_rider_sprite.z_index = -2 if mount_view == "front" else 1
	var rider_anchor_x := (float(rider_size[0]) - float(rider_seat[0])) if flip else float(rider_seat[0])
	mount_rider_sprite.position = Vector2(-rider_anchor_x, seat_local_y - float(rider_seat[1]))
	mount_rider_sprite.modulate = player.sprite.modulate if player.get("sprite") != null else Color.WHITE
	var head_local_y := seat_local_y - float(rider_seat[1]) + float(rider.get("head_y", 0.0))
	player.set_mount_lift(maxf(0.0, HERO_HEAD_Y - head_local_y), true)

func _clear_mount_rider() -> void:
	if mount_back_sprite != null and is_instance_valid(mount_back_sprite):
		mount_back_sprite.queue_free()
	if mount_rider_sprite != null and is_instance_valid(mount_rider_sprite):
		mount_rider_sprite.queue_free()
	mount_back_sprite = null
	mount_rider_sprite = null
	if player != null and player.has_method("set_mount_lift"):
		player.set_mount_lift(0.0)

func _current_equipped_pet_code() -> String:
	var payload: Dictionary = mmo_cache.get("pets_state", {})
	for pet in payload.get("pets", []):
		if typeof(pet) == TYPE_DICTIONARY and bool(pet.get("equipped", false)):
			return str(pet.get("code", ""))
	return ""

func _current_equipped_mount_code() -> String:
	var payload: Dictionary = mmo_cache.get("mounts_state", {})
	for mount in payload.get("mounts", []):
		if typeof(mount) == TYPE_DICTIONARY and bool(mount.get("equipped", false)):
			return str(mount.get("code", ""))
	if not online_mode:
		return ""
	return ""
