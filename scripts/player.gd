extends CharacterBody2D
class_name Player

# Estado e regras do personagem jogavel. Os atributos "raw" guardam a
# progressao real; os atributos exibidos recebem bonus de equipamentos/joias.
signal stats_changed
signal message_requested(text: String)
signal damage_taken(amount: int)
signal healed(amount: int)
signal died
signal attack_requested(power: float, radius: float, skill_id: String)
signal skill_area_requested(power: float, radius: float, skill_id: String)
signal dash_requested(distance: float, skill_id: String)
signal self_effect_requested(skill_id: String)

var class_name_selected := ""
var character_name := "Aventureiro"
var level := 1
var xp := 0
var ouro := 0
var vida := 100
var vida_max := 100
var mana := 50
var mana_max := 50
var ataque := 10
var ataque_distancia := 0
var defesa := 5
var raw_ataque := 10
var raw_defesa := 5
var velocidade_ataque := 1.0
var velocidade_movimento := 180.0
var alcance := 60.0
var ataque_magico := 0
var xp_ataque := 0
var xp_defesa := 0
var xp_speed_attack := 0
var speed_attack_level := 1
var incoming_hits := 0
var physical_damage_pct := 0.0
var mana_regen_pct := 0.0
var attack_speed_pct := 0.0
var move_speed_pct := 0.0
var companion_physical_damage_pct := 0.0
var companion_mana_regen_pct := 0.0
var companion_attack_speed_pct := 0.0
var companion_move_speed_pct := 0.0
var companion_vida_max_pct := 0.0
var shield_points := 0
var poison_timer := 0.0
var skills: Dictionary = {}
var in_safe_zone := false

var inventory := InventorySystem.new()
var class_data: Dictionary = {}
var item_db: ItemDatabase
var can_attack := true
var war_cry_timer := 0.0
var war_cry_bonus := 0.0
var hero_hour_timer := 0.0
var hero_attack_bonus := 0.0
var hero_defense_bonus := 0.0
var agility_timer := 0.0
var agility_move_bonus := 0.0
var agility_attack_bonus := 0.0
var current_sprite_path := ""
var current_sprite_flip := false
var current_sprite_direction := "front"
var walk_anim_time := 0.0
var walk_anim_frame := 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel
var shadow_sprite: Sprite2D

func setup(chosen_class: String, data: Dictionary, database: ItemDatabase) -> void:
	collision_layer = 1
	collision_mask = 0
	class_name_selected = chosen_class
	class_data = data
	item_db = database
	if skills.is_empty():
		skills = SkillProgressionSystem.default_skills()
	var base: Dictionary = data.get("base", {})
	vida_max = int(base.get("vida", 100))
	mana_max = int(base.get("mana", 50))
	vida = vida_max
	mana = mana_max
	ataque = int(base.get("ataque", 10))
	ataque_distancia = 0
	defesa = int(base.get("defesa", 5))
	raw_ataque = ataque
	raw_defesa = defesa
	velocidade_ataque = float(base.get("velocidade_ataque", 1.0))
	velocidade_movimento = float(base.get("velocidade_movimento", 180))
	alcance = float(base.get("alcance", 60))
	_set_player_sprite(_player_sprite_path(chosen_class), false)
	inventory.add_item(str(data.get("weapon", "")), 1)
	inventory.equip(str(data.get("weapon", "")), item_db.get_item(str(data.get("weapon", ""))))
	inventory.add_item("Pocao pequena de vida", 3)
	inventory.add_item("Pocao pequena de mana", 3)
	recalculate_equipment()
	_update_health_bar()
	stats_changed.emit()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_directional_sprite(input, delta)
	velocity = input * velocidade_movimento * (1.0 + move_speed_pct + agility_move_bonus)
	move_and_slide()
	_update_health_bar()
	if war_cry_timer > 0:
		war_cry_timer -= delta
		if war_cry_timer <= 0:
			war_cry_bonus = 0
			stats_changed.emit()
	if hero_hour_timer > 0:
		hero_hour_timer -= delta
		if hero_hour_timer <= 0:
			hero_attack_bonus = 0
			hero_defense_bonus = 0
			stats_changed.emit()
	if agility_timer > 0:
		agility_timer -= delta
		if agility_timer <= 0:
			agility_move_bonus = 0
			agility_attack_bonus = 0
			stats_changed.emit()
	if poison_timer > 0:
		poison_timer -= delta
		if int(poison_timer * 10) % 10 == 0:
			_take_raw_damage(1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		basic_attack()
	elif event.is_action_pressed("skill_1"):
		use_skill(0)
	elif event.is_action_pressed("skill_2"):
		use_skill(1)
	elif event.is_action_pressed("skill_3"):
		use_skill(2)

func basic_attack() -> void:
	if not can_attack:
		return
	if in_safe_zone:
		message_requested.emit("Zona segura: ataques bloqueados perto dos portais.")
		return
	_gain_speed_attack_xp()
	attack_requested.emit(1.0, alcance, "basic_attack")
	_start_attack_cooldown()

func use_skill(index: int) -> void:
	var skills: Array = class_data.get("skills", [])
	if index >= skills.size():
		return
	var skill: Dictionary = skills[index]
	if in_safe_zone:
		message_requested.emit("Zona segura: habilidades de ataque bloqueadas.")
		return
	if not SkillSystem.can_use(self, skill):
		return
	SkillSystem.cast(self, skill)
	_add_skill_xp("magic", 4)
	_gain_speed_attack_xp()
	self_effect_requested.emit(str(skill.get("id", "")))
	_start_attack_cooldown()

func _start_attack_cooldown() -> void:
	can_attack = false
	await get_tree().create_timer(1.0 / get_attack_speed()).timeout
	can_attack = true

func get_attack_speed() -> float:
	return min(2.35, velocidade_ataque * (1.0 + attack_speed_pct + agility_attack_bonus))

func get_attack_value() -> float:
	return ataque * (1.0 + war_cry_bonus + hero_attack_bonus)

func receive_damage(amount: int, poison_chance: float = 0.0) -> void:
	var final_damage := amount
	if shield_points > 0:
		var absorbed: int = min(shield_points, final_damage)
		shield_points -= absorbed
		final_damage -= absorbed
	if class_name_selected == "Guerreiro":
		incoming_hits += 1
		if incoming_hits >= 5:
			final_damage = int(ceil(final_damage * 0.7))
			incoming_hits = 0
	if hero_defense_bonus > 0:
		final_damage = max(1, int(ceil(float(final_damage) * (1.0 - hero_defense_bonus))))
	if final_damage > 0:
		_take_raw_damage(final_damage)
		_gain_defense_xp()
	if poison_chance > 0 and randf() <= poison_chance:
		poison_timer = 5.0

func _take_raw_damage(amount: int) -> void:
	if amount <= 0:
		return
	vida = max(0, vida - amount)
	damage_taken.emit(amount)
	_update_health_bar()
	stats_changed.emit()
	if vida <= 0:
		died.emit()

func heal(amount: int) -> void:
	if amount <= 0:
		return
	var before := vida
	vida = min(vida_max, vida + amount)
	var recovered := vida - before
	if recovered > 0:
		healed.emit(recovered)
	_update_health_bar()
	stats_changed.emit()

func recover_mana(amount: int) -> void:
	mana = min(mana_max, mana + amount)
	stats_changed.emit()

func spend_mana(amount: int) -> bool:
	var reduced_amount := int(ceil(float(amount) * (1.0 - SkillProgressionSystem.mana_efficiency_bonus(skills))))
	if mana < reduced_amount:
		return false
	mana -= reduced_amount
	stats_changed.emit()
	return true

func pay_life_percent(percent: float) -> bool:
	var cost: int = int(ceil(float(vida_max) * percent))
	if vida <= int(ceil(float(vida_max) * 0.2)):
		message_requested.emit("Seifador de Almas nao pode ser usado com 20% de vida ou menos.")
		return false
	if vida - cost <= 0:
		return false
	_take_raw_damage(cost)
	return true

func on_hit_enemy(skill_id: String = "basic_attack") -> void:
	xp_ataque += 5
	var needed := 100 + ataque * 25
	if xp_ataque >= needed:
		xp_ataque -= needed
		raw_ataque += 1
		recalculate_equipment()
	var progression_id := _progression_for_attack(skill_id)
	var xp_amount := 6 if progression_id == "magic" else 5
	_add_skill_xp(progression_id, xp_amount)
	stats_changed.emit()

func _gain_defense_xp() -> void:
	xp_defesa += 6
	var needed := 100 + defesa * 25
	if xp_defesa >= needed:
		xp_defesa -= needed
		raw_defesa += 1
		recalculate_equipment()
	_add_skill_xp("protection", 6)
	stats_changed.emit()

func _gain_speed_attack_xp() -> void:
	xp_speed_attack += 2
	var needed := 100 + speed_attack_level * 30
	if xp_speed_attack >= needed and velocidade_ataque < 2.0:
		xp_speed_attack -= needed
		speed_attack_level += 1
		velocidade_ataque = min(2.0, velocidade_ataque + 0.03)
	stats_changed.emit()

func _add_skill_xp(skill_id: String, amount: int) -> void:
	var messages := SkillProgressionSystem.add_xp(skills, skill_id, amount, class_name_selected)
	for message in messages:
		recalculate_equipment()
		message_requested.emit(message)

func _progression_for_attack(skill_id: String) -> String:
	if skill_id in ["fireball", "arcane_blast", "mystic_shield", "blue_meteor", "burning_fireball", "fire_hurricane"]:
		return "magic"
	if skill_id in ["precise_shot", "arrow_rain", "stun_shot", "agility"] or class_name_selected == "Arqueiro":
		return "distance"
	return "fighting"

func damage_multiplier_for(skill_id: String) -> float:
	match _progression_for_attack(skill_id):
		"magic":
			return 1.0 + SkillProgressionSystem.magic_damage_bonus(skills)
		"distance":
			return 1.0 + SkillProgressionSystem.distance_damage_bonus(skills)
	return 1.0 + SkillProgressionSystem.fighting_damage_bonus(skills)

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		vida_max += 10
		mana_max += 5
		raw_ataque += 1
		if level % 2 == 0:
			raw_defesa += 1
		vida = vida_max
		mana = mana_max
		recalculate_equipment()
	stats_changed.emit()

func xp_to_next_level() -> int:
	return 100 + level * 80

func on_enemy_killed() -> void:
	if class_name_selected == "Mago":
		recover_mana(int(mana_max * 0.08))

func recalculate_equipment() -> void:
	var keep_hp_ratio: float = float(vida) / max(1.0, float(vida_max))
	var keep_mp_ratio: float = float(mana) / max(1.0, float(mana_max))
	var base: Dictionary = class_data.get("base", {})
	vida_max = int(base.get("vida", vida_max)) + (level - 1) * 10
	var magic_level := int(skills.get("magic", {}).get("level", 10))
	mana_max = int(base.get("mana", mana_max)) + (level - 1) * 5 + max(0, magic_level - 10) * 3
	ataque = raw_ataque
	ataque_distancia = 0
	defesa = raw_defesa
	ataque_magico = 0
	physical_damage_pct = 0
	mana_regen_pct = 0
	attack_speed_pct = 0
	move_speed_pct = 0
	for item_name in inventory.equipment.values():
		if str(item_name).is_empty():
			continue
		var item: Dictionary = item_db.get_item(str(item_name))
		var stats: Dictionary = PlayerStats.normalized_stats(item)
		for stat in stats.keys():
			match str(stat):
				"vida_max":
					vida_max += int(stats[stat])
				"mana_max":
					mana_max += int(stats[stat])
				"ataque":
					ataque += int(stats[stat])
				"ataque_distancia":
					ataque_distancia += int(stats[stat])
				"defesa":
					defesa += int(stats[stat])
				"ataque_magico":
					ataque_magico += int(stats[stat])
				"physical_damage_pct":
					physical_damage_pct += float(stats[stat])
				"mana_regen_pct":
					mana_regen_pct += float(stats[stat])
				"attack_speed_pct":
					attack_speed_pct += float(stats[stat])
				"move_speed_pct":
					move_speed_pct += float(stats[stat])
	defesa += SkillProgressionSystem.protection_defense_bonus(skills)
	_apply_set_bonuses()
	vida = clamp(int(vida_max * keep_hp_ratio), 1, vida_max)
	mana = clamp(int(mana_max * keep_mp_ratio), 0, mana_max)
	stats_changed.emit()

func _apply_set_bonuses() -> void:
	var counts := {}
	for item_name in inventory.equipment.values():
		var set_name := str(item_db.get_item(str(item_name)).get("set", ""))
		if not set_name.is_empty():
			counts[set_name] = int(counts.get(set_name, 0)) + 1
	if int(counts.get("Couro do Aventureiro", 0)) >= 4:
		vida_max += 10
		defesa += 2
		move_speed_pct += 0.03
	if int(counts.get("Ferro do Guardiao", 0)) >= 4:
		vida_max += 25
		defesa += 6
		move_speed_pct -= 0.03
	if int(counts.get("Tecido Arcano", 0)) >= 4:
		mana_max += 30
		ataque_magico += 3
		mana_regen_pct += 0.05
	if int(counts.get("Draconico", 0)) >= 4:
		vida_max += 80
		defesa += 10
		physical_damage_pct += 0.06
	if int(counts.get("Celestial", 0)) >= 1:
		ataque_magico += 2
		mana_regen_pct += 0.04
	if int(counts.get("Aco Sombrio", 0)) >= 4:
		vida_max += 120
		defesa += 18
		physical_damage_pct += 0.08
	if int(counts.get("Cristal Ancestral", 0)) >= 4:
		mana_max += 120
		ataque_magico += 12
		mana_regen_pct += 0.10
	if int(counts.get("Infernal", 0)) >= 2:
		vida_max += 140
		defesa += 18
		physical_damage_pct += 0.08
		attack_speed_pct += 0.04
	_apply_companion_bonuses()

func _apply_companion_bonuses() -> void:
	if companion_vida_max_pct > 0:
		vida_max += int(round(float(vida_max) * companion_vida_max_pct))
	physical_damage_pct += companion_physical_damage_pct
	mana_regen_pct += companion_mana_regen_pct
	attack_speed_pct += companion_attack_speed_pct
	move_speed_pct += companion_move_speed_pct

func revive_in_city() -> void:
	ouro = int(ouro * 0.95)
	vida = int(vida_max * 0.5)
	mana = int(mana_max * 0.5)
	_update_health_bar()
	stats_changed.emit()

func to_save() -> Dictionary:
	return {
		"name": character_name, "class": class_name_selected, "level": level, "xp": xp, "ouro": ouro,
		"vida": vida, "mana": mana, "vida_max": vida_max, "mana_max": mana_max,
		"ataque": ataque, "ataque_distancia": ataque_distancia, "defesa": defesa, "raw_ataque": raw_ataque, "raw_defesa": raw_defesa, "velocidade_ataque": velocidade_ataque,
		"velocidade_movimento": velocidade_movimento, "xp_ataque": xp_ataque,
		"xp_defesa": xp_defesa, "xp_speed_attack": xp_speed_attack,
		"speed_attack_level": speed_attack_level, "skills": skills, "inventory": inventory.to_save()
	}

func from_save(data: Dictionary, database: ItemDatabase, class_db: ClassDatabase) -> void:
	setup(str(data.get("class", "Guerreiro")), class_db.get_class_data(str(data.get("class", "Guerreiro"))), database)
	character_name = str(data.get("name", "Aventureiro"))
	level = int(data.get("level", level))
	xp = int(data.get("xp", xp))
	ouro = int(data.get("ouro", ouro))
	raw_ataque = int(data.get("raw_ataque", data.get("ataque", ataque)))
	raw_defesa = int(data.get("raw_defesa", data.get("defesa", defesa)))
	velocidade_ataque = float(data.get("velocidade_ataque", velocidade_ataque))
	velocidade_movimento = float(data.get("velocidade_movimento", velocidade_movimento))
	xp_ataque = int(data.get("xp_ataque", 0))
	xp_defesa = int(data.get("xp_defesa", 0))
	xp_speed_attack = int(data.get("xp_speed_attack", 0))
	speed_attack_level = int(data.get("speed_attack_level", 1))
	skills = data.get("skills", SkillProgressionSystem.default_skills())
	inventory.from_save(data.get("inventory", {}))
	recalculate_equipment()
	vida = int(data.get("vida", vida_max))
	mana = int(data.get("mana", mana_max))
	_update_health_bar()
	stats_changed.emit()

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = vida_max
	health_bar.value = vida
	if name_label != null:
		name_label.text = "%s  Lv %d" % [character_name, level]

func _player_sprite_path(chosen_class: String) -> String:
	var art_front := _class_direction_sprite_path(chosen_class, "front")
	if ResourceLoader.exists(art_front):
		return art_front
	match chosen_class:
		"Guerreiro":
			return "res://assets/sprites/player_guerreiro.png"
		"Mago":
			return "res://assets/sprites/player_mago.png"
		"Arqueiro":
			return "res://assets/sprites/player_arqueiro.png"
	return "res://assets/sprites/player_guerreiro.png"

func _update_directional_sprite(input: Vector2, delta: float) -> void:
	if input.length() < 0.08:
		walk_anim_time = 0.0
		walk_anim_frame = 0
		_set_direction_sprite_or_default(current_sprite_direction, current_sprite_flip, false)
		return
	var prefix := _class_sprite_prefix(class_name_selected)
	if prefix.is_empty():
		return
	walk_anim_time += delta
	if walk_anim_time >= 0.12:
		walk_anim_time = 0.0
		walk_anim_frame = (walk_anim_frame + 1) % 4
	if abs(input.y) > abs(input.x):
		if input.y < 0:
			_set_direction_sprite_or_default("back", false, true)
		else:
			_set_direction_sprite_or_default("front", false, true)
	else:
		# The side art is expected to face left; flip it when walking right.
		_set_direction_sprite_or_default("side", input.x > 0, true)

func _set_direction_sprite_or_default(direction: String, flip_h: bool, moving: bool) -> void:
	current_sprite_direction = direction
	var path := ""
	if moving:
		path = _class_direction_sprite_path(class_name_selected, direction, "_walk_%d" % [walk_anim_frame + 1])
	if path.is_empty() or not ResourceLoader.exists(path):
		path = _class_direction_sprite_path(class_name_selected, direction)
	if ResourceLoader.exists(path):
		_set_player_sprite(path, flip_h)
	else:
		_set_player_sprite(_player_sprite_path(class_name_selected), false)

func _class_direction_sprite_path(chosen_class: String, direction: String, suffix: String = "") -> String:
	var prefix := _class_sprite_prefix(chosen_class)
	if prefix.is_empty():
		return ""
	return "res://assets/sprites/player_%s_art_%s%s.png" % [prefix, direction, suffix]

func _class_sprite_prefix(chosen_class: String) -> String:
	match chosen_class:
		"Guerreiro":
			return "guerreiro"
		"Mago":
			return "mago"
		"Arqueiro":
			return "arqueiro"
	return ""

func _class_has_custom_sprite(chosen_class: String) -> bool:
	for direction in ["front", "side", "back"]:
		if ResourceLoader.exists(_class_direction_sprite_path(chosen_class, direction)):
			return true
	return false

func _set_player_sprite(path: String, flip_h: bool) -> void:
	if current_sprite_path == path and current_sprite_flip == flip_h:
		return
	current_sprite_path = path
	current_sprite_flip = flip_h
	sprite.texture = load(path)
	sprite.flip_h = flip_h
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fit_player_sprite()

func _fit_player_sprite() -> void:
	if sprite.texture == null:
		return
	_ensure_shadow()
	if _class_has_custom_sprite(class_name_selected):
		var target_height := 58.0
		var texture_height: float = maxf(1.0, float(sprite.texture.get_height()))
		var sprite_scale: float = target_height / texture_height
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		sprite.position = Vector2(0, -18)
		name_label.offset_top = -58
		name_label.offset_bottom = -40
		health_bar.offset_top = -36
		health_bar.offset_bottom = -30
	else:
		sprite.scale = Vector2(2, 2)
		sprite.position = Vector2.ZERO

func _ensure_shadow() -> void:
	if shadow_sprite != null:
		return
	var texture := load("res://assets/sprites/decor_shadow_soft.png") as Texture2D
	if texture == null:
		return
	shadow_sprite = Sprite2D.new()
	shadow_sprite.texture = texture
	shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_sprite.position = Vector2(0, 18)
	shadow_sprite.scale = Vector2(0.56, 0.28)
	shadow_sprite.modulate = Color(1, 1, 1, 0.58)
	shadow_sprite.z_index = -1
	add_child(shadow_sprite)
